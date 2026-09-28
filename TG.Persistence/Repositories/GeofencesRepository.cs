using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NetTopologySuite;
using NetTopologySuite.Geometries;
using NetTopologySuite.IO;
using Npgsql;
using SharedTelematic.Entities.Geofences;
using TG.Entities.Geofences;
using TG.Persistence.Interfaces;
using TG.Persistence.Settings;

namespace TG.Persistence.Repositories;

/// <summary>
/// Record que mapea exactamente con el Composite Type 'public.type_geofence_event_batch' en PostgreSQL.
/// Sustituye al antiguo DataTable para inserciones masivas de alto rendimiento.
/// </summary>
public record TypeGeofenceEventBatch(
    int temp_id,
    long id_gps,
    long id_equipo,
    decimal latitud,
    decimal longitud,
    decimal odometro,
    decimal velocidad,
    decimal velocidad_maxima_kmh,
    decimal velocidad_promedio_kmh,
    decimal orientacion,
    DateTime fechahora_utc,
    DateTime fechahora_utc_recepcion,
    int evento,
    long id_geoespacial,
    string nombre_geoespacial,
    int tipo_geoespacial,
    decimal tiempo_estancia_segundos
);

/// <summary>
/// Repositorio para gestionar geocercas (circulares y poligonales).
/// 
/// OBJETIVO PRINCIPAL:
/// Extraer las geometrías de la base de datos usando PostGIS, 
/// inyectar eventos históricos en lote, y mantener el estado actual de los equipos dentro de las geocercas.
/// </summary>
public class GeofencesRepository : BaseRepository<Geofence>, IGeofencesRepository
{
    // Un lector de WKT (Well-Known Text) de NetTopologySuite.
    // Es reutilizable y seguro para hilos.
    private readonly WKTReader _wktReader;
    private readonly NpgsqlDataSource _dataSource; // Data Source para Npgsql 8+

    public GeofencesRepository(
        IOptions<DatabaseSettings> dbSettings,
        ILogger<GeofencesRepository> logger,
        NpgsqlDataSource dataSource) : base(dbSettings, logger)
    {
        _dataSource = dataSource;

        // Inicializamos el lector. SRID 4326 es el estándar para Lat/Lon.
        var precisionModel = new PrecisionModel();
        int srid = 4326;

        // Creamos un GeometryFactory con esas especificaciones
        var geometryFactory = new GeometryFactory(precisionModel, srid);

        // Esto le dice a NetTopologySuite cómo debe manejar las geometrías
        var services = new NtsGeometryServices(
            geometryFactory.CoordinateSequenceFactory,
            geometryFactory.PrecisionModel,
            geometryFactory.SRID
        );

        _wktReader = new WKTReader(services);
    }

    /// <summary>
    /// Obtiene el detalle espacial de una geocerca específica por su ID,
    /// incluyendo su geometría (convertida de PostGIS a WKT) y su AccountId.
    /// </summary>
    public async Task<Geofence?> GetByIdSpatialAsync(long geofenceId)
    {
        if (geofenceId <= 0) return null;

        try
        {
            await using var connection = await _dataSource.OpenConnectionAsync();

            // En PostgreSQL (PostGIS), usamos ST_AsText para extraer la geometría.
            // Se elimina el 'WITH (NOLOCK)' ya que Postgres utiliza MVCC y no bloquea lecturas.
            const string query = @"
                SELECT 
                    g.id_geocerca,
                    g.id_cuenta,
                    g.nombre,
                    g.tipo_geocerca,
                    g.latitud_centro,
                    g.longitud_centro,
                    g.radio_metros,
                    ST_AsText(g.geometria) AS geometria_wkt
                FROM 
                    public.cat_geocercas g
                WHERE 
                    g.id_geocerca = @geofenceId 
                    AND g.estado = 1;";

            await using var command = new NpgsqlCommand(query, connection);
            command.Parameters.AddWithValue("@geofenceId", geofenceId);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                var geofence = new Geofence
                {
                    GeofenceId = reader.GetInt64(reader.GetOrdinal("id_geocerca")),
                    AccountId = reader.GetInt32(reader.GetOrdinal("id_cuenta")),
                    Name = reader.GetString(reader.GetOrdinal("nombre")),
                    Type = ParseGeofenceType(reader.GetString(reader.GetOrdinal("tipo_geocerca")))
                };

                // Procesamiento condicional según el tipo primitivo de la geocerca
                if (geofence.Type == GeofenceType.Circulo)
                {
                    geofence.CenterLatitude = Convert.ToDouble(reader.GetDecimal(reader.GetOrdinal("latitud_centro")));
                    geofence.CenterLongitude = Convert.ToDouble(reader.GetDecimal(reader.GetOrdinal("longitud_centro")));
                    geofence.RadiusMeters = Convert.ToDouble(reader.GetInt32(reader.GetOrdinal("radio_metros")));
                }
                else if (geofence.Type == GeofenceType.Poligono)
                {
                    int wktOrdinal = reader.GetOrdinal("geometria_wkt");
                    string? wkt = reader.IsDBNull(wktOrdinal) ? null : reader.GetString(wktOrdinal);

                    if (!string.IsNullOrEmpty(wkt))
                    {
                        geofence.Geometry = _wktReader.Read(wkt);
                    }
                }

                return geofence;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error al obtener el detalle espacial de la geocerca ID: {GeofenceId}", geofenceId);
            throw;
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
            await using var connection = await _dataSource.OpenConnectionAsync();

            const string query = @"
                SELECT 
                    g.id_geocerca,
                    g.id_cuenta,
                    g.nombre,
                    g.tipo_geocerca,
                    g.latitud_centro,
                    g.longitud_centro,
                    g.radio_metros,
                    ST_AsText(g.geometria) AS geometria_wkt
                FROM 
                    public.cat_geocercas g
                WHERE 
                    g.estado = 1;";

            await using var command = new NpgsqlCommand(query, connection);
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
                    geofence.CenterLatitude = Convert.ToDouble(reader.GetDecimal(reader.GetOrdinal("latitud_centro")));
                    geofence.CenterLongitude = Convert.ToDouble(reader.GetDecimal(reader.GetOrdinal("longitud_centro")));
                    geofence.RadiusMeters = Convert.ToDouble(reader.GetInt32(reader.GetOrdinal("radio_metros")));
                }
                else if (geofence.Type == GeofenceType.Poligono)
                {
                    int wktOrdinal = reader.GetOrdinal("geometria_wkt");
                    string? wkt = reader.IsDBNull(wktOrdinal) ? null : reader.GetString(wktOrdinal);

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
    /// utilizando un arreglo de Tipos Compuestos de PostgreSQL.
    /// </summary>
    /// <param name="eventBatch">La lista de eventos de geocerca a insertar.</param>
    /// <returns>
    /// Un diccionario que mapea el índice original de cada evento en la lista de entrada (TempId)
    /// a su nuevo GpsId generado por la base de datos.
    /// </returns>
    public async Task<Dictionary<int, long>> AddGeofenceEventBatchAsync(List<GeofenceEventData> eventBatch)
    {
        var idMap = new Dictionary<int, long>();
        if (!eventBatch.Any()) return idMap;
        // Construir la lista tipada mapeada al tipo compuesto de PostgreSQL
        var mappedBatch = eventBatch.Select((ev, index) => new TypeGeofenceEventBatch(
            index, // TempId es el índice original
            ev.GpsId,
            ev.VehicleId,
            (decimal)ev.Latitude,
            (decimal)ev.Longitude,
            (decimal)ev.Odometer,
            (decimal)ev.Speed,
            (decimal)ev.MaxSpeedKmh,
            (decimal)ev.AvgSpeedKmh,
            (decimal)ev.Orientation,
            DateTime.SpecifyKind(ev.DateTimeUtc, DateTimeKind.Utc),
            DateTime.SpecifyKind(ev.ReceptionDateTimeUtc, DateTimeKind.Utc),
            ev.EventType,
            ev.GeofenceKey,
            ev.GeofenceName,
            ev.GeofenceType,
            (decimal)ev.DwellTimeSeconds
        )).ToList();

        try
        {
            // Construimos un DataSource específico para History que conozca el tipo compuesto
            var dataSourceBuilder = new NpgsqlDataSourceBuilder(_dbSettings.History);
            dataSourceBuilder.MapComposite<TypeGeofenceEventBatch>("public.type_geofence_event_batch");
            await using var historyDataSource = dataSourceBuilder.Build();

            await using var connection = await historyDataSource.OpenConnectionAsync();

            const string sql = "SELECT out_temp_id, out_id_gps FROM public.usp_insert_geofence_event_batch(@batch);";

            await using var command = new NpgsqlCommand(sql, connection);
            command.CommandTimeout = 120;

            // Declaración estricta del arreglo de tipos compuestos
            command.Parameters.Add(new NpgsqlParameter("batch", mappedBatch)
            {
                DataTypeName = "public.type_geofence_event_batch[]"
            });

            await using var reader = await command.ExecuteReaderAsync();
            while (await reader.ReadAsync())
            {
                idMap.Add(reader.GetInt32(0), reader.GetInt64(1));
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "AddGeofenceEventBatchAsync -- Error catastrófico durante la inserción masiva de eventos de geocerca.");
            throw;
        }

        return idMap;
    }

    /// <summary>
    /// Parsea el tipo de geocerca desde cadena a enum.
    /// </summary>
    private GeofenceType ParseGeofenceType(string type) => type switch
    {
        "CIRCULO" => GeofenceType.Circulo,
        "POLIGONO" => GeofenceType.Poligono,
        _ => throw new ArgumentException($"Tipo de geocerca no reconocido: {type}")
    };

    /// <summary>
    /// Inserta un registro de estado en la tabla 'dat_equipos_en_geocercas'.
    /// Aprovecha 'ON CONFLICT DO NOTHING' para ignorar automáticamente registros duplicados.
    /// </summary>
    public async Task<bool> AddVehicleToGeofenceStateAsync(long vehicleId, long geofenceId, DateTime entryTimeUtc)
    {
        try
        {
            await using var connection = await _dataSource.OpenConnectionAsync();

            // Utilizamos ON CONFLICT DO NOTHING en lugar de atrapar la excepción
            const string query = @"
                INSERT INTO public.dat_equipos_en_geocercas (id_equipo, id_geocerca, fecha_utc_entrada)
                VALUES (@id_equipo, @id_geocerca, @fecha_utc_entrada)
                ON CONFLICT (id_equipo, id_geocerca) DO NOTHING;
            ";

            await using var command = new NpgsqlCommand(query, connection);
            command.Parameters.AddWithValue("@id_equipo", vehicleId);
            command.Parameters.AddWithValue("@id_geocerca", geofenceId);
            command.Parameters.AddWithValue("@fecha_utc_entrada", DateTime.SpecifyKind(entryTimeUtc, DateTimeKind.Utc));

            int rowsAffected = await command.ExecuteNonQueryAsync();

            if (rowsAffected == 0)
            {
                _logger.LogWarning("GeofencesRepository.AddVehicleToGeofenceStateAsync -- Intento de inserción duplicada (VehicleId: {VId}, GeofenceId: {GId}). El estado ya existía.", vehicleId, geofenceId);
                return false;
            }

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error en GeofencesRepository.AddVehicleToGeofenceStateAsync (VId: {VId}, GId: {GId})", vehicleId, geofenceId);
            return false;
        }
    }

    /// <summary>
    /// Elimina un registro de estado de 'dat_equipos_en_geocercas'.
    /// Esta operación es llamada por el GeofencingProcessor cuando detecta una SALIDA.
    /// </summary>
    public async Task<bool> RemoveVehicleFromGeofenceStateAsync(long vehicleId, long geofenceId)
    {
        try
        {
            await using var connection = await _dataSource.OpenConnectionAsync();

            const string query = @"
                DELETE FROM public.dat_equipos_en_geocercas 
                WHERE id_equipo = @id_equipo AND id_geocerca = @id_geocerca;
            ";

            await using var command = new NpgsqlCommand(query, connection);
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