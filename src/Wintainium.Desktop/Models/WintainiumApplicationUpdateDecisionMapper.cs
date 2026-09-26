using System.Collections;
using System.Management.Automation;

namespace Wintainium.Desktop.Models;

internal static class WintainiumApplicationUpdateDecisionMapper
{
    public static WintainiumApplicationUpdateDecisionResult Map(PSObject result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var decisionValue = result.Properties["Decision"]?.Value;
        var installedValue = result.Properties["InstalledState"]?.Value;

        return new WintainiumApplicationUpdateDecisionResult(
            OperationId: Required(result, "OperationId"),
            IsSuccessful: Boolean(result, "IsSuccessful"),
            Status: Nullable(result, "Status"),
            Decision: decisionValue is null ? null : MapDecision(PSObject.AsPSObject(decisionValue)),
            InstalledState: installedValue is null ? null : MapInstalledState(PSObject.AsPSObject(installedValue)),
            Errors: Diagnostics(result, "Errors"),
            Warnings: Diagnostics(result, "Warnings"),
            OperationState: DetermineState(Boolean(result, "IsSuccessful")));
    }

    private static WintainiumInstalledStateObservation MapInstalledState(PSObject source)
    {
        var installationStateText = Required(source, "InstallationState");
        if (!Enum.TryParse<WintainiumInstallationState>(installationStateText, ignoreCase: false, out var installationState))
            throw new InvalidOperationException($"Core update status result returned unknown InstallationState '{installationStateText}'.");

        return new WintainiumInstalledStateObservation(
            Required(source, "ApplicationId"),
            installationState,
            Nullable(source, "Version"),
            Nullable(source, "VersionSource"),
            Nullable(source, "Architecture"),
            Nullable(source, "Channel"),
            Nullable(source, "InstallationLocation"));
    }

    private static WintainiumApplicationUpdateDecisionModel MapDecision(PSObject decision) =>
        new(
            IsUpdateAvailable: NullableBoolean(decision, "IsUpdateAvailable"),
            ReasonCode: Nullable(decision, "ReasonCode"),
            Reason: Nullable(decision, "Reason"),
            SelectedRelease: MapRelease(decision.Properties["SelectedRelease"]?.Value),
            IsDeterministic: Boolean(decision, "IsDeterministic"));

    private static WintainiumApplicationReleaseModel? MapRelease(object? value)
    {
        if (value is null) return null;
        var release = PSObject.AsPSObject(value);
        var artifacts = Collection(release, "Artifacts").Select(MapArtifact).Where(static item => item is not null).Cast<WintainiumReleaseArtifactModel>().ToArray();

        return new WintainiumApplicationReleaseModel(
            Required(release, "ReleaseId"),
            Required(release, "Version"),
            Required(release, "Channel"),
            DateTimeOffset.TryParse(Nullable(release, "PublishedAt"), out var published) ? published : null,
            artifacts);
    }

    private static WintainiumReleaseArtifactModel? MapArtifact(object? value)
    {
        if (value is null) return null;
        var artifact = PSObject.AsPSObject(value);
        return new WintainiumReleaseArtifactModel(
            Nullable(artifact, "Uri"),
            Nullable(artifact, "FileName"),
            Nullable(artifact, "Format"),
            Nullable(artifact, "Architecture"),
            Long(artifact, "Size"),
            Collection(artifact, "Hashes")
                .Select(hash => new WintainiumArtifactHashModel(Nullable(hash, "Algorithm"), Nullable(hash, "Value")))
                .ToArray());
    }

    private static WintainiumOperationState DetermineState(bool successful) =>
        successful ? WintainiumOperationState.Completed : WintainiumOperationState.Failed;

    private static IReadOnlyList<WintainiumOperationDiagnostic> Diagnostics(PSObject source, string name) =>
        Collection(source, name).Select(static item => new WintainiumOperationDiagnostic(
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
            throw new InvalidOperationException($"Core update decision result is missing required property '{name}'.");
        return value;
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToString(source.Properties[name]!.Value);

    private static bool Boolean(PSObject source, string name) =>
        source.Properties[name]?.Value is not null && Convert.ToBoolean(source.Properties[name]!.Value);

    private static bool? NullableBoolean(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToBoolean(source.Properties[name]!.Value);

    private static long? Long(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToInt64(source.Properties[name]!.Value);
}
