using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using RabbitMQ.Client.Events;
using RabbitMQ.Client;
using System.Text;
using System.Text.Json;
using SharedTelematic.Services.RabbitMQ;
using TG.Domain.Interfaces;
using TG.Domain.Geofences; // Para GeofencingProcessor
using SharedTelematic.Entities.Gps;
using System.Text.Json.Serialization;

namespace TG.Domain.Services
{
    /// <summary>
    /// OBJETIVO:
    /// Servicio en segundo plano (BackgroundService) que consume eventos de GPS
    /// desde RabbitMQ para procesar la lógica de Geocercas (entradas/salidas).
    /// 
    /// ARQUITECTURA: (Refactorizado)
    /// 1. Sigue el patrón "Fanout-a-Hash". Este servicio compite con
    ///    otras instancias de ESTE MISMO servicio (Geocercas).
    /// 2. Cada instancia que se inicia crea su propia COLA EXCLUSIVA y TEMPORAL.
    /// 3. Todas las instancias bindean (conectan) su cola exclusiva al mismo exchange
    ///    'GeofencingHashExchange' (que es de tipo 'x-consistent-hash').
    /// 4. El exchange 'x-consistent-hash' garantiza que un mismo 'VehicleId' 
    ///    (el routing-key) sea enviado SIEMPRE a la misma cola, y por lo tanto,
    ///    a la misma instancia de este servicio.
    /// </summary>
    public class GeofencingConsumerService : BackgroundService
    {
        private readonly ILogger<GeofencingConsumerService> _logger;
        private readonly RabbitMQService _rabbitMQService;
        private readonly IGeofencingProcessor _processor;
        private IChannel? _channel;
        private string _consumerTag = string.Empty;
        // La variable 'queueName' se elimina, ya que la cola ahora es temporal y exclusiva.

        /// <summary>
        /// Constructor.
        /// </summary>
        /// <param name="logger">Servicio de Logging.</param>
        /// <param name="rabbitMQService">Servicio Singleton que gestiona la conexión a RabbitMQ.</param>
        /// <param name="processor">Servicio Singleton que gestiona los workers de vehículos (Patrón Actor).</param>
        public GeofencingConsumerService(
            ILogger<GeofencingConsumerService> logger,
            RabbitMQService rabbitMQService,
            IGeofencingProcessor processor)
        {
            _logger = logger;
            _rabbitMQService = rabbitMQService;
            _processor = processor;
        }

        /// <summary>
        /// Método principal del servicio. Configura y mantiene la escucha de mensajes.
        /// </summary>
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Servicio Consumidor de Geocercas (Refactorizado) iniciando.");

            try
            {
                // 1. Obtenemos el canal de comunicación.
                _channel = await _rabbitMQService.GetChannelAsync();

                // 2. Obtenemos el nombre del Exchange de Geocercas.
                string exchangeName = _rabbitMQService.GeofencingHashExchange;

                if (string.IsNullOrEmpty(exchangeName))
                {
                    _logger.LogCritical("El exchange 'GeofencingHashExchange' no está configurado en RabbitMQSettings. El servicio no puede iniciar.");
                    return;
                }

                // Declarar una cola FIJA y DURADERA para la comparación de geocercas
                var queueDeclareResult = await _channel.QueueDeclareAsync(
                    queue: _rabbitMQService.GeofencingQueue, // Nombre estático para que RabbitMQ lo recuerde
                    durable: true,                       // Sobrevive a reinicios del servidor RabbitMQ
                    exclusive: false,                    // Permite que el microservicio se reconecte
                    autoDelete: false,                   // La cola NUNCA se borra sola
                    arguments: null);

                var queueName = queueDeclareResult.QueueName;
                _logger.LogInformation("Instancia de Geocercas conectada. Escuchando en la cola exclusiva: {QueueName}", queueName);

                // 4. Bindear (conectar) nuestra cola exclusiva al Exchange de Geocercas.
                //    Usamos "1" como 'routingKey' para el "peso" (weight) del balanceo.
                await _channel.QueueBindAsync(
                    queue: queueName,
                    exchange: exchangeName,
                    routingKey: "1");

                // 5. Crear el consumidor.
                var consumer = new AsyncEventingBasicConsumer(_channel);

                // 6. Asignar el método que manejará los mensajes entrantes.
                consumer.ReceivedAsync += (s, args) => OnMessageReceivedAsync(s, args, stoppingToken);

                // 7. Iniciar el consumo de la cola.
                _consumerTag = await _channel.BasicConsumeAsync(queueName, autoAck: false, consumer);

                // 8. Mantener el servicio vivo.
                await Task.Delay(Timeout.Infinite, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("El servicio consumidor de geocercas se está deteniendo (Operación cancelada).");
            }
            catch (Exception ex)
            {
                _logger.LogCritical(ex, "El servicio consumidor de geocercas ha fallado de forma crítica.");
            }
            finally
            {
                _logger.LogInformation("Servicio Consumidor de Geocercas detenido.");
            }
        }

        /// <summary>
        /// Delegado que se ejecuta cada vez que se recibe un mensaje de la cola.
        /// </summary>
        private async Task OnMessageReceivedAsync(object sender, BasicDeliverEventArgs eventArgs, CancellationToken cancellationToken)
        {
            // Copiamos el cuerpo del mensaje. Es crucial hacerlo inmediatamente.
            var message = Encoding.UTF8.GetString(eventArgs.Body.ToArray());

            if (_channel == null || cancellationToken.IsCancellationRequested)
            {
                // Devolvemos el mensaje a la cola si el servicio se está deteniendo.
                await _channel!.BasicNackAsync(eventArgs.DeliveryTag, false, true); // Devuelve a la cola
                return;
            }

            try
            {
                var serializerOptions = new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                    ReferenceHandler = ReferenceHandler.Preserve
                };
                var gpsEvent = JsonSerializer.Deserialize<AvlData>(message, serializerOptions);

                // Validamos que el evento sea correcto antes de procesarlo.
                if (gpsEvent != null && gpsEvent.GpsId > 0 && gpsEvent.VehicleId > 0)
                {
                    // Pasamos el evento al procesador (singleton) de geocercas.
                    await _processor.ProcessGpsEventAsync(gpsEvent, cancellationToken);
                }
                else
                {
                    _logger.LogWarning("Mensaje de GPS recibido no válido o incompleto (RK: {RoutingKey}).", eventArgs.RoutingKey);
                }

                // Confirmamos a RabbitMQ que el mensaje fue procesado (Ack).
                await _channel.BasicAckAsync(eventArgs.DeliveryTag, false);
            }
            catch (JsonException jsonEx)
            {
                _logger.LogError(jsonEx, "Error al deserializar el mensaje de geocercas. Contenido: {message}", message);
                // Descartamos el mensaje (Nack) porque está corrupto.
                await _channel.BasicNackAsync(eventArgs.DeliveryTag, false, false);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error procesando el mensaje de geocercas (RK: {RoutingKey}).", eventArgs.RoutingKey);
                // Descartamos el mensaje (Nack) para evitar bucles de error.
                await _channel.BasicNackAsync(eventArgs.DeliveryTag, false, false);
            }
        }

        /// <summary>
        /// Se llama cuando se solicita la detención del servicio. 
        /// Realiza una limpieza controlada.
        /// </summary>
        public override async Task StopAsync(CancellationToken cancellationToken)
        {
            _logger.LogInformation("Iniciando la secuencia de parada controlada (Geocercas)...");

            // 1. Cancelar el consumidor para dejar de recibir mensajes.
            if (_channel?.IsOpen ?? false && !string.IsNullOrEmpty(_consumerTag))
            {
                _logger.LogInformation("Cancelando consumidor de RabbitMQ (Geocercas) con tag: {consumerTag}", _consumerTag);
                await _channel.BasicCancelAsync(_consumerTag);
            }

            // 2. Llamar al procesador para que detenga a todos sus workers (VehicleProcessors).
            //    Esto les permite terminar de procesar los mensajes que ya tenían en cola.
            if (_processor is GeofencingProcessor concreteProcessor)
            {
                await concreteProcessor.StopAllProcessorsAsync();
            }
            else
            {
                _logger.LogWarning("No se pudo realizar la parada controlada de los VehicleProcessors (Geocercas).");
            }

            // 3. Llamar al método base.
            await base.StopAsync(cancellationToken);
            _logger.LogInformation("Servicio de Geocercas detenido de forma controlada.");
        }
    }
}