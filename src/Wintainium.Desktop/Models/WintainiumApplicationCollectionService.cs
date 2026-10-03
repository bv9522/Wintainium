using Wintainium.Desktop.Engine;
using Wintainium.Desktop.Settings;
using System.Runtime.InteropServices;

namespace Wintainium.Desktop.Models;

internal sealed class WintainiumApplicationCollectionService
{
    private readonly WintainiumCoreClient _coreClient;
    private readonly WintainiumApplicationInstalledStateService _installedState;
    private readonly WintainiumApplicationUpdateDecisionService _updateDecision;

    public WintainiumApplicationCollectionService(WintainiumCoreClient coreClient, WintainiumApplicationInstalledStateService installedState, WintainiumApplicationUpdateDecisionService updateDecision)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
        _installedState = installedState ?? throw new ArgumentNullException(nameof(installedState));
        _updateDecision = updateDecision ?? throw new ArgumentNullException(nameof(updateDecision));
    }

    /// <summary>
    /// Loads the tracked application collection without performing per-application
    /// reconciliation or live release discovery. This is intentionally fast so the
    /// Dashboard can present the collection before network and reconciliation work runs.
    /// </summary>
    public async Task<WintainiumApplicationCollectionResult> LoadAsync(
        string manifestRoot,
        bool recurse = true,
        string? schemaPath = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(manifestRoot))
            throw new ArgumentException("The manifest collection path is required.", nameof(manifestRoot));

        var invocation = await _coreClient.GetManifestsAsync(
            manifestRoot, recurse, schemaPath, cancellationToken).ConfigureAwait(false);

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation, "Get-WintainiumManifest", cancellationToken);

        return WintainiumApplicationModelMapper.MapManifestResult(result);
    }

    /// <summary>
    /// Hydrates one application from the last persisted Core installed-state observation.
    /// This performs no reconciliation or provider discovery, so it is suitable for
    /// immediate Dashboard hydration before live background refresh begins.
    /// </summary>
    public async Task<WintainiumApplicationModel> HydratePersistedApplicationStateAsync(
        WintainiumApplicationModel application,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(application);

        if (string.IsNullOrWhiteSpace(application.ApplicationId))
            throw new ArgumentException("The application identifier is required.", nameof(application));

        var result = await _installedState.GetAsync(
            WintainiumDesktopPaths.InstalledStateRoot,
            application.ApplicationId,
            cancellationToken).ConfigureAwait(false);

        return result.IsSuccessful
            ? WintainiumApplicationModelMapper.ApplyInstalledState(application, result.State)
            : application;
    }

    /// <summary>
    /// Refreshes one application. Multiple callers may run independently; the
    /// desktop PowerShell host continues to serialize individual Core invocations.
    /// </summary>
    public async Task<WintainiumApplicationRefreshResult> RefreshApplicationAsync(
        WintainiumApplicationModel application,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(application);

        if (string.IsNullOrWhiteSpace(application.ManifestPath))
            throw new ArgumentException("The application manifest path is required.", nameof(application));

        var errors = new List<WintainiumOperationDiagnostic>();
        var warnings = new List<WintainiumOperationDiagnostic>();
        var withState = application;

        try
        {
            var refreshResult = await _installedState.RefreshAsync(
                application.ManifestPath, WintainiumDesktopPaths.InstalledStateRoot,
                cancellationToken: cancellationToken).ConfigureAwait(false);

            if (refreshResult.IsSuccessful)
                withState = WintainiumApplicationModelMapper.ApplyInstalledState(withState, refreshResult.State);

            errors.AddRange(refreshResult.Errors);
            warnings.AddRange(refreshResult.Warnings);

            var installedStateResult = await _installedState.GetAsync(
                WintainiumDesktopPaths.InstalledStateRoot, application.ApplicationId,
                cancellationToken).ConfigureAwait(false);

            if (installedStateResult.IsSuccessful)
                withState = WintainiumApplicationModelMapper.ApplyInstalledState(withState, installedStateResult.State);

            errors.AddRange(installedStateResult.Errors);
            warnings.AddRange(installedStateResult.Warnings);

            var decisionResult = await _updateDecision.EvaluateAsync(
                application.ManifestPath, GetMachineArchitecture(),
                cancellationToken).ConfigureAwait(false);

            withState = WintainiumApplicationModelMapper.ApplyInstalledState(withState, decisionResult.InstalledState);
            withState = WintainiumApplicationModelMapper.ApplyUpdateDecision(withState, decisionResult);
            errors.AddRange(decisionResult.Errors);
            warnings.AddRange(decisionResult.Warnings);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            errors.Add(new WintainiumOperationDiagnostic("ApplicationRefreshFailed", application.ManifestPath, ex.Message));
        }

        return new WintainiumApplicationRefreshResult(withState, errors, warnings);
    }

    private static string GetMachineArchitecture() =>
        RuntimeInformation.OSArchitecture.ToString().ToLowerInvariant() switch
        {
            "x64" => "x64",
            "x86" => "x86",
            "arm64" => "arm64",
            "arm" => "arm",
            _ => "unknown"
        };
}