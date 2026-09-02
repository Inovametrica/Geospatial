using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System.Threading.Channels;
using TG.Domain.Interfaces;
using TG.Persistence.Interfaces;
using SharedTelematic.Interfaces;
using SharedTelematic.Entities.Geofences;
using TG.Entities.Geofences;

namespace TG.Domain.Device
{
    public class VehicleProcessor
    {
        private readonly long _vehicleId;
        private readonly ILogger _logger;
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly Channel<IAvlData> _queue;

        public VehicleProcessor(long vehicleId, IServiceScopeFactory scopeFactory, ILogger logger)
        {
            _vehicleId = vehicleId;
            _scopeFactory = scopeFactory;
            _logger = logger;

            // Creamos un canal "sin límites" para este vehículo.
            // Si un vehículo envía una ráfaga de datos, se encolarán en memoria.
            _queue = Channel.CreateUnbounded<IAvlData>(new UnboundedChannelOptions
            {
                SingleReader = true // Optimización: solo nuestro bucle leerá de la cola.
            });
        }

        /// <summary>
        /// Inicia el bucle de procesamiento en segundo plano para este vehículo.
        /// Ahora acepta un CancellationToken para permitir una parada controlada.
        /// </summary>
        public Task StartProcessingLoop(CancellationToken cancellationToken)
        {
            return Task.Run(() => ProcessQueueAsync(cancellationToken));
        }

        /// <summary>
        /// Agrega un nuevo dato GPS a la cola. Ahora valida si se está deteniendo.
        /// </summary>
        public async Task EnqueueDataAsync(IAvlData data)
        {
            // Esta tarea se completa cuando el canal se marca como 'completo' y se vacía,
            // lo que nos sirve como señal de que el servicio se está deteniendo.
            if (_queue.Reader.Completion.IsCompleted)
            {
                //_logger.LogWarning("Se intentó encolar un dato en el procesador del vehículo {VehicleId} durante el apagado. Se descartará.", _vehicleId);
                return;
            }
            await _queue.Writer.WriteAsync(data);
        }

        /// <summary>
        /// Marca la cola como 'completa', indicando que no se aceptarán más datos.
        /// </summary>
        public void StopAcceptingData()
        {
            _queue.Writer.TryComplete();
        }

        /// <summary>
        /// Bucle principal que se ejecuta en una Tarea del ThreadPool.
        /// Lee continuamente de la cola, procesa los datos para detectar eventos de geocerca,
        /// actualiza la tabla de estado en tiempo real y encola los eventos en un búfer para su guardado masivo.
        /// </summary>
        private async Task ProcessQueueAsync(CancellationToken cancellationToken)
        {
            //_logger.LogInformation("Iniciando bucle de procesamiento para el Vehículo ID: {VehicleId}", _vehicleId);

            // Espera a que haya datos disponibles en la cola.
            await foreach (var gpsEvent in _queue.Reader.ReadAllAsync(cancellationToken))
            {
                // Creamos un scope de dependencias para esta operación.
                // Esto nos permite usar servicios Scoped (como los repositorios) de forma segura.
                await using var scope = _scopeFactory.CreateAsyncScope();
                var vehicleCache = scope.ServiceProvider.GetRequiredService<IVehicleCacheService>();
                var eventBuffer = scope.ServiceProvider.GetRequiredService<IGeofenceEventBufferService>();
                var geofencesRepo = scope.ServiceProvider.GetRequiredService<IGeofencesRepository>();
                // Servicio de Caché de Estado (Redis) para velocidades y contadores
                var geofenceStateCache = scope.ServiceProvider.GetRequiredService<IGeofenceStateCache>();

                // El cerebro matemático
                var spatialIndexManager = scope.ServiceProvider.GetRequiredService<ISpatialIndexManager>();

                try
                {
                    // 1. OBTENER ESTADO DEL VEHÍCULO
                    var vehicle = await vehicleCache.GetVehicleByIdAsync(_vehicleId);
                    if (vehicle == null) continue;

                    // Descartar paquetes atrasados
                    if (gpsEvent.DateTimeUtc <= vehicle.AvlData.DateTimeUtc) continue;

                    // 2. MAGIA ESPACIAL: Consulta instantánea O(log N) al Árbol-R de esta cuenta
                    // Devuelve SÓLO las geocercas que el vehículo está tocando en este momento exacto.
                    var intersectingGeofences = spatialIndexManager.FindIntersectingGeofences(vehicle.AccountId, gpsEvent.Lat, gpsEvent.Lng);
                    var geofencesVehicleIsInNow = new HashSet<Geofence>(intersectingGeofences);

                    // 3. COMPARAR "ANTES" Y "DESPUÉS"
                    var (geofencesVehicleWasIn, oldEntryTimes) = ParseGeofencesFromState(
                        vehicle.AvlData.GeofenceKeys,
                        vehicle.AccountId,
                        spatialIndexManager
                    );

                    var enteredGeofences = geofencesVehicleIsInNow.Except(geofencesVehicleWasIn);
                    var exitedGeofences = geofencesVehicleWasIn.Except(geofencesVehicleIsInNow);
                    var stayingGeofences = geofencesVehicleIsInNow.Intersect(geofencesVehicleWasIn);
                    bool stateChanged = enteredGeofences.Any() || exitedGeofences.Any();

                    // --- EJECUTAR CAMBIOS (ENTRADAS) ---
                    foreach (var geo in enteredGeofences)
                    {
                        // Guardar en tabla (Llamada asíncrona pero sin afectar el R-Tree)
                        await geofencesRepo.AddVehicleToGeofenceStateAsync(_vehicleId, geo.GeofenceId, gpsEvent.DateTimeUtc);

                        // Redis: Iniciar estado de visita
                        var newState = new VehicleGeofenceState
                        {
                            MaxSpeedKmh = gpsEvent.Speed,
                            SumSpeedKmh = gpsEvent.Speed,
                            PointCount = 1,
                            LastUpdateUtc = gpsEvent.DateTimeUtc
                        };
                        await geofenceStateCache.SetStateAsync(_vehicleId, geo.GeofenceId, newState);

                        // Búfer: Encolar para histórico masivo
                        eventBuffer.AddEvent(new GeofenceEventData
                        {
                            GpsId = gpsEvent.GpsId,
                            VehicleId = _vehicleId,
                            Imei = vehicle.Imei,
                            Latitude = gpsEvent.Lat,
                            Longitude = gpsEvent.Lng,
                            Odometer = gpsEvent.Odometer,
                            Speed = gpsEvent.Speed,
                            Orientation = gpsEvent.Orientation,
                            DateTimeUtc = gpsEvent.DateTimeUtc,
                            EventType = 100, // Entrada
                            GeofenceKey = geo.GeofenceId,
                            GeofenceName = geo.Name,
                            GeofenceType = (int)geo.Type,
                            MaxSpeedKmh = gpsEvent.Speed,
                            AvgSpeedKmh = gpsEvent.Speed,
                            DwellTimeSeconds = 0
                        });
                    }

                    // --- GESTIÓN DE PERMANENCIA ---
                    foreach (var geo in stayingGeofences)
                    {
                        var state = await geofenceStateCache.GetStateAsync(_vehicleId, geo.GeofenceId) ?? new VehicleGeofenceState
                        {
                            MaxSpeedKmh = gpsEvent.Speed,
                            SumSpeedKmh = gpsEvent.Speed,
                            PointCount = 0
                        };

                        if (gpsEvent.Speed > state.MaxSpeedKmh) state.MaxSpeedKmh = gpsEvent.Speed;
                        state.SumSpeedKmh += gpsEvent.Speed;
                        state.PointCount++;
                        state.LastUpdateUtc = gpsEvent.DateTimeUtc;

                        await geofenceStateCache.SetStateAsync(_vehicleId, geo.GeofenceId, state);
                    }

                    // --- EJECUTAR CAMBIOS (SALIDAS) ---
                    foreach (var geo in exitedGeofences)
                    {
                        await geofencesRepo.RemoveVehicleFromGeofenceStateAsync(_vehicleId, geo.GeofenceId);

                        var state = await geofenceStateCache.GetStateAsync(_vehicleId, geo.GeofenceId);

                        double maxSpeed = gpsEvent.Speed;
                        double avgSpeed = gpsEvent.Speed;
                        double dwellTime = 0;

                        if (oldEntryTimes.TryGetValue(geo.GeofenceId, out var entryTime))
                        {
                            dwellTime = (gpsEvent.DateTimeUtc - entryTime).TotalSeconds;
                        }

                        if (state != null)
                        {
                            maxSpeed = state.MaxSpeedKmh;
                            avgSpeed = state.PointCount > 0 ? (state.SumSpeedKmh / state.PointCount) : 0;
                            await geofenceStateCache.RemoveStateAsync(_vehicleId, geo.GeofenceId);
                        }

                        eventBuffer.AddEvent(new GeofenceEventData
                        {
                            GpsId = gpsEvent.GpsId,
                            VehicleId = _vehicleId,
                            Imei = vehicle.Imei,
                            Latitude = gpsEvent.Lat,
                            Longitude = gpsEvent.Lng,
                            Odometer = gpsEvent.Odometer,
                            Speed = gpsEvent.Speed,
                            Orientation = gpsEvent.Orientation,
                            DateTimeUtc = gpsEvent.DateTimeUtc,
                            EventType = 101, // Salida
                            GeofenceKey = geo.GeofenceId,
                            GeofenceName = geo.Name,
                            GeofenceType = (int)geo.Type,
                            MaxSpeedKmh = maxSpeed,
                            AvgSpeedKmh = avgSpeed,
                            DwellTimeSeconds = dwellTime
                        });
                    }

                    // --- ACTUALIZAR ESTADO DEL VEHÍCULO ---
                    vehicle.UpdateStateFromGpsEvent(gpsEvent);

                    if (stateChanged)
                    {
                        var newGeofenceKeys = string.Join(",", geofencesVehicleIsInNow.Select(g =>
                        {
                            var entryTime = oldEntryTimes.TryGetValue(g.GeofenceId, out var oldTime) ? oldTime : gpsEvent.DateTimeUtc;
                            return $"{g.GeofenceId}|{(int)g.Type}|{entryTime:O}";
                        }));
                        vehicle.AvlData.GeofenceKeys = newGeofenceKeys;
                    }

                    vehicleCache.UpdateVehicleCache(vehicle);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error procesando evento para el vehículo {VehicleId}", _vehicleId);
                }
            }
        }

        /// <summary>
        /// /// Convierte el string de estado de geocercas en un Set de objetos Geofence
        /// y un diccionario de sus tiempos de entrada.
        /// </summary>
        /// <param name="keys"></param>
        /// <param name="accountId"></param>
        /// <param name="spatialManager"></param>
        /// <returns></returns>
        private (HashSet<Geofence> geofences, Dictionary<long, DateTime> entryTimes) ParseGeofencesFromState(
            string keys,
            int accountId,
            ISpatialIndexManager spatialManager)
        {
            var geofences = new HashSet<Geofence>();
            var entryTimes = new Dictionary<long, DateTime>();

            if (string.IsNullOrWhiteSpace(keys)) return (geofences, entryTimes);

            var geofenceEntries = keys.Split(',', StringSplitOptions.RemoveEmptyEntries);

            foreach (var entry in geofenceEntries)
            {
                var parts = entry.Split('|');
                if (parts.Length != 3) continue;

                if (!long.TryParse(parts[0], out var geofenceId) || !DateTime.TryParse(parts[2], out var entryTimeUtc))
                    continue;

                // Usamos el mánager para extraer la geocerca de la memoria
                var foundGeofence = spatialManager.GetGeofence(accountId, geofenceId);
                if (foundGeofence != null)
                {
                    geofences.Add(foundGeofence);
                    entryTimes[geofenceId] = entryTimeUtc;
                }
            }

            return (geofences, entryTimes);
        }

    }
}