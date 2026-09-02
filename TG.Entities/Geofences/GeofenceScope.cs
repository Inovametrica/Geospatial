namespace TG.Entities.Geofences
{
    /// <summary>
    /// Define el ámbito de asignación de una geocerca.
    /// </summary>
    public enum GeofenceScope
    {
        /// <summary>
        /// El ámbito no fue reconocido o es nulo.
        /// </summary>
        Unknown,

        /// <summary>
        /// Compara solo con unidades/grupos específicos (rel_equipo_geocerca_cache).
        /// </summary>
        Especifico,

        /// <summary>
        /// Compara con todas las unidades asignadas al usuario (rel_equipo_geocerca_cache).
        /// </summary>
        Asignadas,

        /// <summary>
        /// Compara con absolutamente todas las unidades.
        /// </summary>
        All
    }
}