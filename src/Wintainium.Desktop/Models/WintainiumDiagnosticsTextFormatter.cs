using System.Text.Json;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Formats structured diagnostics for people without flattening event context into
/// opaque, scriptio-continua message strings.
/// </summary>
internal static class WintainiumDiagnosticsTextFormatter
{
    private static readonly HashSet<string> SafeContextNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "ApplicationId", "Capability", "CandidateCount", "Component", "ContentType",
        "DownloadArtifactCandidateCount", "DurationMilliseconds", "ErrorCode", "EventName",
        "ExceptionType", "EvidenceSource", "FailureStage", "FinalUrl", "Host", "HtmlLength",
        "HttpStatusCode", "InstallationState", "MatchMode", "ObservedInstallationState",
        "OperationId", "Outcome", "ParsedArtifactCount", "ParsedReleaseCount", "Persisted",
        "PriorInstallationState", "ProviderId", "ReasonCode", "RegistryLocationCount",
        "RegistryReadFailureCount", "RequestedUrl", "Scope", "SectionCandidateCount",
        "Severity", "Stage", "Status", "View", "DecisionReasonCode", "DecisionStatus",
        "InstalledVersion", "InstalledVersionSource", "ManifestChannelPolicy",
        "ReleaseObservations", "TargetObservations", "AttemptedCount", "ResolvedCount",
        "RejectedCount", "UnavailableCount", "ArtifactEndpointAttemptedCount",
        "ArtifactEndpointResolvedCount", "ArtifactEndpointRejectedCount",
        "ArtifactEndpointUnavailableCount", "ArtifactEndpointErrorType"
    };

    private static readonly JsonSerializerOptions IndentedJson = new() { WriteIndented = true };

    public static IReadOnlyList<WintainiumOperationDiagnostic> DistinctDiagnostics(
        IEnumerable<WintainiumOperationDiagnostic> diagnostics)
    {
        ArgumentNullException.ThrowIfNull(diagnostics);
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var result = new List<WintainiumOperationDiagnostic>();
        foreach (var diagnostic in diagnostics)
        {
            if (diagnostic is null)
                continue;

            var key = DiagnosticKey(diagnostic);
            if (seen.Add(key))
                result.Add(diagnostic);
        }

        return result;
    }

    public static bool ContainsDiagnostic(
        IEnumerable<WintainiumOperationDiagnostic> diagnostics,
        WintainiumOperationDiagnostic candidate)
    {
        ArgumentNullException.ThrowIfNull(diagnostics);
        ArgumentNullException.ThrowIfNull(candidate);
        var key = DiagnosticKey(candidate);
        return diagnostics.Any(item => item is not null && string.Equals(DiagnosticKey(item), key, StringComparison.Ordinal));
    }

    private static string DiagnosticKey(WintainiumOperationDiagnostic diagnostic)
    {
        var builder = new System.Text.StringBuilder();
        builder.Append(diagnostic.Code).Append('\0')
            .Append(diagnostic.Path).Append('\0')
            .Append(diagnostic.Message);
        if (diagnostic.Details is not null)
        {
            foreach (var detail in diagnostic.Details.OrderBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase))
                builder.Append('\0').Append(detail.Key).Append('=').Append(detail.Value);
        }
        return builder.ToString();
    }

    public static string FormatDiagnostic(WintainiumOperationDiagnostic diagnostic, string indent = "")
    {
        ArgumentNullException.ThrowIfNull(diagnostic);
        var parts = new List<string>();
        if (!string.IsNullOrWhiteSpace(diagnostic.Code))
            parts.Add(diagnostic.Code.Trim());
        if (!string.IsNullOrWhiteSpace(diagnostic.Path))
            parts.Add($"Path: {diagnostic.Path.Trim()}");
        if (!string.IsNullOrWhiteSpace(diagnostic.Message))
            parts.Add(diagnostic.Message.Trim());

        var builder = new System.Text.StringBuilder();
        builder.Append(indent);
        builder.AppendLine(parts.Count == 0 ? "Unspecified diagnostic." : string.Join(": ", parts));

        if (diagnostic.Details is not { Count: > 0 } details)
            return builder.ToString().TrimEnd();

        foreach (var detail in details
            .Where(pair => SafeContextNames.Contains(pair.Key) && !string.IsNullOrWhiteSpace(pair.Value))
            .OrderBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase))
        {
            builder.Append(indent).Append("  ").Append(detail.Key).AppendLine(":");
            AppendFormattedValue(builder, detail.Value!, indent + "    ");
        }

        return builder.ToString().TrimEnd();
    }

    public static void AppendLogEvents(
        System.Text.StringBuilder builder,
        string title,
        IEnumerable<WintainiumOperationLogEvent>? events,
        string indent = "")
    {
        ArgumentNullException.ThrowIfNull(builder);
        var items = events?.ToArray() ?? [];
        if (items.Length == 0)
            return;

        builder.Append(indent).AppendLine(title + ":");
        foreach (var item in items)
        {
            var heading = string.Join(" — ", new[] { item.EventName, item.Message }
                .Where(value => !string.IsNullOrWhiteSpace(value))
                .Select(value => value!.Trim()));
            builder.Append(indent).Append("  - [")
                .Append(string.IsNullOrWhiteSpace(item.Severity) ? "Unspecified" : item.Severity)
                .Append("] ").AppendLine(string.IsNullOrWhiteSpace(heading) ? "Log event" : heading);

            if (!string.IsNullOrWhiteSpace(item.Component))
                builder.Append(indent).Append("      Component: ").AppendLine(item.Component);
            if (!string.IsNullOrWhiteSpace(item.OperationId))
                builder.Append(indent).Append("      Operation ID: ").AppendLine(item.OperationId);
            if (item.Timestamp is DateTimeOffset timestamp)
                builder.Append(indent).Append("      Timestamp (UTC): ").AppendLine(timestamp.ToUniversalTime().ToString("O"));

            foreach (var context in item.Context
                .Where(pair => SafeContextNames.Contains(pair.Key) && !string.IsNullOrWhiteSpace(pair.Value))
                .OrderBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase))
            {
                builder.Append(indent).Append("      ").Append(context.Key).AppendLine(":");
                AppendFormattedValue(builder, context.Value!, indent + "        ");
            }
        }
    }

    private static void AppendFormattedValue(System.Text.StringBuilder builder, string value, string indent)
    {
        try
        {
            using var document = JsonDocument.Parse(value);
            var formatted = JsonSerializer.Serialize(document.RootElement, IndentedJson);
            foreach (var line in formatted.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None))
                builder.Append(indent).AppendLine(line);
            return;
        }
        catch (JsonException)
        {
            // Scalar context values are already safe, normalized strings.
        }

        builder.Append(indent).AppendLine(value);
    }
}
