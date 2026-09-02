# 🏁 Servicio de Geocercas (TG.GeofencingService) - Motor Espacial de Alto Rendimiento

Este servicio es un consumidor de RabbitMQ de clase Enterprise escrito en .NET 10. Actúa como el **cerebro matemático espacial** de la plataforma. Su único propósito es procesar flujos masivos de eventos GPS en tiempo real para detectar entradas y salidas de polígonos utilizando indexación espacial (Árboles-R), actualizar el estado inmediato en Redis, y emitir eventos hacia el resto de la plataforma.

## 1. 🎯 Arquitectura y Flujo de Datos

Este servicio implementa un patrón **Event-Driven** y está completamente desacoplado de las reglas de negocio (notificaciones, asignaciones, etc.).

1. **Topología de Ingesta (Consistent Hash):** - El servicio crea una **cola exclusiva y temporal** que se une al exchange `GeofencingHashExchange`.
   - Utiliza `x-consistent-hash` en RabbitMQ garantizando que todos los pings de un mismo `VehicleId` sean enrutados siempre a la misma instancia del contenedor (Sesiones Fijas), protegiendo la caché local.

2. **Cálculo Espacial Ultrarrápido (`SpatialIndexManager`):**
   - Al iniciar, el servicio carga las geometrías desde SQL Server y construye un **Árbol-R (`STRtree` de NetTopologySuite)** en memoria RAM, agrupado por `AccountId` (Aislamiento Multitenant).
   - Cuando llega una coordenada, el motor realiza una búsqueda binaria espacial (Ray-Casting y Bounding Boxes), bajando la complejidad computacional de $O(N)$ a $\mathcal{O}(\log N)$. No evalúa "asignaciones", evalúa matemáticas.

3. **Sincronización de Configuración en Vivo:**
   - Ya no utiliza temporizadores (Timers) para consultar la BD. Escucha el exchange `ConfigUpdatesFanoutExchange`.
   - Si un usuario crea, edita o elimina una geocerca desde la API web, el microservicio recibe el evento e inyecta atómicamente el nuevo polígono en el Árbol-R sin bloquear los hilos de cálculo ni reiniciar el servicio.

4. **Gestión de Estado y Salidas:**
   - **Estado Inmediato:** Utiliza **Redis** (`RedisGeofenceStateCache`) para consultar/actualizar instantáneamente si el vehículo estaba "Dentro" o "Fuera", calculando velocidades máximas y tiempos de estancia en microsegundos.
   - **Persistencia (Batching):** Los cambios de estado se envían a un búfer en RAM (`GeofenceEventBufferService`). Un proceso en segundo plano los inserta masivamente (TVP) en SQL Server (`dat_equipos_en_geocercas` e Histórico) sin bloquear el cálculo GPS.
   - **Emisión de Eventos:** Una vez procesado el cruce, publica el evento en `GeofenceEventsConsistentHashExchange` para que el **Motor de Notificaciones** lo evalúe.

---

## 2. ⚙️ Configuración (`appsettings.json`)

El archivo `appsettings.json` controla el comportamiento de la infraestructura.

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.Hosting.Lifetime": "Information"
    }
  },
  "ConnectionStrings": {
    "Telematic": "Server=...;Database=TELEMATIC;...",
    "History": "Server=...;Database=TELEMatic_H1;..."
  },
  "RabbitMQ": {
    "HostName": "localhost",
    "UserName": "guest",
    "Password": "guest",
    "GpsFanoutExchange": "gps.fanout",
    "GeofencingHashExchange": "geofencing.hash",
    "ConfigUpdatesFanoutExchange": "config_updates.fanout",
    "GeofenceEventsConsistentHashExchange": "geofence_events.ch"
  },
  "GeofencingSettings": {
    "BatchingIntervalSeconds": 10,
    "BatchingSize": 1000,
    "RedisConnectionString": "tu_contraseña@localhost:6379"
  }
}
```

### Desglose de Secciones Importantes:

- **`ConnectionStrings`**:
- **`Telematic`**: Base de datos principal. Contiene la configuración de `cat_geocercas` (con sus geometrías) y `cat_equipos`.
- **`History`**: Base de datos histórica donde se almacenan los lotes de eventos (`GeofenceEventBatchingService`).

- **`GeofencingSettings`**:
- **`BatchingIntervalSeconds` & `BatchingSize**`: Controlan el tamaño y la frecuencia de las inserciones masivas en SQL Server (Histórico).
- **`RedisConnectionString`**: Obligatorio. Utilizado para mantener el estado de permanencia (Dwell time, Max Speed) de manera distribuida.

---

## 3. 💾 Prerrequisitos de Base de Datos

Antes de ejecutar, asegúrate de que existan las siguientes tablas:

1. **En `Telematic` (BD Principal):**

- `cat_geocercas` (Debe contar con la columna `geometria` de tipo `geography` o su equivalente, y el `id_cuenta`).
- `cat_equipos` (Debe incluir el `id_cuenta` para el multitenant).
- `dat_estado_actual_equipos` (Para métricas del último ping).
- `dat_equipos_en_geocercas` (Tabla de estado actualizado en tiempo real).
- _(Nota: Se ha descontinuado el uso de tablas de relaciones caché como `rel_equipo_geocerca_cache`)._

2. **En `History` (BD Histórica):**

- `GeofenceEventBatchType` (El Tipo de Tabla Definido por Usuario para el TVP).
- `sp_InsertGeofenceEventBatch` (El Stored Procedure para la inserción masiva).

---

## 4. 🚀 Cómo Compilar y Ejecutar

### Compilar la Solución

```bash
dotnet build -c Release

```

### Publicar (Crear el Ejecutable)

`dotnet publish` empaqueta tu servicio en una carpeta (`publish`) con todos los archivos necesarios para ejecutarse.

**Para Windows (x64):**

```bash
dotnet publish TG.GeofencingService/TG.GeofencingService.csproj -c Release -r win-x64 --self-contained true

```

**Para Linux (x64):**

```bash
dotnet publish TG.GeofencingService/TG.GeofencingService.csproj -c Release -r linux-x64 --self-contained true

```

### Ejecutar el Servicio (Desarrollo)

Usa estos comandos para ejecutar el servicio directamente desde la terminal.

```bash
dotnet run --project TG.GeofencingService/TG.GeofencingService.csproj -c Release

```

### Ejecutar en Producción (Docker / Servicios)

Dada su naturaleza desacoplada y el uso de un caché unificado en Redis, este servicio **está diseñado para escalar horizontalmente de forma lineal**. Puedes levantar 1 o 10 contenedores Docker; RabbitMQ (`x-consistent-hash`) balanceará automáticamente los vehículos entre las instancias vivas asegurando consistencia matemática sin saturar SQL Server.
