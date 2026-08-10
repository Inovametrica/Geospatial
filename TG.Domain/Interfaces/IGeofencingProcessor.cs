using SharedTelematic.Interfaces;

namespace TG.Domain.Interfaces
{
    /// <summary>
    /// Define el contrato para el servicio que contiene la lógica de negocio principal
    /// para procesar eventos de GPS.
    /// </summary>
    public interface IGeofencingProcessor
    {
        /// <summary>
        /// Procesa un único evento de datos GPS recibido desde el bus de mensajes.
        /// Este método contendrá la lógica para evaluar geocercas, generar notificaciones, etc.
        /// </summary>
        /// <param name="gpsEvent">El objeto de datos GPS deserializado desde el mensaje de RabbitMQ.</param>
        /// <returns>Una tarea que representa la operación de procesamiento asíncrona.</returns>
        Task ProcessGpsEventAsync(IAvlData gpsEvent, CancellationToken cancellationToken);

        /// <summary>
        /// Detiene y elimina de la memoria el worker de un vehículo específico.
        /// Este método es útil para escenarios como la liberación de hardware, donde un vehículo deja de ser procesado.
        /// </summary>
        Task RemoveVehicleProcessorAsync(long vehicleId);
    }
}