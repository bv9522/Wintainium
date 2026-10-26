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

        // Structured log events keep diagnostic context nested. Promote only explicitly
        // allowlisted context fields so useful evidence survives desktop mapping safely.
        var contextValue = source.Properties["Context"]?.Value;
        if (contextValue is IDictionary contextDictionary)
        {
            foreach (DictionaryEntry entry in contextDictionary)
            {
                var name = Convert.ToString(entry.Key);
                if (!string.IsNullOrWhiteSpace(name) && SafeDetailNames.Contains(name))
                    details[name] = FormatSafeDetail(entry.Value);
            }
        }
        else if (contextValue is not null)
        {
            var context = PSObject.AsPSObject(contextValue);
            foreach (var property in context.Properties)
            {
                if (SafeDetailNames.Contains(property.Name))
                    details[property.Name] = FormatSafeDetail(property.Value);
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
            return System.Text.Json.JsonSerializer.Serialize(ToJsonSafeValue(value));
        return Convert.ToString(value);
    }

    private static object? ToJsonSafeValue(object? value)
    {
        if (value is null) return null;
        if (value is IDictionary dictionary)
        {
            var result = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            foreach (DictionaryEntry entry in dictionary)
            {
                var key = Convert.ToString(entry.Key);
                if (!string.IsNullOrWhiteSpace(key))
                    result[key] = ToJsonSafeValue(entry.Value);
            }
            return result;
        }

        if (value is IEnumerable enumerable and not string)
            return enumerable.Cast<object?>().Select(ToJsonSafeValue).ToArray();

        var wrapped = PSObject.AsPSObject(value);
        if (wrapped.BaseObject is PSCustomObject)
        {
            var result = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);
            foreach (var property in wrapped.Properties)
            {
                if (property.MemberType is PSMemberTypes.NoteProperty or PSMemberTypes.Property or PSMemberTypes.AliasProperty)
                    result[property.Name] = ToJsonSafeValue(property.Value);
            }
            return result;
        }

        return Convert.ToString(value);
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToString(source.Properties[name]!.Value);
}
