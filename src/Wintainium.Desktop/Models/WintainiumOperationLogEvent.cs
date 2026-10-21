namespace Wintainium.Desktop.Models;

/// <summary>
/// Lossless desktop projection of a Core structured log event. Context values remain
/// individually addressable so diagnostics can be rendered without parsing message text.
/// </summary>
internal sealed record WintainiumOperationLogEvent(
    string? Severity,
    string? OperationId,
    string? Component,
    string? EventName,
    string? Message,
    IReadOnlyDictionary<string, string?> Context);

internal static class WintainiumOperationLogEventMapper
{
    public static IReadOnlyList<WintainiumOperationLogEvent> MapCollection(
        System.Management.Automation.PSObject source,
        string propertyName = "LogEvents")
    {
        ArgumentNullException.ThrowIfNull(source);
        var value = source.Properties[propertyName]?.Value;
        if (value is null) return [];

        var items = value is System.Collections.IEnumerable enumerable and not string
            ? enumerable.Cast<object>().Select(System.Management.Automation.PSObject.AsPSObject)
            : new[] { System.Management.Automation.PSObject.AsPSObject(value) };

        return items.Select(Map).ToArray();
    }

    public static WintainiumOperationLogEvent Map(System.Management.Automation.PSObject source)
    {
        ArgumentNullException.ThrowIfNull(source);
        return new WintainiumOperationLogEvent(
            Nullable(source, "Severity"),
            Nullable(source, "OperationId"),
            Nullable(source, "Component"),
            Nullable(source, "EventName"),
            Nullable(source, "Message"),
            MapContext(source.Properties["Context"]?.Value));
    }

    private static IReadOnlyDictionary<string, string?> MapContext(object? value)
    {
        var context = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        if (value is null) return context;

        if (value is System.Collections.IDictionary dictionary)
        {
            foreach (System.Collections.DictionaryEntry entry in dictionary)
            {
                var key = Convert.ToString(entry.Key);
                if (!string.IsNullOrWhiteSpace(key))
                    context[key] = entry.Value is null ? null : Convert.ToString(entry.Value);
            }
            return context;
        }

        var wrapped = System.Management.Automation.PSObject.AsPSObject(value);
        foreach (var property in wrapped.Properties)
            context[property.Name] = property.Value is null ? null : Convert.ToString(property.Value);
        return context;
    }

    private static string? Nullable(System.Management.Automation.PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToString(source.Properties[name]!.Value);
}
