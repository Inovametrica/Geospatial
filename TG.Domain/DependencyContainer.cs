using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SharedTelematic.Entities.RabbitMQ;
using SharedTelematic.Services.RabbitMQ;
using TG.Domain.Geofences;
using TG.Domain.Interfaces;
using TG.Domain.Services;
using TG.Domain.Settings;
using TG.Persistence.Interfaces;
using TG.Persistence.Repositories;
using TG.Persistence.Settings;

namespace TG.Domain
{
    /// <summary>
    /// Contenedor de dependencias
    /// </summary>
    public static class DependencyContainer
    {
        public static IServiceCollection AddApplicationServices(this IServiceCollection services, IConfiguration configuration)
        {
            // Registra la configuración para el servicio de geocercas
            services.Configure<GeofencingSettings>(configuration.GetSection("GeofencingSettings"));

            // Registra la configuración para las cadenas de conexión
            services.Configure<DatabaseSettings>(configuration.GetSection("ConnectionStrings"));

            // Configurar RabbitMQ desde la biblioteca compartida
            services.Configure<RabbitMQSettings>(options => configuration.GetSection("RabbitMQ").Bind(options));
            services.AddSingleton<RabbitMQService>();

            // Agrega el servicio de caché en memoria de .NET
            services.AddMemoryCache();

            // --- CACHÉS Y ESTADOS (SINGLETONS) ---
            services.AddSingleton<IGeofenceStateCache, RedisGeofenceStateCache>();
            services.AddSingleton<IVehicleCacheService, VehicleCacheService>();

            // Registramos el Gestor Espacial como Singleton para que toda la app comparta los mismos Árboles-R
            services.AddSingleton<ISpatialIndexManager, SpatialIndexManager>();

            // --- LÓGICA DE NEGOCIO Y REPOSITORIOS ---
            // El orquestador de vehículos debe ser Singleton porque mantiene el diccionario de actores vivos
            services.AddSingleton<IGeofencingProcessor, GeofencingProcessor>();

            services.AddScoped<IGeofencesRepository, GeofencesRepository>();
            services.AddScoped<IVehiclesRepository, VehiclesRepository>();

            // --- SERVICIOS EN SEGUNDO PLANO (HOSTED SERVICES) ---

            // Consumidores de RabbitMQ
            services.AddHostedService<GeofencingConsumerService>();
            services.AddHostedService<GeofenceConfigConsumerService>();

            // Inicializadores (Warmers / Loaders)
            services.AddHostedService<GeofenceCacheLoader>();
            services.AddHostedService<VehicleCacheWarmer>();

            // Buffer y Batching (Escritura asíncrona masiva)
            // El buffer DEBE ser Singleton para que todos los VehicleProcessors escriban en la misma cola
            services.AddSingleton<IGeofenceEventBufferService, GeofenceEventBufferService>();
            services.AddHostedService<GeofenceEventBatchingService>();

            return services;
        }
    }
}