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

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation,
            "Get-WintainiumApplicationRelease",
            cancellationToken);

        return WintainiumApplicationReleaseMapper.Map(result);
    }
}
