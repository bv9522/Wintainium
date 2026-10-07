using System.Collections.ObjectModel;
using System.Runtime.InteropServices;
using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Wintainium.Desktop.Models;
using Wintainium.Desktop.Settings;
using Windows.Graphics;
using Windows.Storage.Pickers;
using WinRT.Interop;

namespace Wintainium.Desktop;

public sealed partial class ApplicationDetailsWindow : Window
{
    private WintainiumApplicationModel _application;
    private readonly WintainiumApplicationReleaseService _releaseService;
    private readonly WintainiumApplicationUpdateService _updateService;
    private readonly WintainiumApplicationInstallService _installService;
    private readonly WintainiumApplicationUpdateDecisionService _updateDecisionService;
    private readonly WintainiumApplicationInstalledStateService _installedStateService;
    private readonly WintainiumApplicationIconService _iconService;
    private readonly Func<Task>? _onAuthoritativeStateChanged;
    private readonly Func<string, Task>? _onApplicationOperationStarted;
    private readonly Func<string, Task>? _onApplicationOperationCompleted;
    private WintainiumApplicationUpdateResult? _lastUpdateResult;
    private string _savedNotes = string.Empty;
    private CancellationTokenSource? _operationCancellation;
    private bool _applicationOperationRegistered;

    internal ApplicationDetailsWindow(
        WintainiumApplicationModel application,
        WintainiumApplicationReleaseService releaseService,
        WintainiumApplicationUpdateService updateService,
        WintainiumApplicationInstallService installService,
        WintainiumApplicationUpdateDecisionService updateDecisionService,
        WintainiumApplicationInstalledStateService installedStateService,
        WintainiumApplicationIconService iconService,
        Func<Task>? onAuthoritativeStateChanged = null,
        Func<string, Task>? onApplicationOperationStarted = null,
        Func<string, Task>? onApplicationOperationCompleted = null)
    {
        ArgumentNullException.ThrowIfNull(application);
        ArgumentNullException.ThrowIfNull(releaseService);
        ArgumentNullException.ThrowIfNull(updateService);
        ArgumentNullException.ThrowIfNull(installService);
        ArgumentNullException.ThrowIfNull(updateDecisionService);
        ArgumentNullException.ThrowIfNull(installedStateService);
        ArgumentNullException.ThrowIfNull(iconService);

        InitializeComponent();
        App.TrackWindow(this);
        Closed += ApplicationDetailsWindow_Closed;

        _application = application;
        _releaseService = releaseService;
        _updateService = updateService;
        _installService = installService;
        _updateDecisionService = updateDecisionService;
        _installedStateService = installedStateService;
        _iconService = iconService;
        _onAuthoritativeStateChanged = onAuthoritativeStateChanged;
        _onApplicationOperationStarted = onApplicationOperationStarted;
        _onApplicationOperationCompleted = onApplicationOperationCompleted;

        Title = $"{application.DisplayName} — Application Details";
        AppWindow.Resize(new SizeInt32(820, 760));

        PopulateApplicationFacts();
        UpdateIconPresentation();
        ReleaseListView.ItemsSource = new ObservableCollection<WintainiumApplicationReleaseModel>();
        ErrorItemsControl.ItemsSource = Array.Empty<string>();
        WarningItemsControl.ItemsSource = Array.Empty<string>();
        StageItemsControl.ItemsSource = Array.Empty<string>();
    }

    private void PopulateApplicationFacts()
    {
        ApplicationNameText.Text = _application.DisplayName;
        ApplicationIdText.Text = _application.ApplicationId;
        InstalledVersionText.Text = _application.InstalledVersion ?? "Unknown";
        InstallationStateText.Text = _application.InstallationStateText;
        UpdateStatusText.Text = _application.UpdateStatusText;
        SourceText.Text = _application.SourceProviderText;
        UpdateActionButtons();

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

    private void UpdateActionButtons()
    {
        var isRunning = _operationCancellation is not null;
        var isInstalled = _application.InstallationState == WintainiumInstallationState.Installed;
        var isNotInstalled = _application.InstallationState == WintainiumInstallationState.NotInstalled;

        InstallButton.Visibility = isNotInstalled ? Visibility.Visible : Visibility.Collapsed;
        CheckForUpdatesButton.Visibility = isInstalled ? Visibility.Visible : Visibility.Collapsed;
        RunUpdateButton.Visibility = isInstalled ? Visibility.Visible : Visibility.Collapsed;

        InstallButton.IsEnabled = isNotInstalled && !isRunning;
        CheckForUpdatesButton.IsEnabled = isInstalled && !isRunning;
        RunUpdateButton.IsEnabled = isInstalled && !isRunning;
    }

    private async void ChooseIconButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_application.ManifestPath))
        {
            ShowDetailsError("The application's manifest path is not available, so the icon override cannot be saved.");
            return;
        }

        var picker = new FileOpenPicker();
        picker.FileTypeFilter.Add(".ico");
        picker.FileTypeFilter.Add(".png");
        picker.FileTypeFilter.Add(".jpg");
        picker.FileTypeFilter.Add(".jpeg");
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(this));

        var file = await picker.PickSingleFileAsync();
        if (file is null)
            return;

        await SetIconOverrideAsync(new Uri(file.Path).AbsoluteUri);
    }

    private async void UseIconUrlButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_application.ManifestPath))
        {
            ShowDetailsError("The application's manifest path is not available, so the icon override cannot be saved.");
            return;
        }

        var textBox = new TextBox
        {
            Header = "Icon URL",
            PlaceholderText = "https://example.com/icon.png",
            TextWrapping = TextWrapping.Wrap
        };

        var dialog = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = "Use Icon URL",
            Content = textBox,
            PrimaryButtonText = "Use Icon",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary
        };

        if (await dialog.ShowAsync() != ContentDialogResult.Primary)
            return;

        if (!Uri.TryCreate(textBox.Text.Trim(), UriKind.Absolute, out var uri) ||
            (uri.Scheme != Uri.UriSchemeHttp && uri.Scheme != Uri.UriSchemeHttps))
        {
            ShowDetailsError("Enter a valid HTTP or HTTPS icon URL.");
            return;
        }

        await SetIconOverrideAsync(uri.AbsoluteUri);
    }

    private async void ResetIconButton_Click(object sender, RoutedEventArgs e)
    {
        await SetIconOverrideAsync(null);
    }

    private async Task SetIconOverrideAsync(string? iconUri)
    {
        if (string.IsNullOrWhiteSpace(_application.ManifestPath))
            return;

        try
        {
            ResetIconButton.IsEnabled = false;
            ApplicationIconStatusText.Text = iconUri is null
                ? "Removing custom icon…"
                : "Saving selected icon…";

            var result = await _iconService.SetOverrideAsync(
                _application.ManifestPath,
                iconUri,
                CancellationToken.None);

            if (!result.IsSuccessful)
            {
                ShowDetailsError(result.Errors.Count == 0
                    ? "The icon override could not be saved."
                    : string.Join(Environment.NewLine, result.Errors.Select(FormatDiagnostic)));
                return;
            }

            _application = _application with
            {
                IconUri = iconUri ?? _application.AutomaticIconUri,
                IconSource = iconUri is null
                    ? (string.IsNullOrWhiteSpace(_application.AutomaticIconUri)
                        ? WintainiumIconSource.None
                        : WintainiumIconSource.WintainiumSourced)
                    : WintainiumIconSource.Custom
            };
            UpdateIconPresentation();

            if (_onAuthoritativeStateChanged is not null)
                await _onAuthoritativeStateChanged();

            ApplicationIconStatusText.Text = _application.IconSourceText;
        }
        catch (Exception exception)
        {
            ShowDetailsError($"The application icon could not be updated.{Environment.NewLine}{exception.Message}");
        }
        finally
        {
            ResetIconButton.IsEnabled = true;
        }
    }

    private void UpdateIconPresentation()
    {
        ResetIconButton.IsEnabled = !string.IsNullOrWhiteSpace(_application.IconUri);
        ApplicationIconImage.Visibility = Visibility.Collapsed;
        ApplicationIconGlyph.Visibility = Visibility.Visible;

        if (string.IsNullOrWhiteSpace(_application.IconUri))
        {
            ApplicationIconStatusText.Text = _application.IconSourceText;
            return;
        }

        try
        {
            ApplicationIconImage.Source = new Microsoft.UI.Xaml.Media.Imaging.BitmapImage(
                new Uri(_application.IconUri));
            ApplicationIconImage.Visibility = Visibility.Visible;
            ApplicationIconGlyph.Visibility = Visibility.Collapsed;
            ApplicationIconStatusText.Text = _application.IconSourceText;
        }
        catch
        {
            ApplicationIconStatusText.Text = "A custom icon is configured, but it could not be previewed.";
        }
    }

    private async void InstallButton_Click(object sender, RoutedEventArgs e)
    {
        if (_application.InstallationState != WintainiumInstallationState.NotInstalled)
        {
            return;
        }

        if (string.IsNullOrWhiteSpace(_application.ManifestPath))
        {
            ShowDetailsError("The application's manifest path is not available, so the installation cannot be requested.");
            return;
        }

        _operationCancellation?.Dispose();
        _operationCancellation = new CancellationTokenSource();
        if (_onApplicationOperationStarted is not null)
        {
            await _onApplicationOperationStarted(_application.ApplicationId);
            _applicationOperationRegistered = true;
        }
        UpdateActionButtons();
        CancelOperationButton.IsEnabled = true;
        OperationStateText.Text = WintainiumOperationState.Running.ToString();
        OperationIdText.Text = "Operation ID: pending Core result.";
        OperationProgressRing.IsActive = true;
        DetailsErrorText.Visibility = Visibility.Collapsed;
        TroubleshootingDiagnosticsCard.Visibility = Visibility.Collapsed;
        TroubleshootingDiagnosticsItemsControl.ItemsSource = null;
        UpdateResultStatusText.Text = "Running the Core-owned installation lifecycle…";
        InstalledStateRefreshStatusText.Text = "Waiting for the installation result.";

        try
        {
            Directory.CreateDirectory(WintainiumDesktopPaths.InstalledStateRoot);
            Directory.CreateDirectory(WintainiumDesktopPaths.DownloadRoot);

            var machineArchitecture = RuntimeInformation.OSArchitecture switch
            {
                Architecture.X64 => "x64",
                Architecture.X86 => "x86",
                Architecture.Arm64 => "arm64",
                _ => RuntimeInformation.OSArchitecture.ToString()
            };

            var result = await _installService.ExecuteAsync(
                _application.ManifestPath,
                WintainiumDesktopPaths.InstalledStateRoot,
                machineArchitecture,
                WintainiumDesktopPaths.DownloadRoot,
                cancellationToken: _operationCancellation.Token);

            OperationStateText.Text = result.OperationState.ToString();
            OperationIdText.Text = $"Operation ID: {result.OperationId ?? "unavailable"}";
            ErrorItemsControl.ItemsSource = result.Errors.Select(FormatDiagnostic).ToArray();
            WarningItemsControl.ItemsSource = result.Warnings.Select(FormatDiagnostic).ToArray();
            TroubleshootingDiagnosticsItemsControl.ItemsSource = result.TroubleshootingDiagnostics.Select(FormatDiagnostic).ToArray();
            TroubleshootingDiagnosticsCard.Visibility = result.OperationState == WintainiumOperationState.Failed && result.TroubleshootingDiagnostics.Count > 0
                ? Visibility.Visible
                : Visibility.Collapsed;

            var completedStages = result.Stages.Count(stage => stage.IsSuccessful);
            UpdateResultStatusText.Text = result.OperationState switch
            {
                WintainiumOperationState.Completed =>
                    $"Installation completed. {completedStages} of {result.Stages.Count} lifecycle stage(s) reported successful.",
                WintainiumOperationState.Cancelled => "Installation was cancelled.",
                WintainiumOperationState.Failed => "Installation failed.",
                WintainiumOperationState.Running => "Installation is still running.",
                _ => $"Installation: {result.Status ?? "Unknown"}."
            };
            StageItemsControl.ItemsSource = result.Stages.Select(FormatStage).ToArray();
            InstalledStateRefreshStatusText.Text = "Refreshing authoritative installed state…";

            if (result.Errors.Count > 0)
            {
                ShowDetailsError(string.Join(
                    Environment.NewLine,
                    result.Errors.Select(static error => error.Message ?? error.Code ?? "Unknown error.")));
            }

            await RefreshAuthoritativeInstalledStateAsync(_operationCancellation.Token);
        }
        catch (OperationCanceledException)
        {
            UpdateResultStatusText.Text = "Installation was cancelled.";
            InstalledStateRefreshStatusText.Text = "Authoritative installed state was not refreshed because the installation was cancelled.";
            OperationStateText.Text = WintainiumOperationState.Cancelled.ToString();
        }
        catch (Exception exception)
        {
            UpdateResultStatusText.Text = "Installation failed before a structured result could be presented.";
            InstalledStateRefreshStatusText.Text = "Authoritative installed state was not refreshed.";
            ShowDetailsError($"Installation could not be completed.{Environment.NewLine}{exception.Message}");
        }
        finally
        {
            OperationProgressRing.IsActive = false;
            CancelOperationButton.IsEnabled = false;
            _operationCancellation?.Dispose();
            _operationCancellation = null;
            if (_applicationOperationRegistered)
            {
                _applicationOperationRegistered = false;
                if (_onApplicationOperationCompleted is not null)
                    await _onApplicationOperationCompleted(_application.ApplicationId);
            }
            UpdateActionButtons();
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
        if (_onApplicationOperationStarted is not null)
        {
            await _onApplicationOperationStarted(_application.ApplicationId);
            _applicationOperationRegistered = true;
        }
        UpdateActionButtons();
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
            else
            {
                var decisionResult = await _updateDecisionService.EvaluateAsync(
                    _application.ManifestPath,
                    GetMachineArchitecture(),
                    _operationCancellation.Token);

                OperationStateText.Text = decisionResult.OperationState.ToString();
                OperationIdText.Text = $"Operation ID: {decisionResult.OperationId}";

                ErrorItemsControl.ItemsSource = result.Errors
                    .Concat(decisionResult.Errors)
                    .Select(FormatDiagnostic)
                    .ToArray();
                WarningItemsControl.ItemsSource = result.Warnings
                    .Concat(decisionResult.Warnings)
                    .Select(FormatDiagnostic)
                    .ToArray();

                _application = _application with
                {
                    InstallationState = decisionResult.InstalledState?.InstallationState ?? _application.InstallationState,
                    InstalledVersion = decisionResult.InstalledState?.Version ?? _application.InstalledVersion
                };
                _application = WintainiumApplicationModelMapper.ApplyUpdateDecision(
                    _application,
                    decisionResult);

                PopulateApplicationFacts();

                if (decisionResult.Errors.Count > 0)
                {
                    ShowDetailsError(string.Join(
                        Environment.NewLine,
                        decisionResult.Errors.Select(static error => error.Message ?? error.Code ?? "Unknown error.")));
                }

                if (_onAuthoritativeStateChanged is not null)
                    await _onAuthoritativeStateChanged();
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
            _operationCancellation?.Dispose();
            _operationCancellation = null;
            if (_applicationOperationRegistered)
            {
                _applicationOperationRegistered = false;
                if (_onApplicationOperationCompleted is not null)
                    await _onApplicationOperationCompleted(_application.ApplicationId);
            }
            UpdateActionButtons();
        }
    }

    private static string GetMachineArchitecture() =>
        RuntimeInformation.OSArchitecture.ToString().ToLowerInvariant() switch
        {
            "x64" => "x64",
            "x86" => "x86",
            "arm64" => "arm64",
            "arm" => "arm",
            _ => "unknown"
        };

    private async void RunUpdateButton_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_application.ManifestPath))
        {
            ShowDetailsError("The application's manifest path is not available, so the update cannot be requested.");
            return;
        }

        _operationCancellation?.Dispose();
        _operationCancellation = new CancellationTokenSource();
        if (_onApplicationOperationStarted is not null)
        {
            await _onApplicationOperationStarted(_application.ApplicationId);
            _applicationOperationRegistered = true;
        }
        UpdateActionButtons();
        CancelOperationButton.IsEnabled = true;
        OperationStateText.Text = WintainiumOperationState.Running.ToString();
        OperationIdText.Text = "Operation ID: pending Core result.";
        OperationProgressRing.IsActive = true;
        DetailsErrorText.Visibility = Visibility.Collapsed;
        UpdateResultStatusText.Text = "Running the Core-owned update lifecycle…";
        InstalledStateRefreshStatusText.Text = "Waiting for the update result.";

        try
        {
            Directory.CreateDirectory(WintainiumDesktopPaths.InstalledStateRoot);
            Directory.CreateDirectory(WintainiumDesktopPaths.DownloadRoot);

            var machineArchitecture = RuntimeInformation.OSArchitecture switch
            {
                Architecture.X64 => "x64",
                Architecture.X86 => "x86",
                Architecture.Arm64 => "arm64",
                _ => RuntimeInformation.OSArchitecture.ToString()
            };

            var result = await _updateService.ExecuteAsync(
                _application.ManifestPath,
                WintainiumDesktopPaths.InstalledStateRoot,
                machineArchitecture,
                WintainiumDesktopPaths.DownloadRoot,
                cancellationToken: _operationCancellation.Token);

            _lastUpdateResult = result;
            OperationStateText.Text = result.OperationState.ToString();
            OperationIdText.Text = $"Operation ID: {result.OperationId ?? "unavailable"}";
            ErrorItemsControl.ItemsSource = result.Errors.Select(FormatDiagnostic).ToArray();
            WarningItemsControl.ItemsSource = result.Warnings.Select(FormatDiagnostic).ToArray();

            var completedStages = result.Stages.Count(stage => stage.IsSuccessful);
            UpdateResultStatusText.Text = result.OperationState switch
            {
                WintainiumOperationState.Completed =>
                    $"Update completed. {completedStages} of {result.Stages.Count} lifecycle stage(s) reported successful.",
                WintainiumOperationState.Cancelled => "Update was cancelled.",
                WintainiumOperationState.Failed => "Update failed.",
                WintainiumOperationState.Running => "Update is still running.",
                _ => $"Update: {result.Status ?? "Unknown"}."
            };
            StageItemsControl.ItemsSource = result.Stages.Select(FormatStage).ToArray();
            InstalledStateRefreshStatusText.Text = "Refreshing authoritative installed state…";

            if (result.Errors.Count > 0)
            {
                ShowDetailsError(string.Join(
                    Environment.NewLine,
                    result.Errors.Select(static error => error.Message ?? error.Code ?? "Unknown error.")));
            }

            await RefreshAuthoritativeInstalledStateAsync(_operationCancellation.Token);
        }
        catch (OperationCanceledException)
        {
            UpdateResultStatusText.Text = "Update was cancelled.";
            InstalledStateRefreshStatusText.Text = "Authoritative installed state was not refreshed because the update was cancelled.";
            OperationStateText.Text = WintainiumOperationState.Cancelled.ToString();
        }
        catch (Exception exception)
        {
            UpdateResultStatusText.Text = "Update failed before a structured result could be presented.";
            InstalledStateRefreshStatusText.Text = "Authoritative installed state was not refreshed.";
            ShowDetailsError($"Update could not be completed.{Environment.NewLine}{exception.Message}");
        }
        finally
        {
            OperationProgressRing.IsActive = false;
            CancelOperationButton.IsEnabled = false;
            _operationCancellation?.Dispose();
            _operationCancellation = null;
            if (_applicationOperationRegistered)
            {
                _applicationOperationRegistered = false;
                if (_onApplicationOperationCompleted is not null)
                    await _onApplicationOperationCompleted(_application.ApplicationId);
            }
            UpdateActionButtons();
        }
    }

    private async Task RefreshAuthoritativeInstalledStateAsync(CancellationToken cancellationToken)
    {
        try
        {
            var stateResult = await _installedStateService.RefreshAsync(
                _application.ManifestPath!,
                WintainiumDesktopPaths.InstalledStateRoot,
                cancellationToken: cancellationToken);

            if (!stateResult.IsSuccessful)
            {
                var message = stateResult.Errors.Count == 0
                    ? "The update result was received, but authoritative installed state could not be refreshed."
                    : string.Join(Environment.NewLine, stateResult.Errors.Select(FormatDiagnostic));

                InstalledStateRefreshStatusText.Text = "Authoritative installed-state refresh failed.";
                ShowDetailsError(message);
                return;
            }

            _application = WintainiumApplicationModelMapper.ApplyInstalledState(
                _application,
                stateResult.State);

            PopulateApplicationFacts();
            if (_onAuthoritativeStateChanged is not null)
            {
                try
                {
                    await _onAuthoritativeStateChanged();
                }
                catch (Exception exception)
                {
                    ShowDetailsError($"The authoritative installed state was refreshed, but the application collection could not be refreshed.{Environment.NewLine}{exception.Message}");
                }
            }

            InstalledStateRefreshStatusText.Text = stateResult.State is null
                ? "Authoritative installed state was not reported."
                : $"Authoritative installed state refreshed: {stateResult.State.InstallationState}"
                    + (string.IsNullOrWhiteSpace(stateResult.State.Version)
                        ? "."
                        : $" (version {stateResult.State.Version}).");
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            InstalledStateRefreshStatusText.Text = "Authoritative installed-state refresh failed.";
            ShowDetailsError($"The update result was received, but authoritative installed state could not be refreshed.{Environment.NewLine}{exception.Message}");
        }
    }

    private void CancelOperationButton_Click(object sender, RoutedEventArgs e)
    {
        _operationCancellation?.Cancel();
    }

    private void ApplicationDetailsWindow_Closed(object sender, WindowEventArgs args)
    {
        // The active operation owns disposal; closing the window only requests cancellation.
        _operationCancellation?.Cancel();
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

    private static string FormatStage(WintainiumApplicationUpdateStageModel stage)
    {
        return FormatStage(
            stage.Sequence,
            stage.Name,
            stage.Status,
            stage.IsSuccessful,
            stage.WasCancelled,
            stage.Error);
    }

    private static string FormatStage(WintainiumApplicationInstallStageModel stage)
    {
        return FormatStage(
            stage.Sequence,
            stage.Name,
            stage.Status,
            stage.IsSuccessful,
            stage.WasCancelled,
            stage.Error);
    }

    private static string FormatStage(
        int sequence,
        string? name,
        string? status,
        bool isSuccessful,
        bool wasCancelled,
        WintainiumOperationDiagnostic? error)
    {
        var outcome = wasCancelled
            ? "Cancelled"
            : isSuccessful
                ? "Succeeded"
                : "Failed";

        var statusText = string.IsNullOrWhiteSpace(status) ? string.Empty : $" — {status}";
        var errorText = error is null ? string.Empty : $" — {FormatDiagnostic(error)}";
        return $"{sequence}. {name ?? "Unnamed stage"}: {outcome}{statusText}{errorText}";
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