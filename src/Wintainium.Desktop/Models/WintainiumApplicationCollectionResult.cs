namespace Wintainium.Desktop.Models;

/// <summary>
/// Presentation-layer result for loading the tracked application collection.
/// </summary>
internal sealed record WintainiumApplicationCollectionResult(
    string OperationId,
    bool IsSuccessful,
    IReadOnlyList<WintainiumApplicationModel> Applications,
    IReadOnlyList<WintainiumOperationDiagnostic> Errors,
    IReadOnlyList<WintainiumOperationDiagnostic> Warnings,
    WintainiumOperationState OperationState = WintainiumOperationState.NotStarted);

/// <summary>
/// Stable diagnostic data projected from a documented Core result.
/// </summary>
internal sealed record WintainiumOperationDiagnostic(
    string? Code,
    string? Path,
    string? Message);
