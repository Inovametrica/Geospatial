using TG.Domain;
using Serilog;

var builder = Host.CreateApplicationBuilder(args);
// Configura la instancia estática de Serilog desde appsettings.json
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .CreateLogger();
try
{
    //Limpia los proveedores de logging por defecto (Console, Debug, etc.)
    builder.Logging.ClearProviders();

    //Agrega Serilog como el proveedor de logging.
    builder.Services.AddSerilog();

    // Configura el host para que se ejecute como un servicio de Windows
    builder.Services.AddWindowsService(options =>
    {
        options.ServiceName = builder.Configuration["ServiceName"]!.ToString();
    });

    // Llama a tu método centralizado para registrar todos los servicios de la aplicación
    builder.Services.AddApplicationServices(builder.Configuration);

    // Configura Serilog u otro logger si lo deseas
    // builder.Logging.AddSerilog(...);

    var host = builder.Build();
    host.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "La aplicación falló al iniciar.");
}
finally
{
    Log.CloseAndFlush();
    Environment.Exit(1);
}
