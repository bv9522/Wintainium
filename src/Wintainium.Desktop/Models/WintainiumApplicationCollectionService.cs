using Wintainium.Desktop.Engine;
using Wintainium.Desktop.Settings;
using System.Runtime.InteropServices;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Loads the tracked application collection through the public Core manifest command.
/// </summary>
internal sealed class WintainiumApplicationCollectionService
{
    private readonly WintainiumCoreClient _coreClient;
    private readonly WintainiumApplicationInstalledStateService _installedState;
    private readonly WintainiumApplicationUpdateDecisionService _updateDecision;

    public WintainiumApplicationCollectionService(
        WintainiumCoreClient coreClient,
        WintainiumApplicationInstalledStateService installedState,
        WintainiumApplicationUpdateDecisionService updateDecision)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
        _installedState = installedState ?? throw new ArgumentNullException(nameof(installedState));
        _updateDecision = updateDecision ?? throw new ArgumentNullException(nameof(updateDecision));
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
            manifestRoot, recurse, schemaPath, cancellationToken).ConfigureAwait(false);

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation, "Get-WintainiumManifest", cancellationToken);

        var collection = WintainiumApplicationModelMapper.MapManifestResult(result);
        var applications = new List<WintainiumApplicationModel>();
        var errors = collection.Errors.ToList();
        var warnings = collection.Warnings.ToList();

        foreach (var application in collection.Applications)
        {
            var withState = application;

            try
            {
                // Installed state is an independent Core-owned observation and must remain
                // available even when update-decision evaluation fails. This keeps the
                // collection's installed facts independent from update availability.
                var installedStateResult = await _installedState.GetAsync(
                    WintainiumDesktopPaths.InstalledStateRoot,
                    application.ApplicationId,
                    cancellationToken).ConfigureAwait(false);

                if (installedStateResult.IsSuccessful)
                {
                    withState = WintainiumApplicationModelMapper.ApplyInstalledState(
                        withState, installedStateResult.State);
                }

                errors.AddRange(installedStateResult.Errors);
                warnings.AddRange(installedStateResult.Warnings);

                // Update status is a separate Core-owned observation. If it succeeds,
                // its installed-state observation may be newer (for example after Core
                // reconciliation), so it remains authoritative for this composed model.
                var decisionResult = await _updateDecision.EvaluateAsync(
                    application.ManifestPath!,
                    GetMachineArchitecture(),
                    cancellationToken).ConfigureAwait(false);

                withState = WintainiumApplicationModelMapper.ApplyInstalledState(
                    withState, decisionResult.InstalledState);
                withState = WintainiumApplicationModelMapper.ApplyUpdateDecision(
                    withState, decisionResult);
                errors.AddRange(decisionResult.Errors);
                warnings.AddRange(decisionResult.Warnings);
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                errors.Add(new WintainiumOperationDiagnostic(
                    "UpdateDecisionEvaluationFailed",
                    application.ManifestPath,
                    ex.Message));
            }

            applications.Add(withState);
        }

        var isSuccessful = collection.IsSuccessful && errors.Count == 0;
        var operationState = isSuccessful
            ? collection.OperationState
            : WintainiumOperationState.Failed;

        return collection with
        {
            IsSuccessful = isSuccessful,
            Applications = applications,
            Errors = errors,
            Warnings = warnings,
            OperationState = operationState
        };
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