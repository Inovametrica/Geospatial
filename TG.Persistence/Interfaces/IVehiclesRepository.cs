
using SharedTelematic.Entities.Vehicles;

namespace TG.Persistence.Interfaces;

public interface IVehiclesRepository : IBaseRepository<Vehicle>
{
    Task<Vehicle?> GetByVehicleIdAsync(long vehicleId);
    Task<IEnumerable<Vehicle>> GetAllVehiclesWithStateAsync();
}