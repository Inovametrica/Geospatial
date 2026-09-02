using SharedTelematic.Entities.Vehicles;
using TG.Entities.Geofences;

namespace TG.Domain.Interfaces
{
    /// <summary>
    /// Servicio de caché para vehículos.
    /// </summary>
    public interface IVehicleCacheService
    {
        Task<Vehicle?> GetVehicleByIdAsync(long vehicleId);
        void UpdateVehicleCache(Vehicle vehicle);
        void PrimeCache(IEnumerable<Vehicle> vehicles);
    }
}