using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using TG.Domain.Interfaces; // Para IVehicleCacheService
using TG.Persistence.Interfaces; // Para IVehiclesRepository

namespace TG.Domain.Services
{
    /// <summary>
    /// Servicio de pre-calentamiento del caché de vehículos.
    /// </summary>
    public class VehicleCacheWarmer : BackgroundService
    {
        private readonly ILogger<VehicleCacheWarmer> _logger;
        private readonly IServiceScopeFactory _scopeFactory;

        public VehicleCacheWarmer(ILogger<VehicleCacheWarmer> logger, IServiceScopeFactory scopeFactory)
        {
            _logger = logger;
            _scopeFactory = scopeFactory;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Iniciando pre-calentamiento del caché de vehículos...");

            try
            {
                // Creamos un scope para resolver nuestros servicios Scoped y Singleton
                await using var scope = _scopeFactory.CreateAsyncScope();
                var vehiclesRepository = scope.ServiceProvider.GetRequiredService<IVehiclesRepository>();
                var vehicleCache = scope.ServiceProvider.GetRequiredService<IVehicleCacheService>();

                var vehicles = await vehiclesRepository.GetAllVehiclesWithStateAsync();

                if (vehicles != null && vehicles.Any())
                {
                    // Delegamos la lógica de cacheo a nuestro servicio especializado
                    vehicleCache.PrimeCache(vehicles);
                    _logger.LogInformation("{Count} vehículos han sido cargados en el caché.", vehicles.Count());
                }
                else
                {
                    _logger.LogWarning("No se encontraron vehículos para cargar en el caché.");
                }
            }
            catch (Exception ex)
            {
                _logger.LogCritical(ex, "El servicio de pre-calentamiento del caché de vehículos ha fallado.");
            }
        }
    }
}