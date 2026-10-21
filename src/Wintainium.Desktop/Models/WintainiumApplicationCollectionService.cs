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
        var stages = new List<WintainiumApplicationRefreshStage>();
        var withState = application;
        string currentStage = "InstalledStateReconciliation";
        string? operationId = null;

        try
        {
            var beforeReconciliation = withState.InstallationState;
            var refreshResult = await _installedState.RefreshAsync(
                application.ManifestPath, WintainiumDesktopPaths.InstalledStateRoot,
                cancellationToken: cancellationToken).ConfigureAwait(false);
            operationId ??= refreshResult.OperationId;

            if (refreshResult.IsSuccessful)
                withState = ApplyInstalledStateForRefreshStage(withState, refreshResult.State, "DesktopInstalledStateMapping", "DesktopInstalledStateMappingFailed");

            errors.AddRange(refreshResult.Errors);
            warnings.AddRange(refreshResult.Warnings);
            var reconciliationStageName = refreshResult.Status == "DesktopMappingFailed"
                ? "DesktopInstalledStateMapping"
                : currentStage;
            stages.Add(new WintainiumApplicationRefreshStage(
                reconciliationStageName,
                refreshResult.OperationId,
                refreshResult.IsSuccessful ? (refreshResult.Status ?? "Completed") : (refreshResult.Status ?? "Failed"),
                GetStageReasonCode(refreshResult.Reconciliation?.ReasonCode, refreshResult.Errors, refreshResult.Warnings),
                beforeReconciliation,
                withState.InstallationState,
                refreshResult.Errors,
                refreshResult.Warnings,
                refreshResult.LogEvents ?? []));

            currentStage = "PersistedInstalledStateRead";
            var beforeStateRead = withState.InstallationState;
            var installedStateResult = await _installedState.GetAsync(
                WintainiumDesktopPaths.InstalledStateRoot, application.ApplicationId,
                cancellationToken).ConfigureAwait(false);
            operationId ??= installedStateResult.OperationId;

            if (installedStateResult.IsSuccessful)
                withState = ApplyInstalledStateForRefreshStage(withState, installedStateResult.State, "DesktopPersistedStateMapping", "DesktopPersistedStateMappingFailed");

            errors.AddRange(installedStateResult.Errors);
            warnings.AddRange(installedStateResult.Warnings);
            var persistedStateStageName = installedStateResult.Status == "DesktopMappingFailed"
                ? "DesktopPersistedStateMapping"
                : currentStage;
            stages.Add(new WintainiumApplicationRefreshStage(
                persistedStateStageName,
                installedStateResult.OperationId,
                installedStateResult.IsSuccessful ? (installedStateResult.Status ?? "Completed") : (installedStateResult.Status ?? "Failed"),
                GetStageReasonCode(null, installedStateResult.Errors, installedStateResult.Warnings),
                beforeStateRead,
                withState.InstallationState,
                installedStateResult.Errors,
                installedStateResult.Warnings,
                installedStateResult.LogEvents ?? []));

            currentStage = "UpdateDecision";
            var beforeDecision = withState.InstallationState;
            var decisionResult = await _updateDecision.EvaluateAsync(
                application.ManifestPath, GetMachineArchitecture(),
                cancellationToken).ConfigureAwait(false);
            operationId ??= decisionResult.OperationId;

            withState = ApplyInstalledStateForRefreshStage(withState, decisionResult.InstalledState, "DesktopUpdateDecisionMapping", "DesktopUpdateDecisionMappingFailed");
            withState = WintainiumApplicationModelMapper.ApplyUpdateDecision(withState, decisionResult);
            errors.AddRange(decisionResult.Errors);
            warnings.AddRange(decisionResult.Warnings);
            var updateDecisionStageName = decisionResult.Status == "DesktopMappingFailed"
                ? "DesktopUpdateDecisionMapping"
                : currentStage;
            stages.Add(new WintainiumApplicationRefreshStage(
                updateDecisionStageName,
                decisionResult.OperationId,
                decisionResult.IsSuccessful ? (decisionResult.Status ?? "Completed") : (decisionResult.Status ?? "Failed"),
                GetStageReasonCode(decisionResult.Decision?.ReasonCode, decisionResult.Errors, decisionResult.Warnings),
                beforeDecision,
                withState.InstallationState,
                decisionResult.Errors,
                decisionResult.Warnings,
                decisionResult.LogEvents ?? []));
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (DesktopRefreshMappingException ex)
        {
            var diagnostic = new WintainiumOperationDiagnostic(ex.ReasonCode, application.ManifestPath, ex.InnerException?.Message ?? ex.Message);
            errors.Add(diagnostic);
            stages.Add(new WintainiumApplicationRefreshStage(
                ex.StageName,
                operationId,
                "Failed",
                ex.ReasonCode,
                withState.InstallationState,
                withState.InstallationState,
                [diagnostic],
                [],
                []));
        }
        catch (Exception ex)
        {
            var failureCode = currentStage switch
            {
                "InstalledStateReconciliation" => "InstalledStateReconciliationFailed",
                "PersistedInstalledStateRead" => "PersistedInstalledStateReadFailed",
                "UpdateDecision" => "UpdateDecisionFailed",
                _ => "ApplicationRefreshFailed"
            };
            var diagnostic = new WintainiumOperationDiagnostic(failureCode, application.ManifestPath, ex.Message);
            errors.Add(diagnostic);
            stages.Add(new WintainiumApplicationRefreshStage(
                currentStage,
                operationId,
                "Failed",
                failureCode,
                withState.InstallationState,
                withState.InstallationState,
                [diagnostic],
                [],
                []));
        }

        return new WintainiumApplicationRefreshResult(withState, errors, warnings, operationId, stages, DateTimeOffset.UtcNow);
    }

    private static WintainiumApplicationModel ApplyInstalledStateForRefreshStage(
        WintainiumApplicationModel application,
        WintainiumInstalledStateObservation? state,
        string stageName,
        string reasonCode)
    {
        try
        {
            return WintainiumApplicationModelMapper.ApplyInstalledState(application, state);
        }
        catch (Exception ex)
        {
            throw new DesktopRefreshMappingException(stageName, reasonCode, ex);
        }
    }

    private sealed class DesktopRefreshMappingException : Exception
    {
        public DesktopRefreshMappingException(string stageName, string reasonCode, Exception innerException)
            : base($"Desktop mapping failed during {stageName}.", innerException)
        {
            StageName = stageName;
            ReasonCode = reasonCode;
        }

        public string StageName { get; }
        public string ReasonCode { get; }
    }

    private static string? GetStageReasonCode(
        string? explicitReason,
        IReadOnlyList<WintainiumOperationDiagnostic> errors,
        IReadOnlyList<WintainiumOperationDiagnostic> warnings)
    {
        if (!string.IsNullOrWhiteSpace(explicitReason))
            return explicitReason;

        return errors.Select(item => item.Code)
                   .Concat(warnings.Select(item => item.Code))
                   .FirstOrDefault(code => !string.IsNullOrWhiteSpace(code));
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