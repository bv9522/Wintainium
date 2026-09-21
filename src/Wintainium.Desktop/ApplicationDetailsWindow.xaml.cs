using System.Collections.ObjectModel;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Wintainium.Desktop.Models;
using Windows.Graphics;

namespace Wintainium.Desktop;

public sealed partial class ApplicationDetailsWindow : Window
{
    private readonly WintainiumApplicationModel _application;
    private readonly WintainiumApplicationReleaseService _releaseService;
    private string _savedNotes = string.Empty;

    public ApplicationDetailsWindow(
        WintainiumApplicationModel application,
        WintainiumApplicationReleaseService releaseService)
    {
        ArgumentNullException.ThrowIfNull(application);
        ArgumentNullException.ThrowIfNull(releaseService);

        InitializeComponent();

        _application = application;
        _releaseService = releaseService;

        Title = $"{application.Name} — Wintainium";
        AppWindow.Resize(new SizeInt32(820, 760));

        PopulateApplicationFacts();
        ReleaseListView.ItemsSource = new ObservableCollection<WintainiumApplicationReleaseModel>();
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

        CheckForUpdatesButton.IsEnabled = false;
        DetailsErrorText.Visibility = Visibility.Collapsed;
        ReleaseStatusText.Text = "Checking the application's declared source…";

        try
        {
            var result = await _releaseService.DiscoverAsync(_application.ManifestPath);

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
        }
        catch (Exception exception)
        {
            ShowDetailsError($"Release discovery could not be completed.{Environment.NewLine}{exception.Message}");
            ReleaseStatusText.Text = "Release discovery failed.";
        }
        finally
        {
            CheckForUpdatesButton.IsEnabled = true;
        }
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

    private void ShowDetailsError(string message)
    {
        DetailsErrorText.Text = message;
        DetailsErrorText.Visibility = Visibility.Visible;
    }
}