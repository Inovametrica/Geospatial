using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SharedTelematic.Entities.RabbitMQ;
using SharedTelematic.Services.RabbitMQ;
using TG.Domain.Interfaces;
using TG.Domain.Services;
using TG.Domain.Settings;
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

            // --- LÓGICA DE NEGOCIO Y REPOSITORIOS ---

            // --- SERVICIOS EN SEGUNDO PLANO (HOSTED SERVICES) ---

            // Consumidores de RabbitMQ
            services.AddHostedService<GeofencingConsumerService>();

            // Inicializadores (Warmers / Loaders)

            return services;
        }
    }
}