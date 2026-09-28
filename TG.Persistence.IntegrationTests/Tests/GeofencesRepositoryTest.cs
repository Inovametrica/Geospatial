using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using NetTopologySuite.Geometries;
using Npgsql;
using SharedTelematic.Entities.Geofences;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TG.Entities.Geofences;
using TG.Persistence.IntegrationTests.Fixtures;
using TG.Persistence.Repositories;
using TG.Persistence.Settings;
using Xunit;

namespace TG.Persistence.IntegrationTests.Tests
{
    [Collection("PostgresCollection")]
    public class GeofencesRepositoryTest : IAsyncLifetime
    {
        private readonly PostgresTestcontainerFixture _fixture;
        private readonly string _telematicDb;
        private readonly string _historyDb;

        public GeofencesRepositoryTest(PostgresTestcontainerFixture fixture)
        {
            _fixture = fixture;
            _telematicDb = fixture.TelematicConnectionString;
            _historyDb = fixture.HistoryConnectionString;
        }

        public async Task InitializeAsync()
        {
            // ========================================================================
            // 1. CONFIGURACIÓN DE LA BASE DE DATOS TELEMATIC (Catálogos y Estados)
            // ========================================================================
            await using var connectionTel = new NpgsqlConnection(_telematicDb);
            await connectionTel.OpenAsync();

            const string setupTelematicSql = @"
                -- PostGIS es requerido para las columnas espaciales
                CREATE EXTENSION IF NOT EXISTS postgis;

                -- Tablas de dependencia para cat_equipos y cat_geocercas, para asegurar aislamiento
                CREATE TABLE IF NOT EXISTS public.cat_cuentas (
                    id_cuenta INT PRIMARY KEY,
                    nombre_cuenta VARCHAR(255),
                    estado INT
                );
                CREATE TABLE IF NOT EXISTS public.cat_usuarios (
                    id_usuario INT PRIMARY KEY,
                    id_cuenta INT,
                    correo_electronico VARCHAR(255),
                    clave VARCHAR(255),
                    estado INT,
                    nombre_completo VARCHAR(255),
                    nombre_corto VARCHAR(50)
                );
                CREATE TABLE IF NOT EXISTS public.cat_tipos_unidad (
                    id_tipo_unidad INT PRIMARY KEY,
                    nombre VARCHAR(255)
                );
                CREATE TABLE IF NOT EXISTS public.cat_fabricantes_dispositivos (
                    id_fabricante INT PRIMARY KEY,
                    nombre VARCHAR(255)
                );
                CREATE TABLE IF NOT EXISTS public.cat_modelos_dispositivo (
                    id_modelo_dispositivo INT PRIMARY KEY,
                    id_fabricante INT,
                    nombre_modelo VARCHAR(255)
                );
                CREATE TABLE IF NOT EXISTS public.cat_equipos (
                    id_equipo BIGINT PRIMARY KEY,
                    id_cuenta INT,
                    tag VARCHAR(255),
                    id_equipo_cliente VARCHAR(50),
                    estado INT,
                    id_tipo_unidad INT,
                    id_modelo_dispositivo INT,
                    id_usuario_creador INT
                );

                CREATE TABLE IF NOT EXISTS public.cat_geocercas (
                    id_geocerca BIGSERIAL PRIMARY KEY,
                    id_cuenta INT NOT NULL,
                    nombre VARCHAR(255),
                    tipo_geocerca VARCHAR(50),
                    latitud_centro DECIMAL(18,6),
                    longitud_centro DECIMAL(18,6),
                    radio_metros INT,
                    estado INT,
                    geometria GEOMETRY,
                    id_usuario_creador INT
                );

                CREATE TABLE IF NOT EXISTS public.dat_equipos_en_geocercas (
                    id_equipo BIGINT,
                    id_geocerca BIGINT,
                    fecha_utc_entrada TIMESTAMPTZ,
                    PRIMARY KEY (id_equipo, id_geocerca)
                );

                -- Limpieza completa para aislamiento de pruebas
                TRUNCATE TABLE public.cat_geocercas, public.dat_equipos_en_geocercas, public.cat_equipos, public.cat_cuentas, public.cat_usuarios, public.cat_tipos_unidad, public.cat_fabricantes_dispositivos, public.cat_modelos_dispositivo RESTART IDENTITY CASCADE;
            ";
            await using (var cmd = new NpgsqlCommand(setupTelematicSql, connectionTel))
            {
                await cmd.ExecuteNonQueryAsync();
            }

            // ========================================================================
            // 2. CONFIGURACIÓN DE LA BASE DE DATOS HISTORY (Eventos Masivos)
            // ========================================================================
            await using var connectionHist = new NpgsqlConnection(_historyDb);
            await connectionHist.OpenAsync();

            const string setupHistorySql = @"
                CREATE TABLE IF NOT EXISTS public.dat_geoespacial_eventos (
                    id_gps BIGINT,
                    id_equipo BIGINT,
                    latitud DECIMAL(18, 6),
                    longitud DECIMAL(18, 6),
                    odometro DECIMAL(18, 3),
                    velocidad DECIMAL(18, 3),
                    velocidad_maxima_kmh DECIMAL(18, 3),
                    velocidad_promedio_kmh DECIMAL(18, 3),
                    orientacion DECIMAL(18, 3),
                    fechahora_utc TIMESTAMPTZ,
                    fechahora_utc_recepcion TIMESTAMPTZ,
                    evento INT,
                    id_geoespacial BIGINT,
                    nombre_geoespacial VARCHAR(100),
                    tipo_geoespacial SMALLINT,
                    tiempo_estancia_segundos DECIMAL(18, 3)
                );

                TRUNCATE TABLE public.dat_geoespacial_eventos;

                -- Tipos compuestos requeridos
                DO $$
                BEGIN
                    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'type_geofence_event_batch') THEN
                        CREATE TYPE public.type_geofence_event_batch AS (
                            temp_id INT,
                            id_gps BIGINT,
                            id_equipo BIGINT,
                            latitud DECIMAL(18, 6),
                            longitud DECIMAL(18, 6),
                            odometro DECIMAL(18, 3),
                            velocidad DECIMAL(18, 3),
                            velocidad_maxima_kmh DECIMAL(18, 3),
                            velocidad_promedio_kmh DECIMAL(18, 3),
                            orientacion DECIMAL(18, 3),
                            fechahora_utc TIMESTAMPTZ,
                            fechahora_utc_recepcion TIMESTAMPTZ,
                            evento INT,
                            id_geoespacial BIGINT,
                            nombre_geoespacial VARCHAR(100),
                            tipo_geoespacial SMALLINT,
                            tiempo_estancia_segundos DECIMAL(18, 3)
                        );
                    END IF;
                END$$;

                DROP FUNCTION IF EXISTS public.usp_insert_geofence_event_batch(public.type_geofence_event_batch[]);

                CREATE OR REPLACE FUNCTION public.usp_insert_geofence_event_batch(p_batch public.type_geofence_event_batch[])
                RETURNS TABLE (out_temp_id INT, out_id_gps BIGINT) LANGUAGE plpgsql AS $$
                BEGIN
                    INSERT INTO public.dat_geoespacial_eventos (
                        id_gps, id_equipo, latitud, longitud, odometro, velocidad, velocidad_maxima_kmh,
                        velocidad_promedio_kmh, orientacion, fechahora_utc, fechahora_utc_recepcion, evento,
                        id_geoespacial, nombre_geoespacial, tipo_geoespacial, tiempo_estancia_segundos
                    )
                    SELECT
                        b.id_gps, b.id_equipo, b.latitud, b.longitud, b.odometro, b.velocidad, b.velocidad_maxima_kmh,
                        b.velocidad_promedio_kmh, b.orientacion, b.fechahora_utc, b.fechahora_utc_recepcion, b.evento,
                        b.id_geoespacial, b.nombre_geoespacial, b.tipo_geoespacial, b.tiempo_estancia_segundos
                    FROM unnest(p_batch) AS b;

                    RETURN QUERY SELECT b.temp_id, b.id_gps FROM unnest(p_batch) AS b;
                END;
                $$;
            ";
            await using (var cmd = new NpgsqlCommand(setupHistorySql, connectionHist))
            {
                await cmd.ExecuteNonQueryAsync();
            }
        }

        public Task DisposeAsync() => Task.CompletedTask;

        /// <summary>
        /// Crea el repositorio inyectando ambas bases de datos.
        /// NOTA: El repositorio utiliza NpgsqlDataSource mapeado a History para el batch,
        /// pero instancia NpgsqlConnection internamente para Telematic.
        /// </summary>
        private GeofencesRepository CreateRepository()
        {
            var dbSettings = Options.Create(new DatabaseSettings
            {
                Telematic = _telematicDb,
                History = _historyDb
            });
            var logger = NullLogger<GeofencesRepository>.Instance;

            // El repositorio usa este DataSource internamente para lecturas/estados, así que DEBE apuntar a Telematic
            var dataSourceBuilder = new NpgsqlDataSourceBuilder(_telematicDb);
            var dataSource = dataSourceBuilder.Build();

            return new GeofencesRepository(dbSettings, logger, dataSource);
        }

        private async Task SeedVehicleAsync(long vehicleId)
        {
            await using var connection = new NpgsqlConnection(_telematicDb);
            await connection.OpenAsync();

            // Aseguramos dependencias mínimas para que cat_equipos no falle por llaves foráneas
            await new NpgsqlCommand("INSERT INTO public.cat_cuentas (id_cuenta, nombre_cuenta, estado) VALUES (1, 'Cuenta Prueba', 1) ON CONFLICT DO NOTHING;", connection).ExecuteNonQueryAsync();
            await new NpgsqlCommand("INSERT INTO public.cat_tipos_unidad (id_tipo_unidad, nombre) VALUES (1, 'Tipo Prueba') ON CONFLICT DO NOTHING;", connection).ExecuteNonQueryAsync();
            await new NpgsqlCommand("INSERT INTO public.cat_fabricantes_dispositivos (id_fabricante, nombre) VALUES (1, 'Fabricante') ON CONFLICT DO NOTHING;", connection).ExecuteNonQueryAsync();
            await new NpgsqlCommand("INSERT INTO public.cat_modelos_dispositivo (id_modelo_dispositivo, id_fabricante, nombre_modelo) VALUES (1, 1, 'Modelo') ON CONFLICT DO NOTHING;", connection).ExecuteNonQueryAsync();
            await new NpgsqlCommand("INSERT INTO public.cat_usuarios (id_usuario, id_cuenta, correo_electronico, clave, estado, nombre_completo, nombre_corto) VALUES (1, 1, 'test@test.com', 'hash', 1, 'Usuario', 'Usu') ON CONFLICT DO NOTHING;", connection).ExecuteNonQueryAsync();

            const string sql = @"
                INSERT INTO public.cat_equipos (id_equipo, id_cuenta, tag, id_equipo_cliente, estado, id_tipo_unidad, id_modelo_dispositivo, id_usuario_creador)
                VALUES (@id, 1, 'Vehiculo Prueba', 'IMEI-TEST', 1, 1, 1, 1)
                ON CONFLICT DO NOTHING;";
            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("@id", vehicleId);
            await command.ExecuteNonQueryAsync();
        }

        #region Helpers de Sembrado

        private async Task<long> SeedGeofenceAsync(string name, string type, double lat = 0, double lng = 0, int radius = 0, string? wkt = null, int status = 1, int accountId = 1, int creatorId = 1)
        {
            await using var connection = new NpgsqlConnection(_telematicDb);
            await connection.OpenAsync();

            // 1. Insertamos la cuenta (preventivo para FK)
            const string seedAccountSql = @"
                INSERT INTO public.cat_cuentas (id_cuenta, nombre_cuenta, estado) 
                VALUES (@account, 'Cuenta Prueba', 1) 
                ON CONFLICT DO NOTHING;";
            await using var accountCommand = new NpgsqlCommand(seedAccountSql, connection);
            accountCommand.Parameters.AddWithValue("@account", accountId);
            await accountCommand.ExecuteNonQueryAsync();

            // 2. Insertamos el usuario (preventivo para FK)
            const string seedUserSql = @"
                INSERT INTO public.cat_usuarios (id_usuario, id_cuenta, correo_electronico, clave, estado, nombre_completo, nombre_corto) 
                VALUES (@creatorId, @account, 'test@test.com', 'hash', 1, 'Usuario', 'Usu') 
                ON CONFLICT DO NOTHING;";
            await using var userCommand = new NpgsqlCommand(seedUserSql, connection);
            userCommand.Parameters.AddWithValue("@creatorId", creatorId);
            userCommand.Parameters.AddWithValue("@account", accountId);
            await userCommand.ExecuteNonQueryAsync();

            // 3. Insertamos la geocerca 
            // NOTA: Agregamos el casteo explícito ::text a @wkt para evitar el error 42P08
            const string sql = @"
                INSERT INTO public.cat_geocercas (
                    id_cuenta, nombre, tipo_geocerca, latitud_centro, longitud_centro, 
                    radio_metros, estado, geometria, id_usuario_creador
                )
                VALUES (
                    @account, @name, @type, @lat, @lng, 
                    @radius, @status, 
                    CASE WHEN @wkt::text IS NOT NULL THEN ST_GeomFromText(@wkt::text, 4326) ELSE NULL END, 
                    @creatorId
                )
                RETURNING id_geocerca;";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("@account", accountId);
            command.Parameters.AddWithValue("@name", name);
            command.Parameters.AddWithValue("@type", type);
            command.Parameters.AddWithValue("@lat", lat);
            command.Parameters.AddWithValue("@lng", lng);
            command.Parameters.AddWithValue("@radius", radius);
            command.Parameters.AddWithValue("@status", status);
            command.Parameters.AddWithValue("@wkt", wkt ?? (object)DBNull.Value);
            command.Parameters.AddWithValue("@creatorId", creatorId);

            return Convert.ToInt64(await command.ExecuteScalarAsync());
        }

        #endregion

        #region Pruebas de Lectura Espacial

        [Fact]
        public async Task GetByIdSpatialAsync_WithCircularGeofence_ShouldReturnGeofence()
        {
            // Arrange
            var repo = CreateRepository();
            var id = await SeedGeofenceAsync("Circulo 1", "CIRCULO", 19.4326, -99.1332, 150);

            // Act
            var result = await repo.GetByIdSpatialAsync(id);

            // Assert
            result.Should().NotBeNull();
            result!.Name.Should().Be("Circulo 1");
            result.Type.Should().Be(GeofenceType.Circulo);
            result.CenterLatitude.Should().Be(19.4326);
            result.CenterLongitude.Should().Be(-99.1332);
            result.RadiusMeters.Should().Be(150);
        }

        [Fact]
        public async Task GetByIdSpatialAsync_WithPolygonGeofence_ShouldReturnGeofenceWithGeometry()
        {
            // Arrange
            var repo = CreateRepository();
            string wkt = "POLYGON((0 0, 0 10, 10 10, 10 0, 0 0))";
            var id = await SeedGeofenceAsync("Poligono 1", "POLIGONO", wkt: wkt);

            // Act
            var result = await repo.GetByIdSpatialAsync(id);

            // Assert
            result.Should().NotBeNull();
            result!.Name.Should().Be("Poligono 1");
            result.Type.Should().Be(GeofenceType.Poligono);
            result.Geometry.Should().NotBeNull();
            result.Geometry.GeometryType.Should().Be("Polygon");
        }

        [Fact]
        public async Task GetAllSpatialGeofencesAsync_ShouldReturnOnlyActiveGeofences()
        {
            // Arrange
            var repo = CreateRepository();
            await SeedGeofenceAsync("Activa 1", "CIRCULO", status: 1);
            await SeedGeofenceAsync("Inactiva 1", "CIRCULO", status: 0);
            await SeedGeofenceAsync("Activa 2", "POLIGONO", wkt: "POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))", status: 1);

            // Act
            var result = await repo.GetAllSpatialGeofencesAsync();

            // Assert
            result.Should().HaveCount(2);
            result.Should().Contain(g => g.Name == "Activa 1");
            result.Should().Contain(g => g.Name == "Activa 2");
            result.Should().NotContain(g => g.Name == "Inactiva 1");
        }

        [Fact]
        public async Task GetByIdSpatialAsync_WhenGeofenceDoesNotExist_ShouldReturnNull()
        {
            // Arrange
            var repo = CreateRepository();

            // Act
            var result = await repo.GetByIdSpatialAsync(99999);

            // Assert
            result.Should().BeNull();
        }

        [Fact]
        public async Task GetByIdSpatialAsync_WhenGeofenceIsInactive_ShouldReturnNull()
        {
            // Arrange
            var repo = CreateRepository();
            var id = await SeedGeofenceAsync("Inactiva", "CIRCULO", status: 0);

            // Act
            var result = await repo.GetByIdSpatialAsync(id);

            // Assert
            result.Should().BeNull();
        }

        [Theory]
        [InlineData(0)]
        [InlineData(-1)]
        public async Task GetByIdSpatialAsync_WhenIdIsInvalid_ShouldReturnNull(long invalidId)
        {
            // Arrange
            var repo = CreateRepository();

            // Act
            var result = await repo.GetByIdSpatialAsync(invalidId);

            // Assert
            result.Should().BeNull();
        }

        [Fact]
        public async Task GetAllSpatialGeofencesAsync_WhenNoGeofences_ShouldReturnEmptyList()
        {
            // Arrange
            var repo = CreateRepository();
            // No se siembra ningún dato a propósito

            // Act
            var result = await repo.GetAllSpatialGeofencesAsync();

            // Assert
            result.Should().NotBeNull();
            result.Should().BeEmpty();
        }

        #endregion

        #region Pruebas de Escritura y Estado (ON CONFLICT)

        [Fact]
        public async Task AddGeofenceEventBatchAsync_WithValidBatch_ShouldInsertAndReturnMapping()
        {
            // Arrange
            var repo = CreateRepository();
            var batch = new List<GeofenceEventData>
            {
                new GeofenceEventData { GpsId = 100, VehicleId = 1, DateTimeUtc = DateTime.UtcNow, ReceptionDateTimeUtc = DateTime.UtcNow, GeofenceName = "Z1", GeofenceType = 1 },
                new GeofenceEventData { GpsId = 200, VehicleId = 1, DateTimeUtc = DateTime.UtcNow, ReceptionDateTimeUtc = DateTime.UtcNow, GeofenceName = "Z2", GeofenceType = 2 }
            };

            // Act
            var mapping = await repo.AddGeofenceEventBatchAsync(batch);

            // Assert
            mapping.Should().HaveCount(2);
            mapping[0].Should().Be(100);
            mapping[1].Should().Be(200);

            await using var conn = new NpgsqlConnection(_historyDb);
            await conn.OpenAsync();
            await using var cmd = new NpgsqlCommand("SELECT COUNT(*) FROM public.dat_geoespacial_eventos", conn);
            var count = Convert.ToInt64(await cmd.ExecuteScalarAsync());
            count.Should().Be(2);
        }

        [Fact]
        public async Task AddVehicleToGeofenceStateAsync_WhenNewEntry_ShouldReturnTrue()
        {
            // Arrange
            var repo = CreateRepository();
            await SeedVehicleAsync(101); // Inyectamos el vehículo real
            long geoId = await SeedGeofenceAsync("Geo 1", "CIRCULO"); // Obtenemos un ID de geocerca real generado

            // Act
            var result = await repo.AddVehicleToGeofenceStateAsync(101, geoId, DateTime.UtcNow);

            // Assert
            result.Should().BeTrue();
        }

        [Fact]
        public async Task AddVehicleToGeofenceStateAsync_WhenDuplicateEntry_ShouldDoNothingAndReturnFalse()
        {
            // Arrange
            var repo = CreateRepository();
            await SeedVehicleAsync(101);
            long geoId = await SeedGeofenceAsync("Geo 1", "CIRCULO");

            await repo.AddVehicleToGeofenceStateAsync(101, geoId, DateTime.UtcNow); // Primera inserción exitosa

            // Act
            var result = await repo.AddVehicleToGeofenceStateAsync(101, geoId, DateTime.UtcNow); // Duplicada

            // Assert
            result.Should().BeFalse(); // ON CONFLICT DO NOTHING debe proteger la BD
        }

        [Fact]
        public async Task RemoveVehicleFromGeofenceStateAsync_WhenExists_ShouldReturnTrue()
        {
            // Arrange
            var repo = CreateRepository();
            await SeedVehicleAsync(202);
            long geoId = await SeedGeofenceAsync("Geo 2", "POLIGONO");

            await repo.AddVehicleToGeofenceStateAsync(202, geoId, DateTime.UtcNow); // Lo insertamos primero

            // Act
            var result = await repo.RemoveVehicleFromGeofenceStateAsync(202, geoId);

            // Assert
            result.Should().BeTrue();
        }

        [Fact]
        public async Task AddGeofenceEventBatchAsync_WithEmptyBatch_ShouldReturnEmptyDictionary()
        {
            // Arrange
            var repo = CreateRepository();
            var emptyBatch = new List<GeofenceEventData>();

            // Act
            var mapping = await repo.AddGeofenceEventBatchAsync(emptyBatch);

            // Assert
            mapping.Should().NotBeNull();
            mapping.Should().BeEmpty();
        }

        [Fact]
        public async Task RemoveVehicleFromGeofenceStateAsync_WhenEntryDoesNotExist_ShouldReturnFalse()
        {
            // Arrange
            var repo = CreateRepository();
            long nonExistentVehicleId = 999;
            long nonExistentGeofenceId = 999;

            // Act
            // Intentamos borrar un registro que nunca fue insertado
            var result = await repo.RemoveVehicleFromGeofenceStateAsync(nonExistentVehicleId, nonExistentGeofenceId);

            // Assert
            result.Should().BeFalse();
        }

        #endregion
    }
}