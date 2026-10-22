using System.Globalization;
using System.Text;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Produces a deterministic, single-application plain-text refresh report.
/// Context is allowlisted to avoid leaking raw registry subkeys or unrelated entries.
/// </summary>
internal static class WintainiumApplicationRefreshReportFormatter
{
    private static readonly HashSet<string> SafeContextNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "ApplicationId", "Capability", "CandidateCount", "Component", "ContentType", "DownloadArtifactCandidateCount",
        "DurationMilliseconds", "ErrorCode", "EventName", "ExceptionType", "EvidenceSource", "FailureStage",
        "FinalUrl", "Host", "HtmlLength", "HttpStatusCode", "InstallationState", "MatchMode",
        "ObservedInstallationState", "OperationId", "Outcome", "ParsedArtifactCount", "ParsedReleaseCount",
        "Persisted", "PriorInstallationState", "ProviderId", "ReasonCode", "RegistryLocationCount",
        "RegistryReadFailureCount", "RequestedUrl", "Scope", "SectionCandidateCount", "Severity", "Stage", "Status", "View"
    };

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
                AppendStageDiagnostics(builder, "Errors", stage.Errors, "  ");
                AppendStageDiagnostics(builder, "Warnings", stage.Warnings, "  ");
                AppendLogEvents(builder, stage.LogEvents, "  ");
            }
        }

        var firstAttention = stages.FirstOrDefault(IsFirstAttentionStage);
        builder.AppendLine();
        builder.AppendLine("First Failed or Uncertain Stage:");
        builder.AppendLine(firstAttention is null
            ? "- No failed stage or Unknown post-stage state was recorded."
            : $"- {FirstAttentionLabel(firstAttention)} (status: {firstAttention.Status}, reason: {Value(FirstAttentionReason(firstAttention))}, state after: {Value(firstAttention.StateAfter?.ToString())})");

        AppendStageDiagnostics(builder, "Aggregate Errors", result.Errors, string.Empty);
        AppendStageDiagnostics(builder, "Aggregate Warnings", result.Warnings, string.Empty);
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
            lines.AddRange(stage.Errors.Select(item => $"  ERROR: {FormatDiagnostic(item)}"));
            lines.AddRange(stage.Warnings.Select(item => $"  WARNING: {FormatDiagnostic(item)}"));
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
            .FirstOrDefault(context => string.Equals(context.Key, key, StringComparison.OrdinalIgnoreCase))
            .Value;

    private static void AppendStageDiagnostics(
        StringBuilder builder,
        string title,
        IReadOnlyList<WintainiumOperationDiagnostic> diagnostics,
        string indent)
    {
        if (diagnostics.Count == 0) return;
        builder.AppendLine($"{indent}{title}:");
        foreach (var diagnostic in diagnostics)
        {
            builder.AppendLine($"{indent}- {FormatDiagnostic(diagnostic)}");
            if (diagnostic.Details is null) continue;
            foreach (var detail in diagnostic.Details
                .Where(item => SafeContextNames.Contains(item.Key))
                .OrderBy(item => item.Key, StringComparer.OrdinalIgnoreCase))
                builder.AppendLine($"{indent}  {detail.Key}: {Value(detail.Value)}");
        }
    }

    private static void AppendLogEvents(StringBuilder builder, IReadOnlyList<WintainiumOperationLogEvent> events, string indent)
    {
        if (events.Count == 0) return;
        builder.AppendLine($"{indent}Log Events:");
        foreach (var item in events)
        {
            builder.AppendLine($"{indent}- [{Value(item.Severity)}] {Value(item.EventName)}: {Value(item.Message)}");
            builder.AppendLine($"{indent}  Operation ID: {Value(item.OperationId)}; Component: {Value(item.Component)}");
            foreach (var context in item.Context
                .Where(entry => SafeContextNames.Contains(entry.Key))
                .OrderBy(entry => entry.Key, StringComparer.OrdinalIgnoreCase))
                builder.AppendLine($"{indent}  {context.Key}: {Value(context.Value)}");
        }
    }

    private static string FormatDiagnostic(WintainiumOperationDiagnostic diagnostic)
    {
        var parts = new[] { diagnostic.Code, diagnostic.Message }
            .Where(part => !string.IsNullOrWhiteSpace(part))
            .Select(part => part!.Trim());
        var text = string.Join(": ", parts);
        return string.IsNullOrWhiteSpace(text) ? "Unspecified diagnostic." : text;
    }

    private static string FormatTimestamp(DateTimeOffset? value) =>
        value is null ? "unavailable" : value.Value.ToUniversalTime().ToString("O", CultureInfo.InvariantCulture);

    private static string Value(string? value) =>
        string.IsNullOrWhiteSpace(value) ? "unavailable" : value.Trim();
}
