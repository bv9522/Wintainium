using System.Collections;
using System.Management.Automation;
using Wintainium.Desktop.Engine;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Presents the Core application-onboarding boundary to the desktop client.
/// Core owns the default lifecycle policy; the desktop client may optionally
/// pass an already-authorized policy object but never constructs one here.
/// </summary>
internal sealed class WintainiumApplicationOnboardingService
{
    private readonly WintainiumCoreClient _coreClient;

    public WintainiumApplicationOnboardingService(WintainiumCoreClient coreClient)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
    }

    public async Task<WintainiumApplicationOnboardingResult> OnboardAsync(
        string sourceUri,
        string manifestRoot,
        object? policy = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(sourceUri))
            throw new ArgumentException("The source URL is required.", nameof(sourceUri));
        if (string.IsNullOrWhiteSpace(manifestRoot))
            throw new ArgumentException("The manifest collection path is required.", nameof(manifestRoot));

        var invocation = await _coreClient.OnboardApplicationAsync(
            sourceUri,
            manifestRoot,
            policy,
            pluginRoot: GetDebugPluginRootOverride(),
            cancellationToken: cancellationToken).ConfigureAwait(false);

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation,
            "Invoke-WintainiumApplicationOnboarding",
            cancellationToken);

        return new WintainiumApplicationOnboardingResult(
            OperationId: Required(result, "OperationId"),
            IsSuccessful: Boolean(result, "IsSuccessful"),
            Status: Nullable(result, "Status"),
            Application: MapApplication(result, Nullable(result, "ManifestPath")),
            ManifestPath: Nullable(result, "ManifestPath"),
            Errors: Diagnostics(result, "Errors"),
            Warnings: Diagnostics(result, "Warnings"),
            OperationState: WintainiumOperationStateMapper.Map(result).State);
    }

    private static string? GetDebugPluginRootOverride()
    {
#if DEBUG
        var value = Environment.GetEnvironmentVariable("WINTAINIUM_DESKTOP_PLUGIN_ROOT");
        return string.IsNullOrWhiteSpace(value) ? null : value;
#else
        return null;
#endif
    }

    private static WintainiumApplicationModel? MapApplication(PSObject result, string? manifestPath)
    {
        var value = result.Properties["ApplicationDefinition"]?.Value;
        if (value is null)
            return null;

        return MapManifest(PSObject.AsPSObject(value), manifestPath);
    }

    private static WintainiumApplicationModel MapManifest(PSObject manifest, string? manifestPath) =>
        new(
            ApplicationId: Required(manifest, "Id"),
            Name: Required(manifest, "Name"),
            Description: Nullable(manifest, "Description"),
            Homepage: Nullable(manifest, "Homepage"),
            Publisher: Nullable(manifest, "Publisher"),
            IconUri: null,
            InstallationState: WintainiumInstallationState.Unknown,
            InstalledVersion: null,
            LastUpdated: null,
            UpdateStatus: WintainiumUpdateStatus.Unknown,
            SourceProviderId: SourceProviderId(manifest),
            ManifestPath: manifestPath);

    private static string? SourceProviderId(PSObject manifest)
    {
        var source = manifest.Properties["Source"]?.Value;
        return source is null ? null : Nullable(PSObject.AsPSObject(source), "PluginId");
    }

    private static IReadOnlyList<WintainiumOperationDiagnostic> Diagnostics(PSObject source, string name)
    {
        var value = source.Properties[name]?.Value;
        if (value is null)
            return [];

        if (value is IEnumerable enumerable and not string)
        {
            return enumerable.Cast<object>()
                .Select(item => PSObject.AsPSObject(item))
                .Select(item => new WintainiumOperationDiagnostic(
                    Nullable(item, "Code"),
                    Nullable(item, "Path"),
                    Nullable(item, "Message")))
                .ToArray();
        }

        var item = PSObject.AsPSObject(value);
        return [new WintainiumOperationDiagnostic(
            Nullable(item, "Code"),
            Nullable(item, "Path"),
            Nullable(item, "Message"))];
    }

    private static string Required(PSObject source, string name)
    {
        var value = Nullable(source, name);
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException($"Core result is missing required property '{name}'.");
        return value;
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToString(source.Properties[name]!.Value);

    private static bool Boolean(PSObject source, string name) =>
        source.Properties[name]?.Value is not null && Convert.ToBoolean(source.Properties[name]!.Value);
}
