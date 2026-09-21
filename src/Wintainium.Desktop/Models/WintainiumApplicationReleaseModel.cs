namespace Wintainium.Desktop.Models;

internal sealed record WintainiumApplicationReleaseModel(
    string ReleaseId,
    string Version,
    string Channel,
    DateTimeOffset? PublishedAt,
    IReadOnlyList<WintainiumReleaseArtifactModel> Artifacts);

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