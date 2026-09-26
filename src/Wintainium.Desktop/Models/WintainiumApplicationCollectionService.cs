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
            var stateResult = await _installedState.GetAsync(
                WintainiumDesktopPaths.InstalledStateRoot,
                application.ApplicationId, cancellationToken).ConfigureAwait(false);

            var withState = WintainiumApplicationModelMapper.ApplyInstalledState(
                application, stateResult.State);

            errors.AddRange(stateResult.Errors);
            warnings.AddRange(stateResult.Warnings);

            try
            {
                var decisionResult = await _updateDecision.EvaluateAsync(
                    application.ManifestPath!,
                    GetMachineArchitecture(),
                    cancellationToken).ConfigureAwait(false);

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