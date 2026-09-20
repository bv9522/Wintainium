using System.Collections;
using System.Management.Automation;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Maps documented Core manifest results into desktop presentation models.
/// No update or installation decisions are made here.
/// </summary>
internal static class WintainiumApplicationModelMapper
{
    public static IReadOnlyList<WintainiumApplicationModel> MapManifestResult(PSObject result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var manifests = GetCollection(result, "Manifests");
        var models = new List<WintainiumApplicationModel>(manifests.Count);

        foreach (var manifest in manifests)
        {
            models.Add(MapManifest(manifest));
        }

        return models;
    }

    private static WintainiumApplicationModel MapManifest(PSObject manifest)
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
            LastUpdatedDisplay: null,
            UpdateStatus: WintainiumUpdateStatus.Unknown,
            SourceDisplayName: GetSourceDisplayName(manifest));
    }

    private static string? GetSourceDisplayName(PSObject manifest)
    {
        var source = GetProperty(manifest, "Source");
        if (source is null)
        {
            return null;
        }

        return GetNullableString(source, "PluginId");
    }

    private static List<PSObject> GetCollection(PSObject source, string propertyName)
    {
        var value = GetProperty(source, propertyName);
        if (value is null)
        {
            return [];
        }

        if (value.BaseObject is IEnumerable enumerable and not string)
        {
            return enumerable
                .Cast<object>()
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
        {
            throw new InvalidOperationException(
                $"Core manifest result is missing required property '{propertyName}'.");
        }

        return value;
    }

    private static string? GetNullableString(PSObject source, string propertyName)
    {
        var property = source.Properties[propertyName];
        return property?.Value is null ? null : Convert.ToString(property.Value);
    }
}