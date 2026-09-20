using System.Management.Automation;
using Wintainium.Desktop.Engine;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Loads the tracked application collection through the public Core manifest command.
/// </summary>
internal sealed class WintainiumApplicationCollectionService
{
    private readonly WintainiumCoreClient _coreClient;

    public WintainiumApplicationCollectionService(WintainiumCoreClient coreClient)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
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

        if (invocation.WasCancelled)
        {
            throw new OperationCanceledException(cancellationToken);
        }

        if (invocation.Output.Count != 1)
        {
            throw new InvalidOperationException(
                $"Get-WintainiumManifest returned {invocation.Output.Count} structured results; exactly one was expected.");
        }

        return WintainiumApplicationModelMapper.MapManifestResult(
            PSObject.AsPSObject(invocation.Output[0]));
    }
}
