namespace TG.Persistence.Interfaces
{
    public interface IBaseRepository<T>
    where T : class
    {
        void SetVehicleId(long VehicleId);
        bool Update(T t);
    }
}