using Wintainium.Desktop.Engine;

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

        var invocation = await _coreClient.GetApplicationUpdateDecisionAsync(
            manifestPath,
            WintainiumDesktopPaths.InstalledStateRoot,
            machineArchitecture,
            cancellationToken: cancellationToken).ConfigureAwait(false);

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation,
            "Get-WintainiumApplicationUpdateDecision",
            cancellationToken);

        return WintainiumApplicationUpdateDecisionMapper.Map(result);
    }
}
