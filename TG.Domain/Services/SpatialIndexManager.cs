using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using NetTopologySuite.Geometries;
using NetTopologySuite.Index.Strtree;
using System.Collections.Concurrent;
using TG.Domain.Interfaces;
using TG.Entities.Geofences;
using TG.Persistence.Interfaces;

namespace TG.Domain.Services
{
    /// <summary>
    /// Gestor del índice espacial en memoria (Árbol-R) para geocercas.
    /// Permite búsquedas rápidas de geocercas que intersectan con una coordenada dada, evitando evaluar todas las geocercas de la cuenta.
    /// </summary>
    public class SpatialIndexManager : ISpatialIndexManager
    {
        private readonly ILogger<SpatialIndexManager> _logger;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly GeometryFactory _geometryFactory;

        // Diccionario principal: La clave es el AccountId. 
        // El valor es el Árbol-R (STRtree) de esa cuenta específica.
        private readonly ConcurrentDictionary<int, STRtree<Geofence>> _accountTrees;

        // LA FUENTE DE VERDAD (Diccionario: AccountId -> GeofenceId -> Geofence)
        private readonly ConcurrentDictionary<int, ConcurrentDictionary<long, Geofence>> _accountGeofences;

        /// <summary>
        /// Constructor del SpatialIndexManager. Se inyectan el logger y el scope factory para acceder a la BD cuando se necesite recargar geocercas específicas.
        /// </summary>
        /// <param name="logger"></param>
        /// <param name="scopeFactory"></param>
        public SpatialIndexManager(ILogger<SpatialIndexManager> logger, IServiceScopeFactory scopeFactory)
        {
            _logger = logger;
            _scopeFactory = scopeFactory;
            _accountTrees = new ConcurrentDictionary<int, STRtree<Geofence>>();
            _accountGeofences = new ConcurrentDictionary<int, ConcurrentDictionary<long, Geofence>>();

            // Factory con SRID 4326 (WGS84 estándar GPS)
            _geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);
        }


        /// <summary>
        /// Inicializa el índice espacial con un conjunto de geocercas. Este método se llama al iniciar el servicio para cargar todas las geocercas activas en memoria.
        /// </summary>
        /// <param name="geofences"></param>
        public void Initialize(IEnumerable<Geofence> geofences)
        {
            _logger.LogInformation("Inicializando SpatialIndexManager con {Count} geocercas...", geofences.Count());

            var groupedByAccount = geofences.GroupBy(g => g.AccountId);

            foreach (var group in groupedByAccount)
            {
                int accountId = group.Key;
                var accountDict = new ConcurrentDictionary<long, Geofence>();

                foreach (var geofence in group)
                {
                    accountDict[geofence.GeofenceId] = geofence;
                }

                // Guardamos en la fuente de verdad
                _accountGeofences[accountId] = accountDict;

                // Construimos el árbol a partir del diccionario
                RebuildTreeForAccount(accountId);
            }

            _logger.LogInformation("SpatialIndexManager inicializado. Se crearon Árboles-R para {Count} cuentas.", _accountTrees.Count);
        }

        /// <summary>
        ///     Evalúa en qué geocercas de la cuenta se encuentra actualmente una coordenada.
        /// </summary>
        /// <param name="accountId"></param>
        /// <param name="latitude"></param>
        /// <param name="longitude"></param>
        /// <returns></returns>
        public IEnumerable<Geofence> FindIntersectingGeofences(int accountId, double latitude, double longitude)
        {
            if (!_accountTrees.TryGetValue(accountId, out var tree))
            {
                return Enumerable.Empty<Geofence>(); // La cuenta no tiene geocercas en memoria
            }

            // Convertimos la coordenada GPS en un Punto de NTS
            var point = _geometryFactory.CreatePoint(new Coordinate(longitude, latitude)); // NTS usa X,Y (Longitud, Latitud)

            // 1. FASE DE FILTRADO ESPACIAL (Bounding Box): 
            // Esto es magia de NTS. El Query descarta instantáneamente el 99% de las geocercas lejanas.
            var candidates = tree.Query(point.EnvelopeInternal);

            // 2. FASE DE PRECISIÓN (Ray-Casting):
            // Solo probamos las que están realmente cerca
            var intersecting = new List<Geofence>();
            foreach (var candidate in candidates)
            {
                if (candidate.Type == GeofenceType.Circulo
                    && candidate.CenterLatitude.HasValue
                    && candidate.CenterLongitude.HasValue
                    && candidate.RadiusMeters.HasValue)
                {
                    // Validación de distancia usando la fórmula de Haversine (o distancia nativa si usas geography)
                    // (Asumiendo que tienes un método auxiliar para calcular distancia entre coordenadas)
                    double distance = CalculateDistance(latitude, longitude,
                     candidate.CenterLatitude.Value, candidate.CenterLongitude.Value);
                    if (distance <= candidate.RadiusMeters.Value)
                    {
                        intersecting.Add(candidate);
                    }
                }
                else if (candidate.Type == GeofenceType.Poligono && candidate.Geometry != null)
                {
                    // Intersección matemática exacta del polígono
                    if (candidate.Geometry.Intersects(point))
                    {
                        intersecting.Add(candidate);
                    }
                }
            }

            return intersecting;
        }

        /// <summary>
        /// Recarga o agrega una geocerca específica al Árbol-R en memoria. Este método se llama cuando se recibe un mensaje de actualización de configuración para una geocerca específica.
        /// </summary>
        /// <param name="accountId"></param>
        /// <param name="geofenceId"></param>
        /// <returns></returns>
        public async Task ReloadGeofenceAsync(int accountId, long geofenceId)
        {
            try
            {
                await using var scope = _scopeFactory.CreateAsyncScope();
                var repository = scope.ServiceProvider.GetRequiredService<IGeofencesRepository>();

                var geofence = await repository.GetByIdSpatialAsync(geofenceId);

                // Obtenemos o creamos el diccionario de la cuenta
                var accountDict = _accountGeofences.GetOrAdd(accountId, _ => new ConcurrentDictionary<long, Geofence>());

                if (geofence != null)
                {
                    // Si existe y está activa, la guardamos o actualizamos en el diccionario
                    accountDict[geofenceId] = geofence;
                }
                else
                {
                    // Si devolvió null (ej. el cliente la inactivó a estado 0 o -1), la removemos
                    accountDict.TryRemove(geofenceId, out _);
                }

                // Reconstruimos el árbol
                RebuildTreeForAccount(accountId);

                _logger.LogInformation("Geocerca {GeofenceId} recargada exitosamente en el índice de la Cuenta {AccountId}.", geofenceId, accountId);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error al recargar la geocerca {GeofenceId} en el índice espacial.", geofenceId);
            }
        }

        /// <summary>
        /// Elimina una geocerca del Árbol-R en memoria. Este método se llama cuando se recibe un mensaje de eliminación de una geocerca, para que deje de evaluarse en cruces futuros.
        /// </summary>
        /// <param name="accountId"></param>
        /// <param name="geofenceId"></param>
        public void RemoveGeofence(int accountId, long geofenceId)
        {
            if (_accountGeofences.TryGetValue(accountId, out var accountDict))
            {
                if (accountDict.TryRemove(geofenceId, out _))
                {
                    // Si la eliminación del diccionario fue exitosa, reconstruimos el árbol
                    RebuildTreeForAccount(accountId);
                    _logger.LogInformation("Geocerca {GeofenceId} eliminada del índice de la Cuenta {AccountId}.", geofenceId, accountId);
                }
            }
        }

        /// <summary>
        /// Reconstruye el STRtree de una cuenta a partir de su diccionario en memoria y realiza 
        /// un reemplazo atómico para no bloquear hilos de lectura.
        /// </summary>
        private void RebuildTreeForAccount(int accountId)
        {
            if (!_accountGeofences.TryGetValue(accountId, out var accountDict)) return;

            var newTree = new STRtree<Geofence>();

            foreach (var geofence in accountDict.Values)
            {
                InsertIntoTree(newTree, geofence);
            }

            newTree.Build();

            // Reemplazo atómico. Cualquier hilo que estuviera leyendo el árbol viejo, terminará sin errores.
            // Los nuevos hilos usarán automáticamente el nuevo árbol.
            _accountTrees[accountId] = newTree;
        }

        /// <summary>
        /// Inserta una geocerca en el Árbol-R, calculando su Bounding Box según su tipo (Círculo o Polígono). Para círculos, se calcula un bounding box aproximado con un margen de seguridad. Para polígonos, se usa su bounding box nativo de NTS.
        /// </summary>
        /// <param name="tree"></param>
        /// <param name="geofence"></param>
        private void InsertIntoTree(STRtree<Geofence> tree, Geofence geofence)
        {
            Envelope boundingBox;

            if (geofence.Type == GeofenceType.Circulo && geofence.RadiusMeters.HasValue
                && geofence.CenterLatitude.HasValue && geofence.CenterLongitude.HasValue)
            {
                // Un cálculo aproximado del Bounding Box para un círculo en grados (1 grado latitud ~ 111km)
                double offsetDegrees = (geofence.RadiusMeters.Value / 111000.0) * 1.1; // Margen del 10%
                boundingBox = new Envelope(
                    geofence.CenterLongitude.Value - offsetDegrees,
                    geofence.CenterLongitude.Value + offsetDegrees,
                    geofence.CenterLatitude.Value - offsetDegrees,
                    geofence.CenterLatitude.Value + offsetDegrees
                );
            }
            else
            {
                boundingBox = geofence.Geometry!.EnvelopeInternal;
            }

            tree.Insert(boundingBox, geofence);
        }

        /// <summary>
        /// Calcula la distancia en metros entre dos coordenadas GPS usando la fórmula de Haversine.
        /// Este método se utiliza para validar si una coordenada está dentro del radio de una geocerca circular durante la fase de precisión.
        /// </summary>
        /// <param name="lat1"></param>
        /// <param name="lon1"></param>
        /// <param name="lat2"></param>
        /// <param name="lon2"></param>
        /// <returns></returns>
        private double CalculateDistance(double lat1, double lon1, double lat2, double lon2)
        {
            // Fórmula Haversine simplificada o puedes inyectar un servicio geográfico.
            var d1 = lat1 * (Math.PI / 180.0);
            var num1 = lon1 * (Math.PI / 180.0);
            var d2 = lat2 * (Math.PI / 180.0);
            var num2 = lon2 * (Math.PI / 180.0) - num1;
            var d3 = Math.Pow(Math.Sin((d2 - d1) / 2.0), 2.0) + Math.Cos(d1) * Math.Cos(d2) * Math.Pow(Math.Sin(num2 / 2.0), 2.0);
            return 6371000.0 * (2.0 * Math.Atan2(Math.Sqrt(d3), Math.Sqrt(1.0 - d3))); // Devuelve metros
        }

        /// <summary>
        /// Obtiene una geocerca específica por su ID, útil para operaciones de actualización o eliminación.
        ///  Este método se puede usar para validar la existencia de una geocerca antes de intentar recargarla o eliminarla, evitando llamadas innecesarias a la base de datos.
        /// </summary>
        /// <param name="accountId"></param>
        /// <param name="geofenceId"></param>
        /// <returns></returns>
        public Geofence? GetGeofence(int accountId, long geofenceId)
        {
            if (_accountGeofences.TryGetValue(accountId, out var accountDict))
            {
                if (accountDict.TryGetValue(geofenceId, out var geofence)) return geofence;
            }
            return null;
        }
    }
}