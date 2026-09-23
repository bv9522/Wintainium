using Wintainium.Desktop.Engine;
using Wintainium.Desktop.Settings;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Loads the tracked application collection through the public Core manifest command.
/// </summary>
internal sealed class WintainiumApplicationCollectionService
{
    private readonly WintainiumCoreClient _coreClient;
    private readonly WintainiumApplicationInstalledStateService _installedState;

    public WintainiumApplicationCollectionService(
        WintainiumCoreClient coreClient,
        WintainiumApplicationInstalledStateService installedState)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
        _installedState = installedState ?? throw new ArgumentNullException(nameof(installedState));
    }

    public async Task<WintainiumApplicationCollectionResult> LoadAsync(
        string manifestRoot,
        bool recurse = true,
        string? schemaPath = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(manifestRoot))
        {
            throw new ArgumentException("The manifest collection path is required.", nameof(manifestRoot));
        }

        var invocation = await _coreClient.GetManifestsAsync(
            manifestRoot,
            recurse,
            schemaPath,
            cancellationToken).ConfigureAwait(false);

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation,
            "Get-WintainiumManifest",
            cancellationToken);

        var collection = WintainiumApplicationModelMapper.MapManifestResult(result);
        var applications = new List<WintainiumApplicationModel>();
        var errors = collection.Errors.ToList();
        var warnings = collection.Warnings.ToList();

        foreach (var application in collection.Applications)
        {
            var stateResult = await _installedState.GetAsync(
                WintainiumDesktopPaths.InstalledStateRoot,
                application.ApplicationId,
                cancellationToken).ConfigureAwait(false);

            var mappedState = WintainiumApplicationModelMapper.MapInstalledStateResult(
                ToPowerShellObject(stateResult));

            applications.Add(WintainiumApplicationModelMapper.ApplyInstalledState(application, mappedState));
            errors.AddRange(stateResult.Errors);
            warnings.AddRange(stateResult.Warnings);
        }

        return collection with
        {
            IsSuccessful = collection.IsSuccessful && errors.Count == 0,
            Applications = applications,
            Errors = errors,
            Warnings = warnings
        };
    }
    private static System.Management.Automation.PSObject ToPowerShellObject(
        WintainiumApplicationInstalledStateResult result) =>
        System.Management.Automation.PSObject.AsPSObject(new
        {
            result.OperationId,
            result.ApplicationId,
            result.IsSuccessful,
            result.Status,
            State = result.State is null ? null : new
            {
                result.State.ApplicationId,
                InstallationState = result.State.InstallationState.ToString(),
                result.State.Version,
                result.State.VersionSource,
                result.State.Architecture,
                result.State.Channel,
                result.State.InstallationLocation
            }
        });

}
