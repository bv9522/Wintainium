using System.Globalization;
using System.Text;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Produces a deterministic, single-application plain-text refresh report.
/// Stage results are the primary diagnostic location; aggregate collections contribute
/// only diagnostics not already represented by a stage.
/// </summary>
internal static class WintainiumApplicationRefreshReportFormatter
{
    public static string Format(WintainiumApplicationRefreshResult result)
    {
        ArgumentNullException.ThrowIfNull(result);
        var builder = new StringBuilder();
        var app = result.Application;

        builder.AppendLine("Wintainium Installed-State Refresh Report");
        builder.AppendLine($"Captured (UTC): {FormatTimestamp(result.CapturedAtUtc)}");
        builder.AppendLine($"Application: {app.DisplayName}");
        builder.AppendLine($"Application ID: {app.ApplicationId}");
        if (!string.IsNullOrWhiteSpace(app.ManifestPath))
            builder.AppendLine($"Manifest: {app.ManifestPath}");
        builder.AppendLine($"Refresh Operation ID: {Value(result.OperationId)}");
        builder.AppendLine($"Final Installation State: {app.InstallationState}");
        builder.AppendLine($"Final Update Status: {app.UpdateStatusText}");

        var stages = result.Stages ?? [];
        builder.AppendLine();
        builder.AppendLine("Stages:");
        if (stages.Count == 0)
        {
            builder.AppendLine("- No stage results were recorded.");
        }
        else
        {
            foreach (var stage in stages)
            {
                builder.AppendLine($"- {stage.Name}: {stage.Status}");
                builder.AppendLine($"  Operation ID: {Value(stage.OperationId)}");
                builder.AppendLine($"  Reason Code: {Value(stage.ReasonCode)}");
                builder.AppendLine($"  Installation State: {Value(stage.StateBefore?.ToString())} -> {Value(stage.StateAfter?.ToString())}");
                AppendStageDiagnostics(builder, "Errors", WintainiumDiagnosticsTextFormatter.DistinctDiagnostics(stage.Errors), "  ");
                AppendStageDiagnostics(builder, "Warnings", WintainiumDiagnosticsTextFormatter.DistinctDiagnostics(stage.Warnings), "  ");
                WintainiumDiagnosticsTextFormatter.AppendLogEvents(builder, "Log Events", stage.LogEvents, "  ");
            }
        }

        var firstAttention = stages.FirstOrDefault(IsFirstAttentionStage);
        builder.AppendLine();
        builder.AppendLine("First Failed or Uncertain Stage:");
        builder.AppendLine(firstAttention is null
            ? "- No failed stage or Unknown post-stage state was recorded."
            : $"- {FirstAttentionLabel(firstAttention)} (status: {firstAttention.Status}, reason: {Value(FirstAttentionReason(firstAttention))}, state after: {Value(firstAttention.StateAfter?.ToString())})");

        var stageErrors = stages.SelectMany(stage => stage.Errors).ToArray();
        var stageWarnings = stages.SelectMany(stage => stage.Warnings).ToArray();
        var additionalErrors = WintainiumDiagnosticsTextFormatter.DistinctDiagnostics(result.Errors)
            .Where(item => !WintainiumDiagnosticsTextFormatter.ContainsDiagnostic(stageErrors, item))
            .ToArray();
        var additionalWarnings = WintainiumDiagnosticsTextFormatter.DistinctDiagnostics(result.Warnings)
            .Where(item => !WintainiumDiagnosticsTextFormatter.ContainsDiagnostic(stageWarnings, item))
            .ToArray();

        AppendStageDiagnostics(builder, "Additional Errors", additionalErrors, string.Empty);
        AppendStageDiagnostics(builder, "Additional Warnings", additionalWarnings, string.Empty);
        return builder.ToString().TrimEnd();
    }

    public static IReadOnlyList<string> FormatSummaryLines(WintainiumApplicationRefreshResult result)
    {
        ArgumentNullException.ThrowIfNull(result);
        var lines = new List<string>
        {
            $"Captured: {FormatTimestamp(result.CapturedAtUtc)}",
            $"Final state: {result.Application.InstallationState}",
            $"Refresh operation: {Value(result.OperationId)}"
        };

        foreach (var stage in result.Stages ?? [])
        {
            lines.Add($"{stage.Name}: {stage.Status}; state {Value(stage.StateBefore?.ToString())} -> {Value(stage.StateAfter?.ToString())}; reason {Value(stage.ReasonCode)}");
            lines.AddRange(WintainiumDiagnosticsTextFormatter.DistinctDiagnostics(stage.Errors)
                .Select(item => "  ERROR: " + WintainiumDiagnosticsTextFormatter.FormatDiagnostic(item)));
            lines.AddRange(WintainiumDiagnosticsTextFormatter.DistinctDiagnostics(stage.Warnings)
                .Select(item => "  WARNING: " + WintainiumDiagnosticsTextFormatter.FormatDiagnostic(item)));
        }

        return lines;
    }

    private static bool IsFirstAttentionStage(WintainiumApplicationRefreshStage stage) =>
        stage.Status.Contains("Failed", StringComparison.OrdinalIgnoreCase) ||
        stage.Status.Contains("Error", StringComparison.OrdinalIgnoreCase) ||
        stage.Status.Contains("Cancelled", StringComparison.OrdinalIgnoreCase) ||
        stage.Errors.Count > 0 ||
        stage.StateAfter == WintainiumInstallationState.Unknown ||
        (stage.ReasonCode?.Contains("Unknown", StringComparison.OrdinalIgnoreCase) ?? false) ||
        (stage.ReasonCode?.Contains("EvidenceUnavailable", StringComparison.OrdinalIgnoreCase) ?? false) ||
        HasNoReleasesFound(stage);

    private static bool HasNoReleasesFound(WintainiumApplicationRefreshStage stage) =>
        stage.LogEvents.Any(item =>
            string.Equals(item.EventName, "ProviderOperationCompleted", StringComparison.OrdinalIgnoreCase) &&
            (item.Context.Any(context =>
                 context.Key.Equals("Status", StringComparison.OrdinalIgnoreCase) &&
                 string.Equals(context.Value, "NoReleasesFound", StringComparison.OrdinalIgnoreCase)) ||
             (item.Message?.Contains("NoReleasesFound", StringComparison.OrdinalIgnoreCase) ?? false)));

    private static string FirstAttentionLabel(WintainiumApplicationRefreshStage stage) =>
        HasNoReleasesFound(stage)
            ? $"ReleaseDiscovery (provider result surfaced during {stage.Name})"
            : stage.Name;

    private static string? FirstAttentionReason(WintainiumApplicationRefreshStage stage)
    {
        if (!HasNoReleasesFound(stage))
            return stage.ReasonCode;

        var outcome = LogContextValue(stage, "Outcome");
        var sections = LogContextValue(stage, "SectionCandidateCount");
        var links = LogContextValue(stage, "DownloadArtifactCandidateCount");
        var details = new List<string> { "provider returned NoReleasesFound" };
        if (!string.IsNullOrWhiteSpace(outcome)) details.Add($"parser outcome {outcome}");
        if (!string.IsNullOrWhiteSpace(sections)) details.Add($"release-section candidates {sections}");
        if (!string.IsNullOrWhiteSpace(links)) details.Add($"download-artifact candidates {links}");
        return string.Join("; ", details);
    }

    private static string? LogContextValue(WintainiumApplicationRefreshStage stage, string key) =>
        stage.LogEvents
            .Where(item => string.Equals(item.EventName, "ReleaseDiscoveryParsingCompleted", StringComparison.OrdinalIgnoreCase))
            .SelectMany(item => item.Context)
            .Where(context => string.Equals(context.Key, key, StringComparison.OrdinalIgnoreCase))
            .Select(context => context.Value)
            .FirstOrDefault();

    private static void AppendStageDiagnostics(
        StringBuilder builder,
        string title,
        IReadOnlyList<WintainiumOperationDiagnostic> diagnostics,
        string indent)
    {
        if (diagnostics.Count == 0) return;
        builder.AppendLine($"{indent}{title}:");
        foreach (var diagnostic in diagnostics)
            builder.AppendLine(WintainiumDiagnosticsTextFormatter.FormatDiagnostic(diagnostic, indent + "- "));
    }

    private static string FormatTimestamp(DateTimeOffset? value) =>
        value is null ? "unavailable" : value.Value.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture);

    private static string Value(string? value) =>
        string.IsNullOrWhiteSpace(value) ? "unavailable" : value.Trim();
}
