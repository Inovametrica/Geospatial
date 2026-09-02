using System.Collections.Concurrent;
using SharedTelematic.Entities.Geofences;
using TG.Domain.Interfaces;

namespace TG.Domain.Services
{
    /// <summary>
    /// Servicio para almacenar en búfer eventos de geocerca antes de su procesamiento o almacenamiento.
    /// </summary>
    public class GeofenceEventBufferService : IGeofenceEventBufferService
    {
        private ConcurrentQueue<GeofenceEventData> _eventQueue = new();

        public void AddEvent(GeofenceEventData eventData)
        {
            _eventQueue.Enqueue(eventData);
        }

        public List<GeofenceEventData> FlushEvents()
        {
            var eventsToProcess = new List<GeofenceEventData>();
            while (_eventQueue.TryDequeue(out var eventData))
            {
                eventsToProcess.Add(eventData);
            }
            return eventsToProcess;
        }
    }
}