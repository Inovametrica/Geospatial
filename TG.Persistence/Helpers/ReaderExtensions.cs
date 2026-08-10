using Microsoft.Data.SqlClient;

namespace TG.Persistence.Helpers;

/// <summary>
/// Extensiones para SqlDataReader que facilitan la lectura segura de datos.
/// </summary>
internal static class SqlReaderExtensions
{
    public static double? GetDecimalAsDouble(this SqlDataReader reader, string columnName)
    {
        int ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? (double?)null : (double)reader.GetDecimal(ordinal);
    }
    public static double? GetInt32AsDouble(this SqlDataReader reader, string columnName)
    {
        int ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? (double?)null : (double)reader.GetInt32(ordinal);
    }
    public static string GetStringSafe(this SqlDataReader reader, string columnName)
    {
        int ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? string.Empty : reader.GetString(ordinal);
    }
}