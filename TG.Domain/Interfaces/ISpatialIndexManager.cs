using SharedTelematic.Entities.Gps;
using TG.Entities.Geofences;

namespace TG.Domain.Interfaces
{
    public interface ISpatialIndexManager
    {
        /// <summary>
        /// Evalúa en qué geocercas de la cuenta se encuentra actualmente una coordenada.
        /// Utiliza un Árbol-R para evitar evaluar polígonos lejanos.
        /// </summary>
        IEnumerable<Geofence> FindIntersectingGeofences(int accountId, double latitude, double longitude);

        /// <summary>
        /// Recarga o agrega una geocerca específica al Árbol-R en memoria.
        /// </summary>
        Task ReloadGeofenceAsync(int accountId, long geofenceId);

        /// <summary>
        /// Elimina una geocerca del Árbol-R en memoria.
        /// </summary>
        void RemoveGeofence(int accountId, long geofenceId);

        /// <summary>
        /// Carga masiva inicial de geocercas en el motor espacial.
        /// </summary>
        void Initialize(IEnumerable<Geofence> geofences);

        /// <summary>
        /// Obtiene una geocerca específica por su ID, útil para operaciones de actualización o eliminación.
        /// </summary>
        /// <param name="accountId"></param>
        /// <param name="geofenceId"></param>
        /// <returns></returns>
        Geofence? GetGeofence(int accountId, long geofenceId);
    }
}