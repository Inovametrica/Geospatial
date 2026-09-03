# ETAPA 1: Base Ligera
# Utiliza exclusivamente el entorno de ejecución (Runtime) para que la imagen final pese muy poco.
FROM mcr.microsoft.com/dotnet/runtime:10.0 AS base
WORKDIR /app

# ETAPA 2: Compilación y Descarga de NuGet
# Utiliza el SDK completo (que es mucho más pesado) solo para la fase de construcción.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Inyección segura del token para descargar la SharedLibrary privada.
ARG GITHUB_TOKEN
ENV GITHUB_TOKEN=$GITHUB_TOKEN

# Se copia el mapa de dependencias (nuget.config) a la raíz del contenedor.
COPY ["nuget.config", "."]

# Se copia ÚNICAMENTE el archivo de proyecto (.csproj) del decodificador.
COPY ["TG.Service/TG.Service.csproj", "TG.Service/"]

# Restauración de dependencias utilizando explícitamente el archivo nuget.config inyectado.
RUN dotnet restore "TG.Service/TG.Service.csproj" --configfile nuget.config

# Una vez restaurados los paquetes, se copia el resto del código fuente.
COPY . .
WORKDIR "/src/TG.Service"

#Compilamos
RUN dotnet build "TG.Service.csproj" -c Release -o /app/build

# ETAPA 3: Publicación
# Genera los archivos binarios finales y ensamblados listos para producción.
FROM build AS publish
RUN dotnet publish "TG.Service.csproj" -c Release -o /app/publish /p:UseAppHost=false

# ETAPA 4: Imagen Final de Producción
# Toma la Base Ligera de la Etapa 1, le inyecta los binarios de la Etapa 3 y descarta el resto.
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "TG.Service.dll"]