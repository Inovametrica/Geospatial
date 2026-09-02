using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using TG.Domain.Interfaces;
using TG.Persistence.Interfaces;
using SharedTelematic.Services.RabbitMQ;
using System.Text.Json;
using TG.Domain.Settings;
using Microsoft.Extensions.Options;
using SharedTelematic.Entities.Geofences;

namespace TG.Domain.Services
{
    /// <summary>
    /// Servicio en segundo plano para procesar y publicar eventos de geocerca en lotes.
    /// </summary>
    public class GeofenceEventBatchingService : BackgroundService
    {
        private readonly ILogger<GeofenceEventBatchingService> _logger;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly IGeofenceEventBufferService _eventBuffer;
        private readonly RabbitMQService _rabbitMQService;
        private readonly GeofencingSettings _settings;

        public GeofenceEventBatchingService(
            ILogger<GeofenceEventBatchingService> logger,
            IServiceScopeFactory scopeFactory,
            IGeofenceEventBufferService eventBuffer,
            RabbitMQService rabbitMQService,
            IOptions<GeofencingSettings> settings)
        {
            _logger = logger;
            _scopeFactory = scopeFactory;
            _eventBuffer = eventBuffer;
            _rabbitMQService = rabbitMQService;
            _settings = settings.Value;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Servicio de lotes de eventos de geocerca iniciado.");
            var timerInterval = TimeSpan.FromSeconds(_settings.BatchingIntervalSeconds);
            using var timer = new PeriodicTimer(timerInterval);

            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                var eventsToProcess = _eventBuffer.FlushEvents();
                if (!eventsToProcess.Any()) continue;

                _logger.LogInformation("Procesando lote de {Count} eventos de geocerca.", eventsToProcess.Count);

                try
                {
                    await using var scope = _scopeFactory.CreateAsyncScope();
                    var geofencesRepo = scope.ServiceProvider.GetRequiredService<IGeofencesRepository>();

                    foreach (var chunk in eventsToProcess.Chunk(_settings.BatchingSize))
                    {
                        var chunkList = chunk.ToList();
                        await geofencesRepo.AddGeofenceEventBatchAsync(chunkList);
                        await PublishBatchAsync(chunkList);
                    }
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error procesando lote de eventos de geocerca.");
                }
            }
        }

        private async Task PublishBatchAsync(List<GeofenceEventData> enrichedBatch)
        {
            var exchangeName = _rabbitMQService.GeofenceEventsConsistentHashExchange;
            if (string.IsNullOrEmpty(exchangeName)) return;

            foreach (var ev in enrichedBatch)
            {
                string message = JsonSerializer.Serialize(ev);
                string routingKey = $"vehicle_{ev.VehicleId}";
                await _rabbitMQService.PublishAsync(exchangeName, routingKey, message);
            }
        }
    }
}