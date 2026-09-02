using SharedTelematic.Entities.Geofences;
using TG.Entities.Geofences;

namespace TG.Persistence.Interfaces;

public interface IGeofencesRepository : IBaseRepository<Geofence>
{
    /// <summary>
    /// Obtiene todas las geocercas activas de la cuenta, incluyendo su geometría en formato nativo de NetTopologySuite y su AccountId.
    /// </summary>
    /// <returns></returns>
    Task<List<Geofence>> GetAllSpatialGeofencesAsync();

    /// <summary>
    /// Agrega o actualiza la relación de un vehículo dentro de una geocerca, con la fecha/hora de entrada.
    /// </summary>
    /// <param name="vehicleId"></param>
    /// <param name="geofenceId"></param>
    /// <param name="entryTimeUtc"></param>
    /// <returns></returns>
    Task<bool> AddVehicleToGeofenceStateAsync(long vehicleId, long geofenceId, DateTime entryTimeUtc);

    /// <summary>
    /// Elimina la relación de un vehículo dentro de una geocerca, indicando que el vehículo ha salido de la geocerca.
    /// </summary>
    /// <param name="vehicleId"></param>
    /// <param name="geofenceId"></param>
    /// <returns></returns>
    Task<bool> RemoveVehicleFromGeofenceStateAsync(long vehicleId, long geofenceId);

    /// <summary>
    /// Agrega un lote de eventos de geocerca.
    /// </summary>
    /// <param name="eventBatch"></param>
    /// <returns></returns>
    Task<Dictionary<int, long>> AddGeofenceEventBatchAsync(List<GeofenceEventData> eventBatch);

    /// <summary>
    /// Obtiene el detalle espacial de una geocerca específica por su ID,
    /// incluyendo su geometría en formato nativo de NetTopologySuite y su AccountId.
    /// </summary>
    /// <param name="geofenceId">Identificador único de la geocerca.</param>
    /// <returns>El objeto Geofence con su geometría procesada, o null si no se encuentra activa.</returns>
    Task<Geofence?> GetByIdSpatialAsync(long geofenceId);


}