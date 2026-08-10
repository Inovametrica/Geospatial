namespace TG.Persistence.Settings
{
    public class DatabaseSettings
    {
        // Los nombres de las propiedades DEBEN coincidir exactamente
        // con las claves dentro de la sección "ConnectionStrings" en appsettings.json
        public string Telematic { get; set; } = string.Empty;
        public string History { get; set; } = string.Empty;
    }
}