using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SharedTelematic.Entities.Vehicles;
using TG.Domain.Interfaces;
using TG.Persistence.Interfaces;

namespace TG.Domain.Services
{
    /// <summary>
    /// Servicio de caché para vehículos.
    /// </summary>
    public class VehicleCacheService : IVehicleCacheService
    {
        private readonly IMemoryCache _cache;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<VehicleCacheService> _logger;
        private static readonly SemaphoreSlim _dbLock = new(1, 1);

        /// <summary>
        /// Constructor del servicio de caché para vehículos.
        /// </summary>
        /// <param name="cache"></param>
        /// <param name="scopeFactory"></param>
        /// <param name="logger"></param>
        public VehicleCacheService(IMemoryCache cache, IServiceScopeFactory scopeFactory, ILogger<VehicleCacheService> logger)
        {
            _cache = cache;
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        /// <summary>
        /// Genera la clave de caché para un vehículo dado su ID.
        /// </summary>
        /// <param name="vehicleId"></param>
        /// <returns></returns>
        private static string GetCacheKey(long vehicleId) => $"vehicle_{vehicleId}";

        /// <summary>
        /// Obtiene un vehículo por su ID, utilizando caché para optimizar el rendimiento.
        /// </summary>
        /// <param name="vehicleId"></param>
        /// <returns></returns>
        public async Task<Vehicle?> GetVehicleByIdAsync(long vehicleId)
        {
            var cacheKey = GetCacheKey(vehicleId);
            if (_cache.TryGetValue(cacheKey, out Vehicle? vehicle))
            {
                return vehicle;
            }

            await _dbLock.WaitAsync();
            try
            {
                if (_cache.TryGetValue(cacheKey, out vehicle))
                {
                    return vehicle;
                }

                _logger.LogWarning("Cache Miss: Vehículo con ID {VehicleId}. Consultando DB.", vehicleId);

                await using var scope = _scopeFactory.CreateAsyncScope();
                var repository = scope.ServiceProvider.GetRequiredService<IVehiclesRepository>();
                var vehicleFromDb = await repository.GetByVehicleIdAsync(vehicleId);

                _cache.Set(cacheKey, vehicleFromDb);
                return vehicleFromDb;
            }
            finally
            {
                _dbLock.Release();
            }
        }

        /// <summary>
        /// Actualiza la caché de un vehículo específico.
        /// </summary>
        /// <param name="vehicle"></param>
        public void UpdateVehicleCache(Vehicle vehicle)
        {
            var cacheKey = GetCacheKey(vehicle.VehicleId);
            _cache.Set(cacheKey, vehicle);
            //_logger.LogInformation("Caché actualizado para el vehículo {VehicleId}.", vehicle.VehicleId);
        }

        /// <summary>
        /// Prepara la caché con una lista de vehículos.
        /// </summary>
        /// <param name="vehicles"></param>
        public void PrimeCache(IEnumerable<Vehicle> vehicles)
        {
            foreach (var vehicle in vehicles)
            {
                _cache.Set(GetCacheKey(vehicle.VehicleId), vehicle);
            }
        }

        /// <summary>
        /// Elimina un vehículo de la caché en memoria. 
        /// Utilizado principalmente cuando se hace una liberación de hardware (Tombstoning).
        /// </summary>
        /// <param name="vehicleId">El VehicleId original del equipo a remover.</param>
        public void RemoveVehicleFromCache(long vehicleId)
        {
            if (vehicleId <= 0) return;

            string cacheKey = GetCacheKey(vehicleId);
            _cache.Remove(cacheKey);

            _logger.LogInformation("El VehicleId {vehicleId} ha sido purgado del caché en memoria exitosamente.", vehicleId);
        }
    }
}