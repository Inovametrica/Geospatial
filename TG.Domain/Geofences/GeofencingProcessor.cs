using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SharedTelematic.Interfaces;
using System.Collections.Concurrent;
using TG.Domain.Device;
using TG.Domain.Interfaces;
// Asegúrate de importar los namespaces de tus repositorios y entidades aquí
// using TG.Persistence.Interfaces;
// using TG.Entities.Geofences;

namespace TG.Domain.Geofences
{
    /// <summary>
    /// Implementación de la lógica de negocio para el procesamiento de eventos de geocercas.
    /// Esta clase es 'Scoped', lo que significa que se crea una nueva instancia para cada solicitud (mensaje).
    /// </summary>
    public class GeofencingProcessor : IGeofencingProcessor
    {
        private readonly ILogger<GeofencingProcessor> _logger;
        private readonly IServiceScopeFactory _scopeFactory;

        // Diccionario seguro para concurrencia que almacenará un procesador por cada vehículo.
        private readonly ConcurrentDictionary<long, VehicleProcessor> _vehicleProcessors = new();
        // Diccionario para rastrear las tareas en ejecución.
        private readonly ConcurrentDictionary<long, Task> _runningTasks = new();

        public GeofencingProcessor(
            ILogger<GeofencingProcessor> logger,
            IServiceScopeFactory scopeFactory) // Inyectamos la fábrica de scopes
        {
            _logger = logger;
            _scopeFactory = scopeFactory;
        }

        /// <summary>
        /// Procesa un único evento de datos GPS.
        /// </summary>
        public Task ProcessGpsEventAsync(IAvlData gpsEvent, CancellationToken cancellationToken)
        {
            // Obtiene el procesador para este vehículo. Si no existe, lo crea de forma segura.
            var processor = _vehicleProcessors.GetOrAdd(gpsEvent.VehicleId, (vehicleId) =>
            {
                //_logger.LogInformation("Creando nuevo procesador para Vehículo ID: {VehicleId}", vehicleId);
                var newProcessor = new VehicleProcessor(vehicleId, _scopeFactory, _logger);

                // ¡Importante! Guardamos la tarea que se está ejecutando.
                _runningTasks[vehicleId] = newProcessor.StartProcessingLoop(cancellationToken);
                return newProcessor;
            });

            // Llamamos al Enqueue sin esperar (await) para no bloquear al consumidor de RabbitMQ.
            _ = processor.EnqueueDataAsync(gpsEvent);
            return Task.CompletedTask;
        }

        /// <summary>
        /// Inicia el proceso de parada para todos los procesadores de vehículos.
        /// </summary>
        public async Task StopAllProcessorsAsync()
        {
            _logger.LogInformation("Iniciando parada controlada para {Count} procesadores de vehículos...", _vehicleProcessors.Count);

            // 1. Decirle a todas las colas que dejen de aceptar nuevos datos.
            foreach (var processor in _vehicleProcessors.Values)
            {
                processor.StopAcceptingData();
            }

            // 2. Esperar a que todas las tareas terminen de procesar lo que ya tenían en cola.
            await Task.WhenAll(_runningTasks.Values);
            _logger.LogInformation("Todos los procesadores de vehículos han finalizado su trabajo.");
        }

        /// <summary>
        /// Detiene y elimina de la memoria el worker de un vehículo específico.
        /// Este método es útil para escenarios como la liberación de hardware, donde un vehículo deja de ser procesado.
        /// </summary>
        public async Task RemoveVehicleProcessorAsync(long vehicleId)
        {
            if (_vehicleProcessors.TryRemove(vehicleId, out var geocoder))
            {
                _logger.LogInformation("Deteniendo y purgando worker de geoespacial para el vehículo liberado {VehicleId}", vehicleId);

                // 1. Cerramos el canal para que no acepte más datos y empiece a vaciarse
                geocoder.StopAcceptingData();

                if (_runningTasks.TryRemove(vehicleId, out var task))
                {
                    try
                    {
                        // 2. Esperamos a que el worker termine de procesar lo que le quedaba en la cola
                        // Esto garantiza que la última visita se cierre correctamente en Redis.
                        await task;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogWarning(ex, "Excepción controlada al esperar la finalización del task del vehículo {VehicleId}", vehicleId);
                    }
                }

                _logger.LogInformation("Worker del vehículo {VehicleId} eliminado de la RAM exitosamente.", vehicleId);
            }
        }
    }
}