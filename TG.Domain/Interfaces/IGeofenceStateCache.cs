using SharedTelematic.Entities.Geofences;

namespace TG.Domain.Interfaces;

/// <summary>
/// Interfaz para el caché del estado de geocercas de vehículos.
/// </summary>
public interface IGeofenceStateCache
{
    // Clave sugerida: "geo:{vehicleId}:{geofenceId}"
    Task<VehicleGeofenceState?> GetStateAsync(long vehicleId, long geofenceId);
    Task SetStateAsync(long vehicleId, long geofenceId, VehicleGeofenceState state);
    Task RemoveStateAsync(long vehicleId, long geofenceId);
}