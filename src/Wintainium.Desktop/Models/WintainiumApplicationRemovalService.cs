using System.Collections;
using System.Management.Automation;
using Wintainium.Desktop.Engine;

namespace Wintainium.Desktop.Models;

internal sealed class WintainiumApplicationRemovalService
{
    private readonly WintainiumCoreClient _coreClient;

    public WintainiumApplicationRemovalService(WintainiumCoreClient coreClient)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
    }

    public async Task<WintainiumApplicationRemovalResult> RemoveFromCollectionAsync(
        string manifestPath,
        string manifestRoot,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(manifestPath);
        ArgumentException.ThrowIfNullOrWhiteSpace(manifestRoot);

        var invocation = await _coreClient.RemoveApplicationAsync(
            manifestPath,
            manifestRoot,
            cancellationToken: cancellationToken).ConfigureAwait(false);

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation,
            "Remove-WintainiumApplication",
            cancellationToken);

        return new WintainiumApplicationRemovalResult(
            OperationId: Nullable(result, "OperationId") ?? string.Empty,
            IsSuccessful: Boolean(result, "IsSuccessful"),
            Status: Nullable(result, "Status"),
            Errors: Diagnostics(result, "Errors"),
            Warnings: Diagnostics(result, "Warnings"));
    }

    private static IReadOnlyList<WintainiumOperationDiagnostic> Diagnostics(PSObject source, string name)
    {
        var value = source.Properties[name]?.Value;
        if (value is null)
            return [];

        var values = value is IEnumerable enumerable and not string
            ? enumerable.Cast<object>().Select(PSObject.AsPSObject)
            : [PSObject.AsPSObject(value)];

        return values.Select(item => new WintainiumOperationDiagnostic(
            Nullable(item, "Code"),
            Nullable(item, "Path"),
            Nullable(item, "Message"))).ToArray();
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null
            ? null
            : Convert.ToString(source.Properties[name]!.Value);

    private static bool Boolean(PSObject source, string name) =>
        source.Properties[name]?.Value is not null &&
        Convert.ToBoolean(source.Properties[name]!.Value);
}
