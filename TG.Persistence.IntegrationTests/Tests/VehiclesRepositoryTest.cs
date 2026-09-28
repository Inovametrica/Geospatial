using FluentAssertions;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Npgsql;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using SharedTelematic.Entities.Vehicles;
using TG.Persistence.IntegrationTests.Fixtures;
using TG.Persistence.Repositories;
using TG.Persistence.Settings;
using Xunit;

namespace TG.Persistence.IntegrationTests.Tests
{
    [Collection("PostgresCollection")]
    public class VehiclesRepositoryTest : IAsyncLifetime
    {
        private readonly PostgresTestcontainerFixture _fixture;
        private readonly string _telematicDb;

        public VehiclesRepositoryTest(PostgresTestcontainerFixture fixture)
        {
            _fixture = fixture;
            _telematicDb = fixture.TelematicConnectionString;
        }

        public async Task InitializeAsync()
        {
            await using var connection = new NpgsqlConnection(_telematicDb);
            await connection.OpenAsync();

            // 1. Crear el esquema necesario para reproducir la consulta de VehiclesRepository
            // CORRECCIÓN: Se agregan las tablas y columnas faltantes que los helpers de sembrado necesitan.
            const string setupSql = @"
                -- Forzamos la eliminación para asegurar que el esquema de esta prueba sea el que se aplique
                DROP TABLE IF EXISTS public.dat_equipos_en_geocercas CASCADE;
                DROP TABLE IF EXISTS public.cat_geocercas CASCADE;
                DROP TABLE IF EXISTS public.dat_estado_actual_equipos CASCADE;
                DROP TABLE IF EXISTS public.cat_equipos CASCADE;
                DROP TABLE IF EXISTS public.cat_modelos_dispositivo CASCADE;
                DROP TABLE IF EXISTS public.cat_fabricantes_dispositivos CASCADE;
                DROP TABLE IF EXISTS public.cat_tipos_unidad CASCADE;
                DROP TABLE IF EXISTS public.cat_usuarios CASCADE;
                DROP TABLE IF EXISTS public.cat_cuentas CASCADE;

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
                CREATE TABLE IF NOT EXISTS public.cat_fabricantes_dispositivos (
                    id_fabricante INT PRIMARY KEY,
                    nombre VARCHAR(255)
                );
                CREATE TABLE IF NOT EXISTS public.cat_tipos_unidad (
                    id_tipo_unidad INT PRIMARY KEY,
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

                CREATE TABLE IF NOT EXISTS public.dat_estado_actual_equipos (
                    id_equipo BIGINT PRIMARY KEY,
                    latitud DECIMAL(18,6),
                    longitud DECIMAL(18,6),
                    altitud DECIMAL(18,6),
                    velocidad DECIMAL(18,6),
                    orientacion DECIMAL(18,6),
                    ignicion BOOLEAN,
                    odometro_acumulado DECIMAL(18,6),
                    segundos_motor_acumulado DECIMAL(18,6),
                    fecha_ulitmo_paquete_utc TIMESTAMPTZ,
                    fecha_ultimo_ping TIMESTAMPTZ, 
                    fecha_ultima_ignicion_utc TIMESTAMPTZ,
                    trafico_gprs_acumulado DECIMAL(18,6),
                    tipo_ultimo_paquete INT
                );

                CREATE TABLE IF NOT EXISTS public.cat_geocercas (
                    id_geocerca BIGINT PRIMARY KEY,
                    id_cuenta INT,
                    nombre VARCHAR(255),
                    tipo_geocerca VARCHAR(50),
                    estado INT,
                    id_usuario_creador INT
                );

                CREATE TABLE IF NOT EXISTS public.dat_equipos_en_geocercas (
                    id_equipo BIGINT,
                    id_geocerca BIGINT,
                    fecha_utc_entrada TIMESTAMPTZ,
                    PRIMARY KEY (id_equipo, id_geocerca)
                );

                -- Limpiar tablas antes de cada test
                -- El TRUNCATE ya no es necesario porque el DROP TABLE se encarga de la limpieza completa del esquema y los datos.
            ";

            await using var command = new NpgsqlCommand(setupSql, connection);
            await command.ExecuteNonQueryAsync();
        }

        public Task DisposeAsync() => Task.CompletedTask;

        private VehiclesRepository CreateRepository()
        {
            var dbSettings = Options.Create(new DatabaseSettings { Telematic = _telematicDb });
            var logger = NullLogger<VehiclesRepository>.Instance;

            // NpgsqlDataSource simple, sin tipos compuestos porque esta clase solo hace lecturas estándar
            var dataSourceBuilder = new NpgsqlDataSourceBuilder(_telematicDb);
            var dataSource = dataSourceBuilder.Build();

            return new VehiclesRepository(dbSettings, logger, dataSource);
        }

        #region Helpers de Sembrado

        private async Task SeedVehicleAsync(long vehicleId, int accountId, string tag, string imei, int status = 1, int unitTypeId = 1, int modelId = 1, int creatorId = 1)
        {
            await using var connection = new NpgsqlConnection(_telematicDb);
            await connection.OpenAsync();

            // 1. Insertamos un fabricante falso (preventivo para FK)
            const string seedManufSql = @"
                INSERT INTO public.cat_fabricantes_dispositivos (id_fabricante, nombre) 
                VALUES (1, 'Fabricante Prueba') 
                ON CONFLICT DO NOTHING;";
            await using var manufCommand = new NpgsqlCommand(seedManufSql, connection);
            await manufCommand.ExecuteNonQueryAsync();

            // 2. Insertamos un modelo falso vinculado al fabricante (preventivo para FK)
            const string seedModelSql = @"
                INSERT INTO public.cat_modelos_dispositivo (id_modelo_dispositivo, id_fabricante, nombre_modelo) 
                VALUES (@modelId, 1, 'Modelo Prueba') 
                ON CONFLICT DO NOTHING;";
            await using var modelCommand = new NpgsqlCommand(seedModelSql, connection);
            modelCommand.Parameters.AddWithValue("@modelId", modelId);
            await modelCommand.ExecuteNonQueryAsync();

            // 3. Insertamos un tipo de unidad falso (preventivo para FK)
            const string seedUnitSql = @"
                INSERT INTO public.cat_tipos_unidad (id_tipo_unidad, nombre) 
                VALUES (@unitId, 'Tipo Prueba') 
                ON CONFLICT DO NOTHING;";
            await using var unitCommand = new NpgsqlCommand(seedUnitSql, connection);
            unitCommand.Parameters.AddWithValue("@unitId", unitTypeId);
            await unitCommand.ExecuteNonQueryAsync();

            // 3.5 Insertamos la cuenta falsa (preventivo para FK de cat_usuarios y cat_equipos)
            const string seedAccountSql = @"
                INSERT INTO public.cat_cuentas (id_cuenta, nombre_cuenta, estado) 
                VALUES (@account, 'Cuenta Prueba', 1) 
                ON CONFLICT DO NOTHING;";
            await using var accountCommand = new NpgsqlCommand(seedAccountSql, connection);
            accountCommand.Parameters.AddWithValue("@account", accountId);
            await accountCommand.ExecuteNonQueryAsync();

            // 4. Insertamos un usuario creador falso (preventivo para FK de cat_equipos)
            const string seedUserSql = @"
                INSERT INTO public.cat_usuarios (id_usuario, id_cuenta, correo_electronico, clave, estado, nombre_completo, nombre_corto) 
                VALUES (@creatorId, @account, 'test@test.com', 'hash', 1, 'Usuario', 'Usu') 
                ON CONFLICT DO NOTHING;";
            await using var userCommand = new NpgsqlCommand(seedUserSql, connection);
            userCommand.Parameters.AddWithValue("@creatorId", creatorId);
            userCommand.Parameters.AddWithValue("@account", accountId);
            await userCommand.ExecuteNonQueryAsync();

            // 5. Insertamos el vehículo incluyendo todos los IDs obligatorios
            const string sql = @"
                INSERT INTO public.cat_equipos (
                    id_equipo, id_cuenta, tag, id_equipo_cliente, estado, 
                    id_tipo_unidad, id_modelo_dispositivo, id_usuario_creador
                )
                VALUES (
                    @id, @account, @tag, @imei, @status, 
                    @unitId, @modelId, @creatorId
                );";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("@id", vehicleId);
            command.Parameters.AddWithValue("@account", accountId);
            command.Parameters.AddWithValue("@tag", tag);
            command.Parameters.AddWithValue("@imei", imei);
            command.Parameters.AddWithValue("@status", status);
            command.Parameters.AddWithValue("@unitId", unitTypeId);
            command.Parameters.AddWithValue("@modelId", modelId);
            command.Parameters.AddWithValue("@creatorId", creatorId);

            await command.ExecuteNonQueryAsync();
        }

        private async Task SeedVehicleStateAsync(long vehicleId, double lat, double lng, bool ignition, DateTime lastUpdateUtc)
        {
            await using var connection = new NpgsqlConnection(_telematicDb);
            await connection.OpenAsync();
            const string sql = @"
                INSERT INTO public.dat_estado_actual_equipos (
                    id_equipo, latitud, longitud, altitud, velocidad, orientacion, 
                    ignicion, odometro_acumulado, segundos_motor_acumulado, 
                    fecha_ulitmo_paquete_utc, fecha_ultimo_ping, fecha_ultima_ignicion_utc,
                    trafico_gprs_acumulado, tipo_ultimo_paquete -- <--- Última columna agregada
                )
                VALUES (
                    @id, @lat, @lng, 0, 60.5, 90, 
                    @ign, 1500.5, 3600, 
                    @lastUpdate, @lastUpdate, @lastUpdate,
                    0, 1 -- <--- Valores por defecto (0 para trafico, 1 para tipo)
                );";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("@id", vehicleId);
            command.Parameters.AddWithValue("@lat", lat);
            command.Parameters.AddWithValue("@lng", lng);
            command.Parameters.AddWithValue("@ign", ignition);
            command.Parameters.AddWithValue("@lastUpdate", lastUpdateUtc);
            await command.ExecuteNonQueryAsync();
        }

        private async Task SeedGeofenceAsync(long geofenceId, string type, int accountId = 50, int creatorId = 1)
        {
            await using var connection = new NpgsqlConnection(_telematicDb);
            await connection.OpenAsync();

            const string sql = @"
                INSERT INTO public.cat_geocercas (
                    id_geocerca, id_cuenta, nombre, tipo_geocerca, estado, id_usuario_creador
                ) 
                VALUES (
                    @id, @account, 'Geocerca Prueba', @type, 1, @creatorId
                );";

            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("@id", geofenceId);
            command.Parameters.AddWithValue("@account", accountId);
            command.Parameters.AddWithValue("@type", type); // <--- Ahora pasamos el string correcto
            command.Parameters.AddWithValue("@creatorId", creatorId);

            await command.ExecuteNonQueryAsync();
        }

        private async Task SeedVehicleInGeofenceAsync(long vehicleId, long geofenceId, DateTime entryTimeUtc)
        {
            await using var connection = new NpgsqlConnection(_telematicDb);
            await connection.OpenAsync();
            const string sql = @"
                INSERT INTO public.dat_equipos_en_geocercas (id_equipo, id_geocerca, fecha_utc_entrada)
                VALUES (@vId, @gId, @entryTime);";
            await using var command = new NpgsqlCommand(sql, connection);
            command.Parameters.AddWithValue("@vId", vehicleId);
            command.Parameters.AddWithValue("@gId", geofenceId);
            command.Parameters.AddWithValue("@entryTime", entryTimeUtc);
            await command.ExecuteNonQueryAsync();
        }

        #endregion

        #region Tests

        [Fact]
        public async Task GetByVehicleIdAsync_WhenVehicleExists_ShouldReturnVehicleWithGeofences()
        {
            // Arrange
            var repo = CreateRepository();
            long vehicleId = 1001;
            var now = DateTime.UtcNow;

            await SeedVehicleAsync(vehicleId, 50, "Camion 1", "IMEI-12345");
            await SeedVehicleStateAsync(vehicleId, 19.4326, -99.1332, true, now);

            // Pasamos los valores permitidos por el Check Constraint
            await SeedGeofenceAsync(10, "CIRCULO");
            await SeedGeofenceAsync(20, "POLIGONO");

            await SeedVehicleInGeofenceAsync(vehicleId, 10, now.AddMinutes(-10));
            await SeedVehicleInGeofenceAsync(vehicleId, 20, now.AddMinutes(-5));

            // Act
            var result = await repo.GetByVehicleIdAsync(vehicleId);

            // Assert
            result.Should().NotBeNull();
            result!.VehicleId.Should().Be(vehicleId);
            result.AccountId.Should().Be(50);
            result.Tag.Should().Be("Camion 1");
            result.Imei.Should().Be("IMEI-12345");

            result.AvlData.Should().NotBeNull();
            result.AvlData.Lat.Should().Be(19.4326);
            result.AvlData.Lng.Should().Be(-99.1332);
            result.AvlData.Ignition.Should().BeTrue();

            // Validar reconstrucción de geocercas usando los textos reales
            result.AvlData.GeofenceKeys.Should().Contain("10|CIRCULO|");
            result.AvlData.GeofenceKeys.Should().Contain("20|POLIGONO|");
        }

        [Fact]
        public async Task GetByVehicleIdAsync_WhenVehicleDoesNotExist_ShouldReturnNull()
        {
            // Arrange
            var repo = CreateRepository();

            // Act
            var result = await repo.GetByVehicleIdAsync(9999);

            // Assert
            result.Should().BeNull();
        }

        [Fact]
        public async Task GetAllVehiclesWithStateAsync_ShouldReturnAllActiveVehicles()
        {
            // Arrange
            var repo = CreateRepository();
            var now = DateTime.UtcNow;

            // Vehículo 1 (Activo, con estado)
            await SeedVehicleAsync(1, 10, "Vehiculo 1", "IMEI-1");
            await SeedVehicleStateAsync(1, 10.0, -10.0, true, now);

            // Vehículo 2 (Activo, sin estado aún)
            await SeedVehicleAsync(2, 20, "Vehiculo 2", "IMEI-2");

            // Vehículo 3 (Inactivo, estado = -2) -> NO debería ser devuelto
            await SeedVehicleAsync(3, 30, "Vehiculo 3", "IMEI-3", -2);

            // Act
            var results = (await repo.GetAllVehiclesWithStateAsync()).ToList();

            // Assert
            results.Should().NotBeNull();
            results.Should().HaveCount(2);

            var v1 = results.FirstOrDefault(v => v.VehicleId == 1);
            v1.Should().NotBeNull();
            v1!.AvlData.Lat.Should().Be(10.0);

            var v2 = results.FirstOrDefault(v => v.VehicleId == 2);
            v2.Should().NotBeNull();
            // Validar que el COALESCE de la BD funcionó (0 para Lat/Lng al ser un LEFT JOIN sin coincidencias en C#)
            v2!.AvlData.Lat.Should().Be(0.0);
        }

        [Fact]
        public async Task GetByVehicleIdAsync_WhenImeiIsNullInDb_ShouldMapConsistently()
        {
            // Arrange
            var repo = CreateRepository();
            long vehicleId = 5001;

            // Para esta prueba, es más fácil insertar directamente sin el helper
            // para poder forzar un valor NULL en id_equipo_cliente.
            await using (var connection = new NpgsqlConnection(_telematicDb))
            {
                await connection.OpenAsync();
                const string sql = @"
            INSERT INTO public.cat_equipos (
                id_equipo, id_cuenta, tag, id_equipo_cliente, estado, 
                id_tipo_unidad, id_modelo_dispositivo, id_usuario_creador
            ) VALUES (
                @id, 50, 'Vehiculo IMEI Nulo', NULL, 1, 1, 1, 1
            );";
                await using var command = new NpgsqlCommand(sql, connection);
                command.Parameters.AddWithValue("@id", vehicleId);
                await command.ExecuteNonQueryAsync();
            }

            // Act
            var result = await repo.GetByVehicleIdAsync(vehicleId);

            // Assert
            result.Should().NotBeNull();

            // ASERCIÓN CORREGIDA:
            // El comportamiento ahora es consistente. Cuando el IMEI es NULL en la BD,
            // ambas propiedades deben mapearse a una cadena vacía.
            result!.Imei.Should().Be("");
            result.AvlData.Imei.Should().Be("");
        }
        #endregion
    }
}