using System.Collections;
using System.Management.Automation;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Maps Core errors and warnings while retaining a small allowlist of useful context.
/// Registry subkeys and unrelated software names are deliberately excluded.
/// </summary>
internal static class WintainiumOperationDiagnosticMapper
{
    private static readonly HashSet<string> SafeDetailNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "ApplicationId", "Capability", "CandidateCount", "ErrorCode", "EvidenceSource",
        "Host", "InstallationState", "MatchMode", "ObservedInstallationState",
        "RegistryLocationCount", "RegistryReadFailureCount",
        "DecisionReasonCode", "DecisionStatus", "InstalledVersion", "InstalledVersionSource",
        "ManifestChannelPolicy", "OperationId", "Persisted", "PriorInstallationState",
        "ProviderId", "ReasonCode", "ReleaseObservations", "Scope", "Stage", "Status",
        "TargetObservations", "View"
    };

    public static IReadOnlyList<WintainiumOperationDiagnostic> MapCollection(PSObject source, string propertyName)
    {
        ArgumentNullException.ThrowIfNull(source);
        var value = source.Properties[propertyName]?.Value;
        if (value is null) return [];

        var items = value is IEnumerable enumerable and not string
            ? enumerable.Cast<object>().Select(PSObject.AsPSObject)
            : new[] { PSObject.AsPSObject(value) };

        return items.Select(Map).ToArray();
    }

    public static WintainiumOperationDiagnostic Map(PSObject source)
    {
        ArgumentNullException.ThrowIfNull(source);
        var details = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        foreach (var property in source.Properties)
        {
            if (SafeDetailNames.Contains(property.Name) &&
                property.Name is not ("Code" or "Path" or "Message"))
            {
                details[property.Name] = FormatSafeDetail(property.Value);
            }
        }

        if (source.BaseObject is IDictionary dictionary)
        {
            foreach (DictionaryEntry entry in dictionary)
            {
                var name = Convert.ToString(entry.Key);
                if (!string.IsNullOrWhiteSpace(name) && SafeDetailNames.Contains(name))
                    details[name] = FormatSafeDetail(entry.Value);
            }
        }

        return new WintainiumOperationDiagnostic(
            Nullable(source, "Code"),
            Nullable(source, "Path"),
            Nullable(source, "Message"),
            details);
    }

    private static string? FormatSafeDetail(object? value)
    {
        if (value is null) return null;
        if (value is IDictionary || value is IEnumerable and not string)
            return System.Management.Automation.LanguagePrimitives.ConvertTo(
                value is string ? value : System.Management.Automation.PSObject.AsPSObject(value).BaseObject,
                typeof(string))?.ToString() is string text && text is not ("System.Object[]" or "System.Collections.Hashtable")
                ? text
                : System.Text.Json.JsonSerializer.Serialize(value);
        return Convert.ToString(value);
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToString(source.Properties[name]!.Value);
}
