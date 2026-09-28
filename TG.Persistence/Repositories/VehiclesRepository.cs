using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Npgsql; // Reemplaza a Microsoft.Data.SqlClient
using SharedTelematic.Entities.Gps;
using SharedTelematic.Entities.Vehicles;
using TG.Persistence.Interfaces;
using TG.Persistence.Settings;

namespace TG.Persistence.Repositories;

public class VehiclesRepository : BaseRepository<Vehicle>, IVehiclesRepository
{
    private readonly NpgsqlDataSource _dataSource;

    // DEFINICIÓN DE LA CONSULTA BASE (Optimizada y "adelgazada" para Geocercas)
    private const string _baseVehicleQuery = @"
        SELECT
            ce.id_equipo, 
            ce.id_cuenta,
            ce.tag, 
            ce.id_equipo_cliente,

            deae.latitud, deae.longitud, deae.altitud, deae.velocidad, deae.orientacion,
            deae.ignicion, deae.odometro_acumulado, deae.segundos_motor_acumulado,
            -- CAMBIO 2: Eliminamos contrasena, trafico_gprs_acumulado, ip_servidor y puerto_servidor
        
            COALESCE(deae.fecha_ulitmo_paquete_utc, NOW() AT TIME ZONE 'UTC' - INTERVAL '1 year') AS fecha_ulitmo_paquete_utc,
            COALESCE(deae.fecha_ultimo_ping, NOW() AT TIME ZONE 'UTC' - INTERVAL '1 year') AS fecha_ultimo_ping,
            COALESCE(deae.fecha_ultima_ignicion_utc, NOW() AT TIME ZONE 'UTC' - INTERVAL '1 year') AS fecha_ultima_ignicion_utc,
           
            -- Reconstrucción autoritativa del estado de geocercas
            COALESCE(geofences.CurrentGeofenceKeys, '') AS CurrentGeofenceKeys
                       
        FROM public.cat_equipos ce
        LEFT JOIN public.dat_estado_actual_equipos deae ON ce.id_equipo = deae.id_equipo
        LEFT JOIN (
            SELECT 
                deeg.id_equipo,
                STRING_AGG(CONCAT(deeg.id_geocerca, '|', cg.tipo_geocerca, '|', TO_CHAR(deeg.fecha_utc_entrada, 'YYYY-MM-DD""T""HH24:MI:SS.US""Z""')), ',') AS CurrentGeofenceKeys
            FROM public.dat_equipos_en_geocercas deeg
            INNER JOIN public.cat_geocercas cg ON deeg.id_geocerca = cg.id_geocerca 
            GROUP BY deeg.id_equipo
        ) AS geofences ON ce.id_equipo = geofences.id_equipo
        WHERE ce.estado > -2";

    public VehiclesRepository(IOptions<DatabaseSettings> dbSettings, ILogger<VehiclesRepository> logger, NpgsqlDataSource dataSource)
        : base(dbSettings, logger)
    {
        _dataSource = dataSource;
    }

    /// <summary>
    /// Regresa la información de un vehículo a través de su Id de forma asíncrona,
    /// incluyendo su último estado GPS y las geocercas en las que se encuentra.
    /// </summary>
    /// <returns>El vehículo encontrado o null si no existe.</returns>
    public async Task<Vehicle?> GetByVehicleIdAsync(long vehicleId)
    {
        if (vehicleId <= 0) return null;

        try
        {
            await using var connection = await _dataSource.OpenConnectionAsync();

            // Usamos la consulta base y agregamos el filtro (AND debido a que ya hay un WHERE)
            const string query = _baseVehicleQuery + " AND ce.id_equipo = @id_equipo;";

            await using var command = new NpgsqlCommand(query, connection);
            command.Parameters.AddWithValue("@id_equipo", vehicleId);

            await using var reader = await command.ExecuteReaderAsync();

            if (await reader.ReadAsync())
            {
                // Usamos el método de mapeo centralizado
                return MapReaderToVehicle(reader);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "VehiclesRepository.GetByVehicleIdAsync -- Error al obtener el vehículo con ID {VehicleId}.", vehicleId);
        }

        return null; // Retorna null si no se encontró o si ocurrió un error
    }

    /// <summary>
    /// Obtiene una lista de todos los vehículos activos con su último estado conocido.
    /// Este método está optimizado para la carga inicial de la caché ("cache warmer").
    /// Reconstruye el estado de las geocercas a partir de la tabla autoritativa
    /// 'dat_equipos_en_geocercas' para garantizar la máxima consistencia.
    /// </summary>
    /// <returns>Una colección de objetos Vehicle con su estado completo.</returns>
    public async Task<IEnumerable<Vehicle>> GetAllVehiclesWithStateAsync()
    {
        var vehicles = new List<Vehicle>();
        try
        {
            await using var connection = await _dataSource.OpenConnectionAsync();

            // Usamos la consulta base agregando el terminador
            const string query = _baseVehicleQuery + ";";

            await using var command = new NpgsqlCommand(query, connection);
            await using var reader = await command.ExecuteReaderAsync();

            while (await reader.ReadAsync())
            {
                // Usamos el método de mapeo centralizado
                vehicles.Add(MapReaderToVehicle(reader));
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "VehiclesRepository.GetAllVehiclesWithStateAsync -- Error masivo al obtener todos los vehículos para el caché.");
        }
        return vehicles;
    }

    /// <summary>
    /// Método helper privado para mapear un registro de NpgsqlDataReader a un objeto Vehicle.
    /// </summary>
    private Vehicle MapReaderToVehicle(NpgsqlDataReader reader)
    {
        int ordLat = reader.GetOrdinal("latitud");
        int ordLng = reader.GetOrdinal("longitud");
        int ordAlt = reader.GetOrdinal("altitud");
        int ordSpd = reader.GetOrdinal("velocidad");
        int ordOri = reader.GetOrdinal("orientacion");
        int ordIgn = reader.GetOrdinal("ignicion");
        int ordOdo = reader.GetOrdinal("odometro_acumulado");
        int ordEng = reader.GetOrdinal("segundos_motor_acumulado");
        // 👉 Se eliminaron ordGps y ordPort

        var avlData = new AvlData.AvlDataBuilder()
            .SetVehicleId(Convert.ToInt64(reader["id_equipo"]))
            .SetImei(reader["id_equipo_cliente"]?.ToString() ?? "0")
            .SetName(reader["tag"]?.ToString() ?? "")
            .SetLat(reader.IsDBNull(ordLat) ? 0.0 : Convert.ToDouble(reader[ordLat]))
            .SetLng(reader.IsDBNull(ordLng) ? 0.0 : Convert.ToDouble(reader[ordLng]))
            .SetAltitude(reader.IsDBNull(ordAlt) ? 0.0 : Convert.ToDouble(reader[ordAlt]))
            .SetSpeed(reader.IsDBNull(ordSpd) ? 0.0 : Convert.ToDouble(reader[ordSpd]))
            .SetOrientation(reader.IsDBNull(ordOri) ? 0.0 : Convert.ToDouble(reader[ordOri]))
            .SetIgnition(reader.IsDBNull(ordIgn) ? false : Convert.ToBoolean(reader[ordIgn]))
            .SetOdometer(reader.IsDBNull(ordOdo) ? 0.0 : Convert.ToDouble(reader[ordOdo]))
            .SetEngineSecondsTotal(reader.IsDBNull(ordEng) ? 0.0 : Convert.ToDouble(reader[ordEng]))
            // 👉 Se eliminó .SetGprsTrafficAccumulated
            .SetDateTimeUtc(Convert.ToDateTime(reader["fecha_ulitmo_paquete_utc"]))
            .SetLastIgnitionOnTimeUtc(Convert.ToDateTime(reader["fecha_ultima_ignicion_utc"]))
            .SetGeofenceKeys(reader["CurrentGeofenceKeys"]?.ToString() ?? "")
            .Build();

        return new Vehicle
        {
            Imei = reader["id_equipo_cliente"]!.ToString() ?? "",
            VehicleId = Convert.ToInt64(reader["id_equipo"]),
            AccountId = Convert.ToInt32(reader["id_cuenta"]), // 👉 CAMBIO 3: Mapeo de la cuenta hacia el objeto Vehicle
            Tag = reader["tag"]!.ToString() ?? "",
            LastPingDate = Convert.ToDateTime(reader["fecha_ultimo_ping"]),
            AvlData = avlData
            // 👉 CAMBIO 4: Se eliminaron Access, Port y Server, ya que no son necesarios para este caché en RAM.
        };
    }
}