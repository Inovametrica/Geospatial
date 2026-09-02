using NetTopologySuite.Geometries; // ¡Necesario!

namespace TG.Entities.Geofences
{
    /// <summary>
    /// Representa una geocerca unificada (Círculo o Polígono) leída desde cat_geocercas.
    /// </summary>
    public class Geofence
    {
        public int AccountId { get; set; }
        public long GeofenceId { get; set; }
        public string Name { get; set; } = string.Empty;
        public GeofenceType Type { get; set; }
        public GeofenceScope Scope { get; set; }

        // Propiedades para Círculos
        public double? CenterLatitude { get; set; }
        public double? CenterLongitude { get; set; }
        public double? RadiusMeters { get; set; }

        // Propiedad para Polígonos (¡Usando NetTopologySuite!)
        public Geometry? Geometry { get; set; }

        // Puedes añadir más propiedades si las necesitas (color, id_cuenta, etc.)
    }
}