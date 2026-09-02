using SharedTelematic.Entities.Geofences;

namespace TG.Domain.Interfaces
{
    /// <summary>
    /// Servicio para almacenar en búfer eventos de geocerca antes de su procesamiento o almacenamiento.
    /// </summary>
    public interface IGeofenceEventBufferService
    {
        void AddEvent(GeofenceEventData eventData);
        List<GeofenceEventData> FlushEvents();
    }
}