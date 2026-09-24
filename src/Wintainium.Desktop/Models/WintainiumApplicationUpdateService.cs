using Wintainium.Desktop.Engine;

namespace Wintainium.Desktop.Models;

internal sealed class WintainiumApplicationUpdateService
{
    private readonly WintainiumCoreClient _coreClient;

    public WintainiumApplicationUpdateService(WintainiumCoreClient coreClient)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
    }

    public async Task<WintainiumApplicationUpdateResult> ExecuteAsync(
        string manifestPath,
        string stateRoot,
        string machineArchitecture,
        string downloadRoot,
        string? pluginRoot = null,
        string? schemaPath = null,
        int installerTimeoutMilliseconds = 600_000,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(manifestPath);
        ArgumentException.ThrowIfNullOrWhiteSpace(stateRoot);
        ArgumentException.ThrowIfNullOrWhiteSpace(machineArchitecture);
        ArgumentException.ThrowIfNullOrWhiteSpace(downloadRoot);

        var invocation = await _coreClient.UpdateApplicationAsync(
            manifestPath,
            stateRoot,
            machineArchitecture,
            downloadRoot,
            pluginRoot,
            schemaPath,
            installerTimeoutMilliseconds,
            cancellationToken).ConfigureAwait(false);

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation,
            "Invoke-WintainiumApplicationUpdate",
            cancellationToken);

        return WintainiumApplicationUpdateMapper.Map(result);
    }
}