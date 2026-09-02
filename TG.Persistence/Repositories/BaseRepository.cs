
using TG.Persistence.Interfaces;
using Microsoft.Extensions.Logging;
using TG.Persistence.Settings;
using Microsoft.Extensions.Options;

namespace TG.Persistence.Repositories;

public class BaseRepository<T> : IBaseRepository<T>
    where T : class
{
    protected readonly ILogger<IBaseRepository<T>> _logger;
    protected readonly DatabaseSettings _dbSettings;
    protected string ClassName = string.Empty;
    protected long VehicleId = 0;

    public BaseRepository(IOptions<DatabaseSettings> dbSettings, ILogger<IBaseRepository<T>> logger)
    {
        this._dbSettings = dbSettings.Value;
        _logger = logger;
    }

    public virtual bool Update(T t)
    {
        throw new NotImplementedException();
    }

    public void SetVehicleId(long VehicleId)
    {
        this.VehicleId = VehicleId;
    }
}