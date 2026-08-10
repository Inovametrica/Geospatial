using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using StackExchange.Redis;
using System.Text.Json;
using TG.Domain.Interfaces;
using TG.Domain.Settings;
using SharedTelematic.Entities.Geofences; // Donde está VehicleGeofenceState

namespace TG.Domain.Services
{
    /// <summary>
    /// Implementación de la caché de estado de geocercas usando Redis.
    /// </summary>
    public class RedisGeofenceStateCache : IGeofenceStateCache
    {
        private readonly ILogger<RedisGeofenceStateCache> _logger;
        private readonly IConnectionMultiplexer _redis;
        private readonly IDatabase _database;

        // Prefijo para evitar colisiones con otras claves en el mismo Redis
        private const string KeyPrefix = "geo_state:";

        // Expiración de seguridad (ej. 24 horas) por si un vehículo deja de reportar
        private static readonly TimeSpan StateExpiry = TimeSpan.FromHours(24);

        public RedisGeofenceStateCache(IOptions<GeofencingSettings> settings, ILogger<RedisGeofenceStateCache> logger)
        {
            _logger = logger;
            try
            {
                // Conexión Singleton a Redis
                _redis = ConnectionMultiplexer.Connect(settings.Value.RedisConnectionString);
                _database = _redis.GetDatabase();
            }
            catch (Exception ex)
            {
                _logger.LogCritical(ex, "No se pudo conectar a Redis en: {Conn}", settings.Value.RedisConnectionString);
                throw;
            }
        }

        // Genera la clave única: "geo_state:{VehicleId}:{GeofenceId}"
        private string GetKey(long vehicleId, long geofenceId) => $"{KeyPrefix}{vehicleId}:{geofenceId}";

        public async Task<VehicleGeofenceState?> GetStateAsync(long vehicleId, long geofenceId)
        {
            try
            {
                var key = GetKey(vehicleId, geofenceId);
                var jsonValue = await _database.StringGetAsync(key);

                if (jsonValue.IsNullOrEmpty) return null;

                return JsonSerializer.Deserialize<VehicleGeofenceState>(jsonValue.ToString());
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error leyendo estado de Redis (V:{V}, G:{G})", vehicleId, geofenceId);
                return null;
            }
        }

        public async Task SetStateAsync(long vehicleId, long geofenceId, VehicleGeofenceState state)
        {
            try
            {
                var key = GetKey(vehicleId, geofenceId);
                var jsonValue = JsonSerializer.Serialize(state);

                await _database.StringSetAsync(key, jsonValue, StateExpiry);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error guardando estado en Redis (V:{V}, G:{G})", vehicleId, geofenceId);
            }
        }

        public async Task RemoveStateAsync(long vehicleId, long geofenceId)
        {
            try
            {
                var key = GetKey(vehicleId, geofenceId);
                await _database.KeyDeleteAsync(key);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error borrando estado de Redis (V:{V}, G:{G})", vehicleId, geofenceId);
            }
        }
    }
}