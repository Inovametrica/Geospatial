using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NetTopologySuite; // Necesario para leer WKT (Well-Known Text)
using NetTopologySuite.IO; // Necesario para leer WKT (Well-Known Text)
using TG.Entities.Geofences;
using TG.Persistence.Interfaces;
using TG.Persistence.Settings;
using TG.Persistence.Helpers;
using NetTopologySuite.Geometries;
using SharedTelematic.Entities.Geofences;

namespace TG.Persistence.Repositories;


/// <summary>
/// Repositorio para gestionar geocercas (circulares y poligonales).
/// </summary>
public class GeofencesRepository : BaseRepository<Geofence>, IGeofencesRepository
{
    // Un lector de WKT (Well-Known Text) de NetTopologySuite.
    // Es reutilizable y seguro para hilos.
    private readonly WKTReader _wktReader;

    public GeofencesRepository(IOptions<DatabaseSettings> dbSettings, ILogger<GeofencesRepository> logger) : base(dbSettings, logger)
    {
        // Inicializamos el lector. SRID 4326 es el estándar para Lat/Lon.
        // 1. Definimos nuestro modelo de precisión y SRID (4326 para Lat/Lon)
        var precisionModel = new PrecisionModel();
        int srid = 4326;

        // 2. Creamos un GeometryFactory con esas especificaciones
        var geometryFactory = new GeometryFactory(precisionModel, srid);

        // 3. Creamos la nueva instancia de "Servicios"
        // Esto le dice a NetTopologySuite cómo debe manejar las geometrías
        var services = new NtsGeometryServices(
            geometryFactory.CoordinateSequenceFactory, // Arg 1: CoordinateSequenceFactory
            geometryFactory.PrecisionModel,            // Arg 2: PrecisionModel
            geometryFactory.SRID                       // Arg 3: int (SRID)
        );

        // 4. Pasamos esos servicios al constructor de WKTReader
        _wktReader = new WKTReader(services);
    }

    /// <summary>
    /// Obtiene el detalle espacial de una geocerca específica por su ID,
    /// incluyendo su geometría en formato nativo de NetTopologySuite y su AccountId.
    /// </summary>
    public async Task<Geofence?> GetByIdSpatialAsync(long geofenceId)
    {
        if (geofenceId <= 0) return null;

        try
        {
            await using var connection = new SqlConnection(_dbSettings.Telematic);
            await connection.OpenAsync();

            // Seleccionamos el id_cuenta para el agrupamiento en el SpatialIndexManager,
            // y convertimos la geometría espacial de SQL Server a texto WKT.
            const string query = @"
                SELECT 
                    g.id_geocerca,
                    g.id_cuenta,
                    g.nombre,
                    g.tipo_geocerca,
                    g.latitud_centro,
                    g.longitud_centro,
                    g.radio_metros,
                    g.geometria.ToString() AS geometria_wkt
                FROM 
                    dbo.cat_geocercas g WITH (NOLOCK)
                WHERE 
                    g.id_geocerca = @geofenceId 
                    AND g.estado = 1;"; // Solo cargamos si está activa

            await using var command = new SqlCommand(query, connection);
            command.Parameters.AddWithValue("@geofenceId", geofenceId);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                var geofence = new Geofence
                {
                    GeofenceId = reader.GetInt64(reader.GetOrdinal("id_geocerca")),
                    AccountId = reader.GetInt32(reader.GetOrdinal("id_cuenta")), // 👉 Crítico para el R-Tree
                    Name = reader.GetString(reader.GetOrdinal("nombre")),
                    Type = ParseGeofenceType(reader.GetString(reader.GetOrdinal("tipo_geocerca")))
                };

                // Procesamiento condicional según el tipo primitivo de la geocerca
                if (geofence.Type == GeofenceType.Circulo)
                {
                    geofence.CenterLatitude = reader.GetDecimalAsDouble("latitud_centro");
                    geofence.CenterLongitude = reader.GetDecimalAsDouble("longitud_centro");
                    geofence.RadiusMeters = reader.GetInt32AsDouble("radio_metros");
                }
                else if (geofence.Type == GeofenceType.Poligono)
                {
                    string wkt = reader.GetStringSafe("geometria_wkt");
                    if (!string.IsNullOrEmpty(wkt))
                    {
                        // Convertimos la cadena WKT proveniente de SQL Server 
                        // en un objeto Geometry de NetTopologySuite listo para cómputo espacial.
                        geofence.Geometry = _wktReader.Read(wkt);
                    }
                }

                return geofence;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error al obtener el detalle espacial de la geocerca ID: {GeofenceId}", geofenceId);
            throw; // Re-lanzamos para que el consumidor de configuración sepa que la operación falló
        }

        return null;
    }

    /// <summary>
    /// Obtiene TODAS las geocercas activas con su AccountId y geometría espacial
    /// para inicializar el Árbol-R en la memoria RAM (SpatialIndexManager).
    /// </summary>
    public async Task<List<Geofence>> GetAllSpatialGeofencesAsync()
    {
        var geofences = new List<Geofence>();
        try
        {
            await using var connection = new SqlConnection(_dbSettings.Telematic);
            await connection.OpenAsync();

            const string query = @"
                SELECT 
                    g.id_geocerca,
                    g.id_cuenta,
                    g.nombre,
                    g.tipo_geocerca,
                    g.latitud_centro,
                    g.longitud_centro,
                    g.radio_metros,
                    g.geometria.ToString() AS geometria_wkt
                FROM 
                    dbo.cat_geocercas g WITH (NOLOCK)
                WHERE 
                    g.estado = 1;"; // Solo activas

            await using var command = new SqlCommand(query, connection);
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                var geofence = new Geofence
                {
                    GeofenceId = reader.GetInt64(reader.GetOrdinal("id_geocerca")),
                    AccountId = reader.GetInt32(reader.GetOrdinal("id_cuenta")),
                    Name = reader.GetString(reader.GetOrdinal("nombre")),
                    Type = ParseGeofenceType(reader.GetString(reader.GetOrdinal("tipo_geocerca")))
                };

                if (geofence.Type == GeofenceType.Circulo)
                {
                    geofence.CenterLatitude = reader.GetDecimalAsDouble("latitud_centro");
                    geofence.CenterLongitude = reader.GetDecimalAsDouble("longitud_centro");
                    geofence.RadiusMeters = reader.GetInt32AsDouble("radio_metros");
                }
                else if (geofence.Type == GeofenceType.Poligono)
                {
                    string wkt = reader.GetStringSafe("geometria_wkt");
                    if (!string.IsNullOrEmpty(wkt))
                    {
                        geofence.Geometry = _wktReader.Read(wkt);
                    }
                }
                geofences.Add(geofence);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error masivo al obtener todas las geocercas espaciales.");
        }
        return geofences;
    }

    /// <summary>
    /// Inserta un lote de eventos de geocerca en la tabla histórica de forma masiva
    /// utilizando un Tipo de Tabla Definido por el Usuario (TVP) para un rendimiento óptimo.
    /// </summary>
    /// <param name="eventBatch">La lista de eventos de geocerca a insertar.</param>
    /// <returns>
    /// Un diccionario que mapea el índice original de cada evento en la lista de entrada (TempId)
    /// a su nuevo GpsId generado por la base de datos.
    /// </returns>
    public async Task<Dictionary<int, long>> AddGeofenceEventBatchAsync(List<GeofenceEventData> eventBatch)
    {
        var idMap = new Dictionary<int, long>();
        if (!eventBatch.Any())
        {
            return idMap;
        }

        // Crear un DataTable que coincida EXACTAMENTE con la estructura del TVP en SQL.
        var dt = new DataTable();
        dt.Columns.Add("TempId", typeof(int));
        dt.Columns.Add("id_gps", typeof(long));
        dt.Columns.Add("id_equipo", typeof(long));
        dt.Columns.Add("latitud", typeof(decimal));
        dt.Columns.Add("longitud", typeof(decimal));
        dt.Columns.Add("odometro", typeof(decimal));
        dt.Columns.Add("velocidad", typeof(decimal));
        dt.Columns.Add("velocidad_maxima_kmh", typeof(decimal));
        dt.Columns.Add("velocidad_promedio_kmh", typeof(decimal));
        dt.Columns.Add("orientacion", typeof(decimal));
        dt.Columns.Add("fechahora_utc", typeof(DateTime));
        dt.Columns.Add("fechahora_utc_recepcion", typeof(DateTime));
        dt.Columns.Add("evento", typeof(int));
        dt.Columns.Add("id_geoespacial", typeof(long));
        dt.Columns.Add("nombre_geoespacial", typeof(string));
        dt.Columns.Add("tipo_geoespacial", typeof(int));
        dt.Columns.Add("tiempo_estancia_segundos", typeof(decimal));

        // Llenar el DataTable con los datos del lote.
        for (int i = 0; i < eventBatch.Count; i++)
        {
            var ev = eventBatch[i];
            dt.Rows.Add(
                i, // TempId es el índice original
                ev.GpsId,
                ev.VehicleId,
                (decimal)ev.Latitude,
                (decimal)ev.Longitude,
                (decimal)ev.Odometer,
                (decimal)ev.Speed,
                (decimal)ev.MaxSpeedKmh,
                (decimal)ev.AvgSpeedKmh,
                (decimal)ev.Orientation,
                ev.DateTimeUtc,
                ev.ReceptionDateTimeUtc,
                ev.EventType,
                ev.GeofenceKey,
                ev.GeofenceName,
                ev.GeofenceType,
                (decimal)ev.DwellTimeSeconds

            );
        }

        try
        {
            await using var connection = new SqlConnection(_dbSettings.History);
            await connection.OpenAsync();

            const string spName = "dbo.sp_InsertGeofenceEventBatch";

            await using var command = new SqlCommand(spName, connection)
            {
                CommandType = CommandType.StoredProcedure,
                CommandTimeout = 120 // Se aumenta el timeout para lotes grandes.
            };

            // Configurar el parámetro como un TVP.
            var tvpParam = command.Parameters.AddWithValue("@batch", dt);
            tvpParam.SqlDbType = SqlDbType.Structured;
            tvpParam.TypeName = "dbo.GeofenceEventBatchType"; // Nombre exacto del TYPE en SQL.

            // Ejecutar y leer el mapeo de IDs devuelto por el procedimiento.
            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                idMap.Add(reader.GetInt32(0), reader.GetInt64(1)); // Mapea TempId a id_gps
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AddGeofenceEventBatchAsync -- Error catastrófico durante la inserción masiva de eventos de geocerca. Para vehículo {VehicleId}", VehicleId);
            // Volvemos a lanzar la excepción para que el servicio de batching sepa que la operación falló
            // y pueda, potencialmente, reintentar el lote.
            throw;
        }

        return idMap;
    }

    /// <summary>
    /// Parsea el tipo de geocerca desde cadena a enum.
    /// </summary>
    /// <param name="type"></param>
    /// <returns></returns>
    /// <exception cref="ArgumentException"></exception>
    private GeofenceType ParseGeofenceType(string type) => type switch
    {
        "CIRCULO" => GeofenceType.Circulo,
        "POLIGONO" => GeofenceType.Poligono,
        _ => throw new ArgumentException($"Tipo de geocerca no reconocido: {type}")
    };

    /// <summary>
    /// Parsea el ámbito de geocerca desde cadena a enum.
    /// </summary>
    /// <param name="scope"></param>
    /// <returns></returns>
    private GeofenceScope ParseGeofenceScope(string scope) => scope switch
    {
        "ESPECIFICO" => GeofenceScope.Especifico,
        "ASIGNADAS" => GeofenceScope.Asignadas,
        "ALL" => GeofenceScope.All,
        _ => GeofenceScope.Unknown
    };

    /// <summary>
    /// Inserta un registro de estado en la tabla 'dat_equipos_en_geocercas'.
    /// Esta operación es llamada por el GeofencingProcessor cuando detecta una ENTRADA.
    /// </summary>
    /// <param name="vehicleId">El ID del equipo</param>
    /// <param name="geofenceId">El ID de la geocerca (de cat_geocercas)</param>
    /// <param name="entryTimeUtc">El momento de la entrada (usualmente la fecha del paquete GPS)</param>
    /// <returns>True si la inserción fue exitosa.</returns>
    public async Task<bool> AddVehicleToGeofenceStateAsync(long vehicleId, long geofenceId, DateTime entryTimeUtc)
    {
        try
        {
            await using var connection = new SqlConnection(_dbSettings.Telematic);
            await connection.OpenAsync();

            // Usamos 'INSERT' simple.
            // Si ya existe (lo cual sería un error de lógica en el procesador), 
            // la Primary Key (vehicleId, geofenceId) causará un error controlado.
            // Usamos 'IGNORE_DUP_KEY = ON' si quisiéramos evitar el error, 
            // pero es mejor que el procesador tenga la lógica correcta.
            const string query = @"
                INSERT INTO dbo.dat_equipos_en_geocercas (id_equipo, id_geocerca, fecha_utc_entrada)
                VALUES (@id_equipo, @id_geocerca, @fecha_utc_entrada);
            ";

            await using var command = new SqlCommand(query, connection);
            command.Parameters.AddWithValue("@id_equipo", vehicleId);
            command.Parameters.AddWithValue("@id_geocerca", geofenceId);
            command.Parameters.AddWithValue("@fecha_utc_entrada", entryTimeUtc);

            int rowsAffected = await command.ExecuteNonQueryAsync();
            return rowsAffected > 0;
        }
        catch (Exception ex)
        {
            // El error 2627 es violación de Primary Key (ya existe). Podemos ignorarlo si es necesario.
            if (ex.Message.Contains("Violation of PRIMARY KEY constraint"))
            {
                _logger.LogWarning("GeofencesRepository.AddVehicleToGeofenceStateAsync -- Intento de inserción duplicada (VehicleId: {VId}, GeofenceId: {GId}). El estado ya existía.", vehicleId, geofenceId);
                return false; // No fue una nueva inserción
            }
            _logger.LogError(ex, "Error en GeofencesRepository.AddVehicleToGeofenceStateAsync (VId: {VId}, GId: {GId})", vehicleId, geofenceId);
            return false;
        }
    }

    /// <summary>
    /// Elimina un registro de estado de 'dat_equipos_en_geocercas'.
    /// Esta operación es llamada por el GeofencingProcessor cuando detecta una SALIDA.
    /// </summary>
    /// <param name="vehicleId">El ID del equipo</param>
    /// <param name="geofenceId">El ID de la geocerca (de cat_geocercas)</param>
    /// <returns>True si la eliminación fue exitosa.</returns>
    public async Task<bool> RemoveVehicleFromGeofenceStateAsync(long vehicleId, long geofenceId)
    {
        try
        {
            await using var connection = new SqlConnection(_dbSettings.Telematic);
            await connection.OpenAsync();

            const string query = @"
                DELETE FROM dbo.dat_equipos_en_geocercas 
                WHERE id_equipo = @id_equipo AND id_geocerca = @id_geocerca;
            ";

            await using var command = new SqlCommand(query, connection);
            command.Parameters.AddWithValue("@id_equipo", vehicleId);
            command.Parameters.AddWithValue("@id_geocerca", geofenceId);

            int rowsAffected = await command.ExecuteNonQueryAsync();
            return rowsAffected > 0;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error en GeofencesRepository.RemoveVehicleFromGeofenceStateAsync (VId: {VId}, GId: {GId})", vehicleId, geofenceId);
            return false;
        }
    }

}