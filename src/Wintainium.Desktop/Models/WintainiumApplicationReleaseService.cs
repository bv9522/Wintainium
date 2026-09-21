using System.Management.Automation;
using Wintainium.Desktop.Engine;

namespace Wintainium.Desktop.Models;

internal sealed class WintainiumApplicationReleaseService
{
    private readonly WintainiumCoreClient _coreClient;

    public WintainiumApplicationReleaseService(WintainiumCoreClient coreClient)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
    }

    public async Task<WintainiumApplicationReleaseResult> DiscoverAsync(
        string manifestPath,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(manifestPath))
            throw new ArgumentException("The application manifest path is required.", nameof(manifestPath));

        var invocation = await _coreClient.GetApplicationReleaseAsync(
            manifestPath,
            cancellationToken: cancellationToken).ConfigureAwait(false);

        if (invocation.WasCancelled)
            throw new OperationCanceledException(cancellationToken);

        if (invocation.Output.Count != 1)
            throw new InvalidOperationException(
                $"Get-WintainiumApplicationRelease returned {invocation.Output.Count} structured results; exactly one was expected.");

        return WintainiumApplicationReleaseMapper.Map(PSObject.AsPSObject(invocation.Output[0]));
    }
}