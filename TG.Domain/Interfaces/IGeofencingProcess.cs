
using SharedTelematic.Entities.Gps;

namespace TG.Domain.Interfaces;
/// <summary>
/// Interfaz para definir los metodos generales del procedo de geocercas
/// </summary>
public interface IGeofencingProcess
{
    void StartLoadGeofences();
    void GetAssignedGeofences();
    void GetCurrentGeofences();
    void Process(AvlData Data);
}