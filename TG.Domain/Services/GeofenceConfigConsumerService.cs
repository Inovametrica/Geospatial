using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using SharedTelematic.Services.RabbitMQ;
using System.Text;
using System.Text.Json;
using TG.Domain.Interfaces;

namespace TG.Domain.Services
{
    /// <summary>
    /// Escucha eventos administrativos (como la Liberación de Hardware) para purgar 
    /// la memoria RAM y evitar fugas de memoria de vehículos que ya no existen.
    /// </summary>
    public class GeofenceConfigConsumerService : BackgroundService
    {
        private readonly ILogger<GeofenceConfigConsumerService> _logger;
        private readonly RabbitMQService _rabbitMQService;
        private readonly IGeofencingProcessor _processor;
        private readonly ISpatialIndexManager _spatialIndexManager;
        private IChannel? _channel;
        private string? _consumerTag;

        public GeofenceConfigConsumerService(
            ILogger<GeofenceConfigConsumerService> logger,
            RabbitMQService rabbitMQService,
            IGeofencingProcessor processor,
            ISpatialIndexManager spatialIndexManager)
        {
            _logger = logger;
            _rabbitMQService = rabbitMQService;
            _processor = processor;
            _spatialIndexManager = spatialIndexManager;
        }

        /// <summary>
        /// Método principal del servicio. Se ejecuta al iniciar.
        /// Configura la topología de RabbitMQ para esta instancia.
        /// </summary>
        /// <param name="stoppingToken"></param>
        /// <returns></returns>
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Iniciando consumidor de configuración para Geocodificación...");

            try
            {
                _channel = await _rabbitMQService.GetChannelAsync();

                // Cola exclusiva, temporal y auto-borrable para este nodo
                var queueResult = await _channel.QueueDeclareAsync(
                     queue: string.Empty,
                    durable: false,
                    exclusive: true,
                    autoDelete: true,
                    arguments: null);

                // Nos unimos al Fanout de actualizaciones generales
                await _channel.QueueBindAsync(
                    queue: queueResult.QueueName,
                    exchange: _rabbitMQService.ConfigUpdatesFanoutExchange,
                    routingKey: string.Empty);

                var consumer = new AsyncEventingBasicConsumer(_channel);
                consumer.ReceivedAsync += OnMessageReceivedAsync;

                _consumerTag = await _channel.BasicConsumeAsync(
                    queue: queueResult.QueueName, autoAck: false, consumer: consumer);

                await Task.Delay(Timeout.Infinite, stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogCritical(ex, "Error al iniciar GeocodingConfigConsumerService.");
            }
        }

        /// <summary>
        /// Método que se ejecuta cada vez que se recibe un mensaje de la cola.
        /// </summary>
        private async Task OnMessageReceivedAsync(object sender, BasicDeliverEventArgs eventArgs)
        {
            try
            {
                var message = Encoding.UTF8.GetString(eventArgs.Body.ToArray());
                using var doc = JsonDocument.Parse(message);
                var root = doc.RootElement;

                if (root.TryGetProperty("Action", out var actionElement))
                {
                    string action = actionElement.GetString() ?? "";

                    // 👉 NUEVO SWITCH: Orquesta las acciones según el tipo
                    switch (action)
                    {
                        case "EQUIPMENT_RELEASED":
                            if (root.TryGetProperty("EquipmentId", out var eqElement))
                            {
                                long equipmentId = eqElement.GetInt64();
                                _logger.LogWarning("⚠️ Evento de liberación recibido. Purgando RAM del Equipo ID: {EquipmentId}", equipmentId);
                                await _processor.RemoveVehicleProcessorAsync(equipmentId);
                            }
                            break;

                        case "GEOFENCE_CREATED":
                        case "GEOFENCE_MODIFIED":
                            if (root.TryGetProperty("AccountId", out var accModElement) && root.TryGetProperty("GeofenceId", out var geoModElement))
                            {
                                int accountId = accModElement.GetInt32();
                                int geofenceId = geoModElement.GetInt32();

                                _logger.LogInformation("🔄 Recibida actualización de configuración. Recargando Geocerca {GeofenceId} para Cuenta {AccountId} en RAM...", geofenceId, accountId);

                                // Indicamos al índice espacial que recargue esta geocerca desde SQL Server y la meta al R-Tree
                                await _spatialIndexManager.ReloadGeofenceAsync(accountId, geofenceId);
                            }
                            break;

                        case "GEOFENCE_DELETED":
                            if (root.TryGetProperty("AccountId", out var accDelElement) && root.TryGetProperty("GeofenceId", out var geoDelElement))
                            {
                                int accountId = accDelElement.GetInt32();
                                int geofenceId = geoDelElement.GetInt32();

                                _logger.LogInformation("🗑️ Recibida instrucción de eliminación. Retirando Geocerca {GeofenceId} del Índice Espacial de la Cuenta {AccountId}...", geofenceId, accountId);

                                // Instruimos al índice eliminar este polígono para que dejen de evaluarse cruces
                                _spatialIndexManager.RemoveGeofence(accountId, geofenceId);
                            }
                            break;

                        default:
                            _logger.LogDebug("Acción de configuración ignorada: {Action}", action);
                            break;
                    }
                }

                await _channel!.BasicAckAsync(eventArgs.DeliveryTag, false);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error procesando evento de configuración.");
                await _channel!.BasicNackAsync(eventArgs.DeliveryTag, false, false);
            }
        }
    }
}