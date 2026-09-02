using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.DependencyInjection;
using TG.Domain.Interfaces;
using TG.Persistence.Interfaces;

namespace TG.Domain.Services
{
    /// <summary>
    /// Servicio de arranque que carga todas las geocercas activas desde la base de datos
    /// y compila los Árboles-R (STRtree) en la memoria RAM al iniciar el microservicio.
    /// Ya no requiere un temporizador periódico porque las actualizaciones llegan vía RabbitMQ.
    /// </summary>
    public class GeofenceCacheLoader : BackgroundService
    {
        private readonly ILogger<GeofenceCacheLoader> _logger;
        private readonly IServiceScopeFactory _scopeFactory;

        public GeofenceCacheLoader(
            ILogger<GeofenceCacheLoader> logger,
            IServiceScopeFactory scopeFactory)
        {
            _logger = logger;
            _scopeFactory = scopeFactory;
        }

        /// <summary>
        /// Método principal que se ejecuta al iniciar el servicio.
        /// Carga todas las geocercas activas desde la base de datos y las inicializa en el motor espacial.
        /// Si ocurre un error crítico, se registra como tal.
        /// No hay un loop de repetición, ya que la actualización se maneja por eventos.
        /// </summary>
        /// <param name="stoppingToken"></param>
        /// <returns></returns>
        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Iniciando la carga espacial inicial (Árboles-R) en memoria...");

            try
            {
                // Es VITAL crear un scope para resolver servicios Scoped/Transient
                await using var scope = _scopeFactory.CreateAsyncScope();

                var repository = scope.ServiceProvider.GetRequiredService<IGeofencesRepository>();
                var spatialIndexManager = scope.ServiceProvider.GetRequiredService<ISpatialIndexManager>();

                _logger.LogInformation("Obteniendo polígonos y círculos desde SQL Server...");

                // Obtenemos todas las geocercas con geometría de una sola vez
                var geofences = await repository.GetAllSpatialGeofencesAsync();

                if (geofences.Any())
                {
                    // Le pasamos la lista al motor para que agrupe por cuenta y construya los R-Trees
                    spatialIndexManager.Initialize(geofences);
                    _logger.LogInformation("Carga espacial inicial completada. {Count} geocercas en memoria.", geofences.Count);
                }
                else
                {
                    _logger.LogWarning("No se encontraron geocercas activas en la base de datos para cargar.");
                }
            }
            catch (Exception ex)
            {
                // Si esto falla, el nodo no podrá calcular nada espacial. Es crítico.
                _logger.LogCritical(ex, "Ocurrió un error catastrófico al inicializar el índice espacial.");
            }
        }
    }
}