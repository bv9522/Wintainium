using System.Collections;
using System.Management.Automation;
using Wintainium.Desktop.Engine;

namespace Wintainium.Desktop.Models;

internal sealed class WintainiumApplicationInstalledStateService
{
    private readonly WintainiumCoreClient _coreClient;

    public WintainiumApplicationInstalledStateService(WintainiumCoreClient coreClient)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
    }

    public async Task<WintainiumApplicationInstalledStateResult> GetAsync(
        string stateRoot,
        string applicationId,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(stateRoot))
            throw new ArgumentException("The installed-state path is required.", nameof(stateRoot));
        if (string.IsNullOrWhiteSpace(applicationId))
            throw new ArgumentException("The application identifier is required.", nameof(applicationId));

        var invocation = await _coreClient.GetInstalledApplicationStateAsync(
            stateRoot,
            applicationId,
            cancellationToken: cancellationToken).ConfigureAwait(false);

        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation,
            "Get-WintainiumApplicationInstalledState",
            cancellationToken);

        return Map(result);
    }

    private static WintainiumApplicationInstalledStateResult Map(PSObject result)
    {
        return new WintainiumApplicationInstalledStateResult(
            Required(result, "OperationId"),
            Required(result, "ApplicationId"),
            Boolean(result, "IsSuccessful"),
            Nullable(result, "Status"),
            WintainiumApplicationModelMapper.MapInstalledStateResult(result),
            Diagnostics(result, "Errors"),
            Diagnostics(result, "Warnings"),
            WintainiumOperationStateMapper.Map(result).State);
    }

    private static WintainiumInstalledStateObservation MapState(PSObject state) =>
        new(
            Required(state, "ApplicationId"),
            ParseInstallationState(Required(state, "InstallationState")),
            Nullable(state, "Version"),
            Nullable(state, "VersionSource"),
            Nullable(state, "Architecture"),
            Nullable(state, "Channel"),
            Nullable(state, "InstallationLocation"));

    private static WintainiumInstallationState ParseInstallationState(string value) =>
        Enum.TryParse<WintainiumInstallationState>(value, ignoreCase: false, out var state)
            ? state
            : throw new InvalidOperationException($"Core installed-state result returned unknown InstallationState '{value}'.");

    private static IReadOnlyList<WintainiumOperationDiagnostic> Diagnostics(PSObject source, string name) =>
        Collection(source, name).Select(item => new WintainiumOperationDiagnostic(
            Nullable(item, "Code"), Nullable(item, "Path"), Nullable(item, "Message"))).ToArray();

    private static List<PSObject> Collection(PSObject source, string name)
    {
        var value = source.Properties[name]?.Value;
        if (value is null) return [];
        if (value is IEnumerable enumerable and not string)
            return enumerable.Cast<object>().Select(PSObject.AsPSObject).ToList();
        return [PSObject.AsPSObject(value)];
    }

    private static string Required(PSObject source, string name)
    {
        var value = Nullable(source, name);
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException($"Core installed-state result is missing required property '{name}'.");
        return value;
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToString(source.Properties[name]!.Value);

    private static bool Boolean(PSObject source, string name) =>
        source.Properties[name]?.Value is not null && Convert.ToBoolean(source.Properties[name]!.Value);
}
