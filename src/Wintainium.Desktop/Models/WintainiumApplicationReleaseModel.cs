namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationReleaseModel(
    string ReleaseId,
    string Version,
    string Channel,
    DateTimeOffset? PublishedAt,
    IReadOnlyList<WintainiumReleaseArtifactModel> Artifacts)
{
    public string ArtifactSummary =>
        Artifacts.Count == 0
            ? "No artifacts reported."
            : string.Join(
                " • ",
                Artifacts.Select(static artifact =>
                    string.Join(
                        " ",
                        new[]
                        {
                            artifact.FileName,
                            artifact.Format,
                            artifact.Architecture,
                            artifact.Size is null ? null : $"{artifact.Size:N0} bytes"
                        }.Where(static value => !string.IsNullOrWhiteSpace(value)))));
}

internal sealed record WintainiumReleaseArtifactModel(
    string? Uri,
    string? FileName,
    string? Format,
    string? Architecture,
    long? Size,
    IReadOnlyList<WintainiumArtifactHashModel> Hashes);

internal sealed record WintainiumArtifactHashModel(
    string? Algorithm,
    string? Value);