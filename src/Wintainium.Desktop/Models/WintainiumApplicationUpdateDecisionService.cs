using Wintainium.Desktop.Engine;
using Wintainium.Desktop.Settings;

namespace Wintainium.Desktop.Models;

internal sealed class WintainiumApplicationUpdateDecisionService
{
    private readonly WintainiumCoreClient _coreClient;

    public WintainiumApplicationUpdateDecisionService(WintainiumCoreClient coreClient)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
    }

    public async Task<WintainiumApplicationUpdateDecisionResult> EvaluateAsync(
        string manifestPath,
        string machineArchitecture,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(manifestPath))
            throw new ArgumentException("The application manifest path is required.", nameof(manifestPath));
        if (string.IsNullOrWhiteSpace(machineArchitecture))
            throw new ArgumentException("The machine architecture is required.", nameof(machineArchitecture));

        var invocation = await _coreClient.GetApplicationUpdateStatusAsync(
            manifestPath,
            WintainiumDesktopPaths.InstalledStateRoot,
            machineArchitecture,
            cancellationToken: cancellationToken).ConfigureAwait(false);

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation,
            "Get-WintainiumApplicationUpdateStatus",
            cancellationToken);

        return MapSafely(result);
    }
    private static WintainiumApplicationUpdateDecisionResult MapSafely(System.Management.Automation.PSObject result)
    {
        try
        {
            return WintainiumApplicationUpdateDecisionMapper.Map(result);
        }
        catch (Exception ex)
        {
            var diagnostic = new WintainiumOperationDiagnostic(
                "DesktopUpdateDecisionMappingFailed", null,
                $"The desktop could not map the Core update-decision result: {ex.Message}");
            IReadOnlyList<WintainiumOperationDiagnostic> errors;
            IReadOnlyList<WintainiumOperationDiagnostic> warnings;
            try { errors = WintainiumOperationDiagnosticMapper.MapCollection(result, "Errors").Append(diagnostic).ToArray(); }
            catch { errors = [diagnostic]; }
            try { warnings = WintainiumOperationDiagnosticMapper.MapCollection(result, "Warnings"); }
            catch { warnings = []; }

            return new WintainiumApplicationUpdateDecisionResult(
                result.Properties["OperationId"]?.Value is null
                    ? "unavailable"
                    : Convert.ToString(result.Properties["OperationId"]!.Value) ?? "unavailable",
                false,
                "DesktopMappingFailed",
                null,
                null,
                errors,
                warnings,
                WintainiumOperationState.Failed,
                []);
        }
    }
}
