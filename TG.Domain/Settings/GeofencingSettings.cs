namespace TG.Domain.Settings
{
    public class GeofencingSettings
    {
        /// <summary>
        /// El intervalo en minutos para refrescar la caché
        /// </summary>
        public int CacheRefreshIntervalMinutes { get; set; } = 10; // Un valor por defecto por si no se encuentra en el JSON.
        /// <summary>
        /// El intervalo en segundos en que el servicio de batching procesará la cola.
        /// </summary>
        public int BatchingIntervalSeconds { get; set; } = 5;

        /// <summary>
        /// El número máximo de registros que se enviarán a la base de datos en un solo lote.
        /// </summary>
        public int BatchingSize { get; set; } = 2000;

        /// <summary>
        /// Conexión a Redis para el almacenamiento en caché.
        /// </summary>
        public string RedisConnectionString { get; set; } = "localhost:6379";
    }
}