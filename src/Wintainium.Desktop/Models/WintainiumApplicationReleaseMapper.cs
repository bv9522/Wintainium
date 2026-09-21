using System.Collections;
using System.Management.Automation;

namespace Wintainium.Desktop.Models;

internal static class WintainiumApplicationReleaseMapper
{
    public static WintainiumApplicationReleaseResult Map(PSObject result)
    {
        ArgumentNullException.ThrowIfNull(result);

        return new WintainiumApplicationReleaseResult(
            OperationId: Required(result, "OperationId"),
            IsSuccessful: Boolean(result, "IsSuccessful"),
            Status: Nullable(result, "Status"),
            Releases: Collection(result, "Releases").Select(MapRelease).ToArray(),
            Errors: Diagnostics(result, "Errors"),
            Warnings: Diagnostics(result, "Warnings"),
            OperationState: WintainiumOperationStateMapper.Map(result).State);
    }

    private static WintainiumApplicationReleaseModel MapRelease(PSObject release) =>
        new(
            ReleaseId: Required(release, "ReleaseId"),
            Version: Required(release, "Version"),
            Channel: Required(release, "Channel"),
            PublishedAt: DateTimeOffset.TryParse(
                Nullable(release, "PublishedAt"),
                out var published) ? published : null,
            Artifacts: Collection(release, "Artifacts").Select(MapArtifact).ToArray());

    private static WintainiumReleaseArtifactModel MapArtifact(PSObject artifact) =>
        new(
            Uri: Nullable(artifact, "Uri"),
            FileName: Nullable(artifact, "FileName"),
            Format: Nullable(artifact, "Format"),
            Architecture: Nullable(artifact, "Architecture"),
            Size: Long(artifact, "Size"),
            Hashes: Collection(artifact, "Hashes")
                .Select(hash => new WintainiumArtifactHashModel(Nullable(hash, "Algorithm"), Nullable(hash, "Value")))
                .ToArray());

    private static IReadOnlyList<WintainiumOperationDiagnostic> Diagnostics(PSObject source, string name) =>
        Collection(source, name)
            .Select(item => new WintainiumOperationDiagnostic(
                Nullable(item, "Code"), Nullable(item, "Path"), Nullable(item, "Message")))
            .ToArray();

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
            throw new InvalidOperationException($"Core release result is missing required property '{name}'.");
        return value;
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToString(source.Properties[name]!.Value);

    private static bool Boolean(PSObject source, string name) =>
        source.Properties[name]?.Value is not null && Convert.ToBoolean(source.Properties[name]!.Value);

    private static long? Long(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToInt64(source.Properties[name]!.Value);
}