using System.Collections;
using System.Management.Automation;

namespace Wintainium.Desktop.Models;

internal static class WintainiumApplicationModelMapper
{
    public static WintainiumApplicationCollectionResult MapManifestResult(PSObject result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var operationId = GetRequiredString(result, "OperationId");
        var manifests = GetCollection(result, "Manifests");
        var manifestPaths = GetCollection(result, "ManifestPaths");

        var applications = manifests
            .Select((manifest, index) => MapManifest(
                manifest,
                index < manifestPaths.Count ? GetNullableString(manifestPaths[index], null) : null))
            .ToArray();

        return new WintainiumApplicationCollectionResult(
            OperationId: operationId,
            IsSuccessful: GetBoolean(result, "IsSuccessful"),
            Applications: applications,
            Errors: GetDiagnostics(result, "Errors"),
            Warnings: GetDiagnostics(result, "Warnings"),
            OperationState: WintainiumOperationStateMapper.Map(result).State);
    }

    private static WintainiumApplicationModel MapManifest(PSObject manifest, string? manifestPath)
    {
        var applicationId = GetRequiredString(manifest, "Id");
        var name = GetRequiredString(manifest, "Name");

        return new WintainiumApplicationModel(
            ApplicationId: applicationId,
            Name: name,
            Description: GetNullableString(manifest, "Description"),
            Homepage: GetNullableString(manifest, "Homepage"),
            Publisher: GetNullableString(manifest, "Publisher"),
            IconUri: null,
            InstallationState: WintainiumInstallationState.Unknown,
            InstalledVersion: null,
            LastUpdated: null,
            UpdateStatus: WintainiumUpdateStatus.Unknown,
            SourceProviderId: GetSourceProviderId(manifest),
            ManifestPath: manifestPath);
    }

    private static string? GetSourceProviderId(PSObject manifest)
    {
        var source = GetProperty(manifest, "Source");
        return source is null ? null : GetNullableString(source, "PluginId");
    }

    private static IReadOnlyList<WintainiumOperationDiagnostic> GetDiagnostics(PSObject source, string propertyName) =>
        GetCollection(source, propertyName)
            .Select(item => new WintainiumOperationDiagnostic(
                Code: GetNullableString(item, "Code"),
                Path: GetNullableString(item, "Path"),
                Message: GetNullableString(item, "Message")))
            .ToArray();

    private static List<PSObject> GetCollection(PSObject source, string propertyName)
    {
        var value = GetProperty(source, propertyName);
        if (value is null) return [];

        if (value.BaseObject is IEnumerable enumerable and not string)
        {
            return enumerable.Cast<object>()
                .Select(item => item as PSObject ?? PSObject.AsPSObject(item))
                .ToList();
        }

        return [value];
    }

    private static PSObject? GetProperty(PSObject source, string propertyName) =>
        source.Properties[propertyName]?.Value is null
            ? null
            : PSObject.AsPSObject(source.Properties[propertyName]!.Value);

    private static string GetRequiredString(PSObject source, string propertyName)
    {
        var value = GetNullableString(source, propertyName);
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException($"Core result is missing required property '{propertyName}'.");
        return value;
    }

    private static string? GetNullableString(PSObject source, string? propertyName)
    {
        if (propertyName is null) return Convert.ToString(source.BaseObject);
        var property = source.Properties[propertyName];
        return property?.Value is null ? null : Convert.ToString(property.Value);
    }

    private static bool GetBoolean(PSObject source, string propertyName)
    {
        var property = source.Properties[propertyName];
        return property?.Value is not null && Convert.ToBoolean(property.Value);
    }
}