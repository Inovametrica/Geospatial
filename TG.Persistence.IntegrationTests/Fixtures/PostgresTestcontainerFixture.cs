using Npgsql;
using Testcontainers.PostgreSql;
using Xunit;

namespace TG.Persistence.IntegrationTests.Fixtures;

public class PostgresTestcontainerFixture : IAsyncLifetime
{
    // Define el contenedor usando la misma versión de tu producción
    private readonly PostgreSqlContainer _postgresContainer = new PostgreSqlBuilder("postgis/postgis:16-3.4")
       .WithDatabase("telematic_test")
        .WithUsername("admin")
        .WithPassword("adminpassword123")
        .Build();

    // Cadenas de conexión públicas para cada base de datos
    public string TelematicConnectionString => _postgresContainer.GetConnectionString();
    public string HistoryConnectionString => GetConnectionStringForDb("history_test");
    public string AddressConnectionString => GetConnectionStringForDb("address_test");

    public async Task InitializeAsync()
    {
        // 1. Levantar el contenedor en Docker[cite: 20]
        await _postgresContainer.StartAsync();

        // 2. Crear las bases de datos adicionales
        await CreateAdditionalDatabasesAsync();

        // 3. Crear el esquema inicial para cada base de datos leyendo sus respectivos scripts
        // Asume que generaste tres archivos .sql distintos con pg_dump
        await InitializeDatabaseSchemaAsync(TelematicConnectionString, "init_telematic.sql");
        await InitializeDatabaseSchemaAsync(HistoryConnectionString, "init_history.sql");
        await InitializeDatabaseSchemaAsync(AddressConnectionString, "init_address.sql");
    }

    public async Task DisposeAsync()
    {
        // Apagar y destruir el contenedor al terminar todas las pruebas[cite: 20]
        await _postgresContainer.DisposeAsync();
    }

    private string GetConnectionStringForDb(string dbName)
    {
        // Tomamos la cadena base que nos da Testcontainers y le cambiamos el nombre de la BD
        var builder = new NpgsqlConnectionStringBuilder(_postgresContainer.GetConnectionString())
        {
            Database = dbName
        };
        return builder.ConnectionString;
    }

    private async Task CreateAdditionalDatabasesAsync()
    {
        // Nos conectamos a la BD principal para crear las secundarias
        await using var connection = new NpgsqlConnection(TelematicConnectionString);
        await connection.OpenAsync();

        // En PostgreSQL, CREATE DATABASE no puede ejecutarse dentro de un bloque de transacción
        await using var cmdHistory = new NpgsqlCommand("CREATE DATABASE history_test;", connection);
        await cmdHistory.ExecuteNonQueryAsync();

        await using var cmdAddress = new NpgsqlCommand("CREATE DATABASE address_test;", connection);
        await cmdAddress.ExecuteNonQueryAsync();
    }

    private async Task InitializeDatabaseSchemaAsync(string connectionString, string scriptName)
    {
        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync();

        var basePath = AppContext.BaseDirectory;
        var scriptPath = Path.Combine(basePath, "Fixtures", scriptName);

        if (!File.Exists(scriptPath))
        {
            // Si una BD no requiere script, puedes ignorar el error o manejarlo
            return;
        }

        var sqlQuery = await File.ReadAllTextAsync(scriptPath);

        // Parche de seguridad para PostGIS[cite: 20]
        sqlQuery = sqlQuery.Replace("CREATE SCHEMA topology;", "CREATE SCHEMA IF NOT EXISTS topology;");
        sqlQuery = sqlQuery.Replace("CREATE SCHEMA public;", "CREATE SCHEMA IF NOT EXISTS public;");
        sqlQuery = sqlQuery.Replace("CREATE EXTENSION postgis;", "CREATE EXTENSION IF NOT EXISTS postgis;");
        sqlQuery = sqlQuery.Replace("CREATE EXTENSION postgis_topology;", "CREATE EXTENSION IF NOT EXISTS postgis_topology;");

        await using var command = new NpgsqlCommand(sqlQuery, connection);
        command.CommandTimeout = 60;
        await command.ExecuteNonQueryAsync();
    }
}

[CollectionDefinition("PostgresCollection")]
public class PostgresCollection : ICollectionFixture<PostgresTestcontainerFixture>
{
}