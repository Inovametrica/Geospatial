namespace TG.Entities.Interfaces;

public interface IGeofence
{
    long Key { get; set; }
    string Name { get; set; }
    DateTime DateTimeEntryUtc { get; set; }
}