using System.Collections;
using System.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Wintainium.Desktop.Models;
using Windows.ApplicationModel.DataTransfer;

namespace Wintainium.Desktop;

public sealed partial class ApplicationDetailsWindow
{
    private void DiagnosticItemsControl_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is ItemsControl itemsControl)
        {
            itemsControl.SizeChanged -= DiagnosticItemsControl_SizeChanged;
            itemsControl.SizeChanged += DiagnosticItemsControl_SizeChanged;
            UpdateDiagnosticSectionVisibility(itemsControl);
        }
    }

    private void DiagnosticItemsControl_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        if (sender is ItemsControl itemsControl)
            UpdateDiagnosticSectionVisibility(itemsControl);
    }

    private void UpdateDiagnosticSectionVisibility(ItemsControl itemsControl)
    {
        var hasItems = itemsControl.Items.Count > 0;

        if (itemsControl == ErrorItemsControl)
            ErrorsHeaderText.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        else if (itemsControl == WarningItemsControl)
            WarningsHeaderText.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        else if (itemsControl == TroubleshootingDiagnosticsItemsControl)
            TroubleshootingDiagnosticsCard.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;
        else if (itemsControl == RefreshDiagnosticsItemsControl)
            RefreshDiagnosticsCard.Visibility = hasItems ? Visibility.Visible : Visibility.Collapsed;

        CopyDiagnosticsButton.IsEnabled = HasDiagnosticContent();
    }

    internal void ApplyDashboardRefreshResult(WintainiumApplicationRefreshResult result)
    {
        ArgumentNullException.ThrowIfNull(result);

        if (!string.Equals(
            result.Application.ApplicationId,
            _application.ApplicationId,
            StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        _application = result.Application;
        PopulateApplicationFacts();
        UpdateRefreshDiagnosticsPresentation();
    }

    internal void ApplySourceResolutionDiagnostics()
    {
        UpdateSourceResolutionDiagnosticsPresentation();
    }

    private void UpdateSourceResolutionDiagnosticsPresentation()
    {
        var report = WintainiumDesktopDiagnosticsStore.GetSourceResolutionReport(_application.ApplicationId);
        SourceResolutionDiagnosticsText.Text = report ?? string.Empty;
        SourceResolutionDiagnosticsCard.Visibility = string.IsNullOrWhiteSpace(report)
            ? Visibility.Collapsed
            : Visibility.Visible;
        CopyDiagnosticsButton.IsEnabled = HasDiagnosticContent();
    }

    private void UpdateRefreshDiagnosticsPresentation()
    {
        var result = WintainiumDesktopDiagnosticsStore.GetRefreshResult(_application.ApplicationId);
        var lines = result is null
            ? Array.Empty<string>()
            : WintainiumApplicationRefreshReportFormatter.FormatSummaryLines(result).ToArray();

        RefreshDiagnosticsItemsControl.ItemsSource = lines;
        RefreshDiagnosticsCard.Visibility = lines.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
        InstalledStateRefreshStatusText.Text = result is null
            ? "The dashboard installed-state refresh has not completed yet."
            : $"Dashboard refresh completed. Final installed state: {result.Application.InstallationState}.";
        CopyDiagnosticsButton.IsEnabled = HasDiagnosticContent();
    }

    private void UpdateResultDiagnosticsPresentation()
    {
        if (_lastUpdateResult is null)
            return;

        TroubleshootingDiagnosticsItemsControl.ItemsSource =
            _lastUpdateResult.TroubleshootingDiagnostics
                .Select(FormatTroubleshootingDiagnostic)
                .ToArray();

        UpdateDiagnosticSectionVisibility(TroubleshootingDiagnosticsItemsControl);
        CopyDiagnosticsButton.IsEnabled = HasDiagnosticContent();
    }

    private async void CopyDiagnosticsButton_Click(object sender, RoutedEventArgs e)
    {
        var diagnostics = BuildDiagnosticsClipboardText();
        if (string.IsNullOrWhiteSpace(diagnostics))
            return;

        var package = new DataPackage();
        package.SetText(diagnostics);
        Clipboard.SetContent(package);

        CopyDiagnosticsButton.Content = "Diagnostics Copied";
        await Task.Delay(1400);
        CopyDiagnosticsButton.Content = "Copy Diagnostics";
    }

    private bool HasDiagnosticContent()
    {
        return OperationStateText.Text != "Not started." ||
               ErrorItemsControl.Items.Count > 0 ||
               WarningItemsControl.Items.Count > 0 ||
               TroubleshootingDiagnosticsItemsControl.Items.Count > 0 ||
               RefreshDiagnosticsItemsControl.Items.Count > 0 ||
               WintainiumDesktopDiagnosticsStore.GetRefreshResult(_application.ApplicationId) is not null ||
               WintainiumDesktopDiagnosticsStore.GetSourceResolutionReport(_application.ApplicationId) is not null ||
               StageItemsControl.Items.Count > 0;
    }

    private string BuildDiagnosticsClipboardText()
    {
        var builder = new StringBuilder();
        builder.AppendLine("Wintainium Diagnostics");
        builder.AppendLine($"Application: {ApplicationNameText.Text}");
        builder.AppendLine($"Application ID: {ApplicationIdText.Text}");
        builder.AppendLine($"Operation State: {OperationStateText.Text}");
        builder.AppendLine($"Operation Status: {UpdateResultStatusText.Text}");

        var operationId = OperationIdText.Text?.Replace("Operation ID:", string.Empty, StringComparison.OrdinalIgnoreCase).Trim();
        if (!string.IsNullOrWhiteSpace(operationId) && !operationId.Equals("pending Core result.", StringComparison.OrdinalIgnoreCase))
            builder.AppendLine($"Operation ID: {operationId}");

        AppendItems(builder, "Lifecycle", StageItemsControl.Items);
        AppendItems(builder, "Errors", ErrorItemsControl.Items);
        AppendItems(builder, "Warnings", WarningItemsControl.Items);
        AppendItems(builder, "Troubleshooting", TroubleshootingDiagnosticsItemsControl.Items);

        var sourceResolutionReport = WintainiumDesktopDiagnosticsStore.GetSourceResolutionReport(_application.ApplicationId);
        if (!string.IsNullOrWhiteSpace(sourceResolutionReport))
        {
            builder.AppendLine();
            builder.AppendLine(sourceResolutionReport);
        }

        var refreshResult = WintainiumDesktopDiagnosticsStore.GetRefreshResult(_application.ApplicationId);
        if (refreshResult is not null)
        {
            builder.AppendLine();
            builder.AppendLine(WintainiumApplicationRefreshReportFormatter.Format(refreshResult));
        }

        var updateLogs = WintainiumDesktopDiagnosticsStore.LastUpdateResult?.LogEvents;
        if (updateLogs is not null)
            AppendDiagnostics(builder, "Update Log Events", updateLogs);

        var installLogs = WintainiumDesktopDiagnosticsStore.LastInstallResult?.LogEvents;
        if (installLogs is not null)
            AppendDiagnostics(builder, "Install Log Events", installLogs);

        builder.AppendLine();
        builder.AppendLine($"Installed State: {InstalledStateRefreshStatusText.Text}");
        return builder.ToString().TrimEnd();
    }

    private static void AppendItems(StringBuilder builder, string title, IEnumerable items)
    {
        var values = items.Cast<object?>()
            .Select(static item => item?.ToString())
            .Where(static value => !string.IsNullOrWhiteSpace(value))
            .ToArray();

        if (values.Length == 0)
            return;

        builder.AppendLine();
        builder.AppendLine(title + ":");
        foreach (var value in values)
            builder.AppendLine($"- {value}");
    }

    private static void AppendDiagnostics(
        StringBuilder builder,
        string title,
        IEnumerable<WintainiumOperationDiagnostic> diagnostics)
    {
        var values = diagnostics.Select(FormatTroubleshootingDiagnostic)
            .Where(static value => !string.IsNullOrWhiteSpace(value))
            .ToArray();

        if (values.Length == 0)
            return;

        builder.AppendLine();
        builder.AppendLine(title + ":");
        foreach (var value in values)
            builder.AppendLine($"- {value}");
    }

    private static string FormatTroubleshootingDiagnostic(WintainiumOperationDiagnostic diagnostic)
    {
        var message = diagnostic.Message?.Trim();
        var code = diagnostic.Code?.Trim();
        var path = diagnostic.Path?.Trim();

        var parts = new List<string>();
        if (!string.IsNullOrWhiteSpace(code))
            parts.Add(code);
        if (!string.IsNullOrWhiteSpace(message))
            parts.Add(message);
        if (IsUsefulDiagnosticPath(path))
            parts.Add($"Path: {path}");

        if (diagnostic.Details.Count > 0)
        {
            var context = diagnostic.Details
                .Where(static pair => !string.IsNullOrWhiteSpace(pair.Value))
                .OrderBy(static pair => pair.Key, StringComparer.OrdinalIgnoreCase)
                .Select(static pair => $"{pair.Key}={pair.Value}")
                .ToArray();
            if (context.Length > 0)
                parts.Add("Context: " + string.Join("; ", context));
        }

        return parts.Count == 0 ? "Unspecified diagnostic." : string.Join(": ", parts.Take(2)) +
            (parts.Count > 2 ? $" ({string.Join(" | ", parts.Skip(2))})" : string.Empty);
    }

    private static bool IsUsefulDiagnosticPath(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return false;

        return path.Contains("\\Downloads\\", StringComparison.OrdinalIgnoreCase) ||
               path.Contains("\\Applications\\", StringComparison.OrdinalIgnoreCase) ||
               path.EndsWith(".json", StringComparison.OrdinalIgnoreCase) ||
               path.EndsWith(".msi", StringComparison.OrdinalIgnoreCase) ||
               path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) ||
               path.EndsWith(".zip", StringComparison.OrdinalIgnoreCase) ||
               path.EndsWith(".ps1", StringComparison.OrdinalIgnoreCase);
    }
}