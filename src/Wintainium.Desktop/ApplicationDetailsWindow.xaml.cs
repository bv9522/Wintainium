using System.Collections.ObjectModel;
using System.Runtime.InteropServices;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Wintainium.Desktop.Models;
using Wintainium.Desktop.Settings;
using Windows.Graphics;

namespace Wintainium.Desktop;

public sealed partial class ApplicationDetailsWindow : Window
{
    private readonly WintainiumApplicationModel _application;
    private readonly WintainiumApplicationReleaseService _releaseService;
    private readonly WintainiumApplicationUpdateService _updateService;
    private string _savedNotes = string.Empty;
    private CancellationTokenSource? _operationCancellation;

    internal ApplicationDetailsWindow(
        WintainiumApplicationModel application,
        WintainiumApplicationReleaseService releaseService,
        WintainiumApplicationUpdateService updateService)
    {
        ArgumentNullException.ThrowIfNull(application);
        ArgumentNullException.ThrowIfNull(releaseService);
        ArgumentNullException.ThrowIfNull(updateService);

        InitializeComponent();
        Closed += ApplicationDetailsWindow_Closed;

        _application = application;
        _releaseService = releaseService;
        _updateService = updateService;

        Title = $"{application.Name} — Wintainium";
        AppWindow.Resize(new SizeInt32(820, 760));

        PopulateApplicationFacts();
        ReleaseListView.ItemsSource = new ObservableCollection<WintainiumApplicationReleaseModel>();
        ErrorItemsControl.ItemsSource = Array.Empty<string>();
        WarningItemsControl.ItemsSource = Array.Empty<string>();
    }

    private void PopulateApplicationFacts()
    {
        ApplicationNameText.Text = _application.Name;
        ApplicationPublisherText.Text = string.IsNullOrWhiteSpace(_application.Publisher)
            ? "Publisher unavailable"
            : _application.Publisher;

        ApplicationIdText.Text = $"Application ID: {_application.ApplicationId}";
        InstalledVersionText.Text = $"Installed version: {_application.InstalledVersion ?? "Unknown"}";
        InstallationStateText.Text = $"Installation state: {_application.InstallationState}";
        SourceText.Text = $"Source provider: {_application.SourceProviderId ?? "Unknown"}";

        if (Uri.TryCreate(_application.Homepage, UriKind.Absolute, out var homepage))
        {
            HomepageButton.NavigateUri = homepage;
            HomepageButton.IsEnabled = true;
        }
        else
        {
            HomepageButton.IsEnabled = false;
        }
    }

    private async void CheckForUpdatesButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_application.ManifestPath))
        {
            ShowDetailsError("The application's manifest path is not available, so release discovery cannot be requested.");
            return;
        }

        _operationCancellation?.Dispose();
        _operationCancellation = new CancellationTokenSource();
        CheckForUpdatesButton.IsEnabled = false;
        CancelOperationButton.IsEnabled = true;
        OperationStateText.Text = WintainiumOperationState.Running.ToString();
        OperationIdText.Text = "Operation ID: pending Core result.";
        OperationProgressRing.IsActive = true;
        DetailsErrorText.Visibility = Visibility.Collapsed;
        ReleaseStatusText.Text = "Checking the application's declared source…";

        try
        {
            var result = await _releaseService.DiscoverAsync(_application.ManifestPath, _operationCancellation.Token);

            OperationStateText.Text = result.OperationState.ToString();
            OperationIdText.Text = $"Operation ID: {result.OperationId}";
            ErrorItemsControl.ItemsSource = result.Errors.Select(FormatDiagnostic).ToArray();
            WarningItemsControl.ItemsSource = result.Warnings.Select(FormatDiagnostic).ToArray();

            if (!result.IsSuccessful)
            {
                ReleaseStatusText.Text = string.IsNullOrWhiteSpace(result.Status)
                    ? "Release discovery failed."
                    : $"Release discovery: {result.Status}.";
            }
            else
            {
                ReleaseStatusText.Text = result.Releases.Count switch
                {
                    0 => "No releases were reported by the application's source.",
                    1 => "1 release reported by the application's source.",
                    _ => $"{result.Releases.Count} releases reported by the application's source."
                };
            }

            var releases = (ObservableCollection<WintainiumApplicationReleaseModel>)ReleaseListView.ItemsSource!;
            releases.Clear();
            foreach (var release in result.Releases)
            {
                releases.Add(release);
            }

            if (result.Errors.Count > 0)
            {
                ShowDetailsError(string.Join(
                    Environment.NewLine,
                    result.Errors.Select(static error => error.Message ?? error.Code ?? "Unknown error.")));
            }
        }
        catch (OperationCanceledException)
        {
            ReleaseStatusText.Text = "Release discovery was cancelled.";
            OperationStateText.Text = WintainiumOperationState.Cancelled.ToString();
        }
        catch (Exception exception)
        {
            ShowDetailsError($"Release discovery could not be completed.{Environment.NewLine}{exception.Message}");
            ReleaseStatusText.Text = "Release discovery failed.";
        }
        finally
        {
            OperationProgressRing.IsActive = false;
            CancelOperationButton.IsEnabled = false;
            CheckForUpdatesButton.IsEnabled = true;
            _operationCancellation?.Dispose();
            _operationCancellation = null;
        }
    }

    private async void RunUpdateButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_application.ManifestPath))
        {
            ShowDetailsError("The application's manifest path is not available, so the update cannot be requested.");
            return;
        }

        _operationCancellation?.Dispose();
        _operationCancellation = new CancellationTokenSource();
        CheckForUpdatesButton.IsEnabled = false;
        RunUpdateButton.IsEnabled = false;
        CancelOperationButton.IsEnabled = true;
        OperationStateText.Text = WintainiumOperationState.Running.ToString();
        OperationIdText.Text = "Operation ID: pending Core result.";
        OperationProgressRing.IsActive = true;
        DetailsErrorText.Visibility = Visibility.Collapsed;
        ReleaseStatusText.Text = "Running the Core-owned update lifecycle…";

        try
        {
            Directory.CreateDirectory(WintainiumDesktopPaths.InstalledStateRoot);
            Directory.CreateDirectory(WintainiumDesktop.Settings.WintainiumDesktopPaths.DownloadRoot);

            var machineArchitecture = RuntimeInformation.OSArchitecture switch
            {
                Architecture.X64 => "x64",
                Architecture.X86 => "x86",
                Architecture.Arm64 => "arm64",
                _ => RuntimeInformation.OSArchitecture.ToString()
            };

            var result = await _updateService.ExecuteAsync(
                _application.ManifestPath,
                WintainiumDesktop.Settings.WintainiumDesktopPaths.InstalledStateRoot,
                machineArchitecture,
                WintainiumDesktop.Settings.WintainiumDesktopPaths.DownloadRoot,
                cancellationToken: _operationCancellation.Token);

            OperationStateText.Text = result.OperationState.ToString();
            OperationIdText.Text = $"Operation ID: {result.OperationId ?? "unavailable"}";
            ErrorItemsControl.ItemsSource = result.Errors.Select(FormatDiagnostic).ToArray();
            WarningItemsControl.ItemsSource = result.Warnings.Select(FormatDiagnostic).ToArray();

            var completedStages = result.Stages.Count(stage => stage.IsSuccessful);
            ReleaseStatusText.Text = result.Status switch
            {
                "Completed" => $"Update completed. {completedStages} lifecycle stage(s) reported successful.",
                "Cancelled" => "Update was cancelled.",
                "Failed" => "Update failed.",
                _ => $"Update: {result.Status ?? "Unknown"}."
            };

            if (result.Errors.Count > 0)
            {
                ShowDetailsError(string.Join(
                    Environment.NewLine,
                    result.Errors.Select(static error => error.Message ?? error.Code ?? "Unknown error.")));
            }
        }
        catch (OperationCanceledException)
        {
            ReleaseStatusText.Text = "Update was cancelled.";
            OperationStateText.Text = WintainiumOperationState.Cancelled.ToString();
        }
        catch (Exception exception)
        {
            ShowDetailsError($"Update could not be completed.{Environment.NewLine}{exception.Message}");
            ReleaseStatusText.Text = "Update failed.";
        }
        finally
        {
            OperationProgressRing.IsActive = false;
            CancelOperationButton.IsEnabled = false;
            CheckForUpdatesButton.IsEnabled = true;
            RunUpdateButton.IsEnabled = true;
            _operationCancellation?.Dispose();
            _operationCancellation = null;
        }
    }

    private void CancelOperationButton_Click(object sender, RoutedEventArgs e)
    {
        _operationCancellation?.Cancel();
    }

    private void ApplicationDetailsWindow_Closed(object sender, WindowEventArgs args)
    {
        _operationCancellation?.Cancel();
        _operationCancellation?.Dispose();
        _operationCancellation = null;
    }

    private void SaveNotesButton_Click(object sender, RoutedEventArgs e)
    {
        _savedNotes = NotesTextBox.Text;
        NotesStatusText.Text = "Notes saved for this application session.";
    }

    private void DontSaveButton_Click(object sender, RoutedEventArgs e)
    {
        NotesTextBox.Text = _savedNotes;
        NotesStatusText.Text = "Unsaved note changes discarded.";
    }

    private static string FormatDiagnostic(WintainiumOperationDiagnostic diagnostic) =>
        string.IsNullOrWhiteSpace(diagnostic.Message)
            ? diagnostic.Code ?? "Unspecified diagnostic."
            : string.IsNullOrWhiteSpace(diagnostic.Code)
                ? diagnostic.Message
                : $"{diagnostic.Code}: {diagnostic.Message}";

    private void ShowDetailsError(string message)
    {
        DetailsErrorText.Text = message;
        DetailsErrorText.Visibility = Visibility.Visible;
    }
}