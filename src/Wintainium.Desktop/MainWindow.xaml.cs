using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Windowing;
using Windows.System;
using Wintainium.Desktop.Models;
using Wintainium.Desktop.Settings;

namespace Wintainium.Desktop;

public sealed partial class MainWindow : Window
{
    private readonly WintainiumApplicationCollectionViewModel _applicationCollection;
    private readonly WintainiumDesktopServices _services;
    private readonly Dictionary<string, ApplicationDetailsWindow> _applicationDetailsWindows = new(StringComparer.OrdinalIgnoreCase);
    private SettingsWindow? _settingsWindow;
    private bool _collectionLoadInProgress;
    private CancellationTokenSource? _collectionRefreshCancellation;
    private readonly HashSet<string> _activeApplicationOperations = new(StringComparer.OrdinalIgnoreCase);
    private readonly Dictionary<string, long> _applicationRefreshGenerations = new(StringComparer.OrdinalIgnoreCase);

    public MainWindow()
    {
        InitializeComponent();
        Title = "Wintainium";
        _services = ((App)Application.Current).Services;

        _applicationCollection = new WintainiumApplicationCollectionViewModel();
        ApplicationListView.ItemsSource = _applicationCollection.Applications;
        ApplicationGridView.ItemsSource = _applicationCollection.Applications;
        UpdateViewModeButton();
        _applicationCollection.Applications.CollectionChanged += Applications_CollectionChanged;
        UpdateCollectionVisibility();
        Closed += MainWindow_Closed;
        if (Content is FrameworkElement content)
        {
            content.Loaded += MainWindow_Loaded;
        }
    }

    internal void ApplyWindowChromeForCurrentVisualStyle()
    {
        if (App.Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            Y2KTitleBar.Visibility = Visibility.Collapsed;
            SetTitleBar(null);
            AppWindow.TitleBar.ResetToDefault();
            ExtendsContentIntoTitleBar = false;
            return;
        }

        var titleBar = AppWindow.TitleBar;
        if (!AppWindowTitleBar.IsCustomizationSupported())
        {
            Y2KTitleBar.Visibility = Visibility.Collapsed;
            SetTitleBar(null);
            ExtendsContentIntoTitleBar = false;
            return;
        }

        Y2KTitleBar.Visibility = Visibility.Visible;
        Y2KTitleBarText.FontFamily = new FontFamily(
            "ms-appx:///Cyberwave2000-Regular.otf#Cyberwave 2000");
        Y2KTitleBarText.Foreground = new SolidColorBrush(
            ColorHelper.FromArgb(255, 0x76, 0x5C, 0xFF));

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(Y2KTitleBar);

        var violet = ColorHelper.FromArgb(255, 0x76, 0x5C, 0xFF);
        var violetHover = ColorHelper.FromArgb(48, 0x76, 0x5C, 0xFF);
        var violetPressed = ColorHelper.FromArgb(80, 0x76, 0x5C, 0xFF);

        titleBar.ButtonBackgroundColor = Colors.Transparent;
        titleBar.ButtonForegroundColor = violet;
        titleBar.ButtonHoverBackgroundColor = violetHover;
        titleBar.ButtonHoverForegroundColor = violet;
        titleBar.ButtonPressedBackgroundColor = violetPressed;
        titleBar.ButtonPressedForegroundColor = violet;
        titleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
        titleBar.ButtonInactiveForegroundColor = violet;
    }

    internal void SetApplicationCollection(IEnumerable<WintainiumApplicationModel> applications)
    {
        _applicationCollection.SetApplications(applications);
        UpdateCollectionVisibility();
    }

    internal void SetApplicationQuery(WintainiumApplicationQuery query)
    {
        var selectedApplicationId = GetSelectedApplicationId();

        _applicationCollection.SetQuery(query);
        UpdateCollectionVisibility();
        RestoreSelectedApplication(selectedApplicationId);
    }

    private void Applications_CollectionChanged(
        object? sender,
        System.Collections.Specialized.NotifyCollectionChangedEventArgs e)
    {
        UpdateCollectionVisibility();
    }

    private void UpdateCollectionVisibility()
    {
        var hasApplications = _applicationCollection.Applications.Count > 0;
        UpdateCollectionSummary();
        CollectionLoadingText.Visibility =
            _collectionLoadInProgress ? Visibility.Visible : Visibility.Collapsed;
        var showList = hasApplications && _applicationCollection.ViewMode == WintainiumApplicationViewMode.List;
        var showGrid = hasApplications && _applicationCollection.ViewMode == WintainiumApplicationViewMode.Grid;

        ApplicationListView.Visibility = showList ? Visibility.Visible : Visibility.Collapsed;
        ApplicationGridView.Visibility = showGrid ? Visibility.Visible : Visibility.Collapsed;
        EmptyStatePanel.Visibility = hasApplications ? Visibility.Collapsed : Visibility.Visible;
    }

    private void UpdateCollectionSummary()
    {
        if (_collectionLoadInProgress)
        {
            ApplicationSummaryText.Text = "Loading applications…";
            return;
        }

        var visibleCount = _applicationCollection.Applications.Count;
        var updateCount = _applicationCollection.Applications.Count(
            application => application.UpdateStatus == WintainiumUpdateStatus.UpdateAvailable);

        ApplicationSummaryText.Text = visibleCount switch
        {
            0 => "No applications shown",
            1 => updateCount == 1 ? "1 application • 1 update available" : "1 application",
            _ => updateCount == 0
                ? $"{visibleCount} applications"
                : $"{visibleCount} applications • {updateCount} update{(updateCount == 1 ? "" : "s")} available"
        };
    }

    private async void RefreshButton_Click(object sender, RoutedEventArgs e)
    {
        await RefreshApplicationCollectionAsync();
    }

    private void ViewModeButton_Click(object sender, RoutedEventArgs e)
    {
        var selectedApplicationId = GetSelectedApplicationId();
        var nextMode = _applicationCollection.ViewMode == WintainiumApplicationViewMode.List
            ? WintainiumApplicationViewMode.Grid
            : WintainiumApplicationViewMode.List;

        _applicationCollection.SetViewMode(nextMode);
        UpdateViewModeButton();
        UpdateCollectionVisibility();
        RestoreSelectedApplication(selectedApplicationId);
    }

    private void UpdateViewModeButton()
    {
        var switchingToGrid = _applicationCollection.ViewMode == WintainiumApplicationViewMode.List;
        ViewModeButton.Content = switchingToGrid ? "Grid" : "List";
        ToolTipService.SetToolTip(
            ViewModeButton,
            switchingToGrid ? "Switch to grid view" : "Switch to list view");
    }

    private string? GetSelectedApplicationId()
    {
        var selected = _applicationCollection.ViewMode == WintainiumApplicationViewMode.List
            ? ApplicationListView.SelectedItem as WintainiumApplicationModel
            : ApplicationGridView.SelectedItem as WintainiumApplicationModel;

        return selected?.ApplicationId;
    }

    private void RestoreSelectedApplication(string? applicationId)
    {
        if (string.IsNullOrWhiteSpace(applicationId))
        {
            return;
        }

        var selected = _applicationCollection.Applications.FirstOrDefault(
            application => string.Equals(
                application.ApplicationId,
                applicationId,
                StringComparison.OrdinalIgnoreCase));

        if (selected is null)
        {
            return;
        }

        if (_applicationCollection.ViewMode == WintainiumApplicationViewMode.List)
        {
            ApplicationListView.SelectedItem = selected;
        }
        else
        {
            ApplicationGridView.SelectedItem = selected;
        }
    }

    private async void ApplicationItem_RightTapped(object sender, RightTappedRoutedEventArgs e)
    {
        if (sender is not FrameworkElement element ||
            element.DataContext is not WintainiumApplicationModel application)
        {
            return;
        }

        e.Handled = true;
        var flyout = new MenuFlyout();
        var removeItem = new MenuFlyoutItem { Text = "Remove Software" };
        removeItem.Click += async (_, _) => await RemoveApplicationAsync(application);
        flyout.Items.Add(removeItem);

        flyout.ShowAt(element, e.GetPosition(element));
    }

    private async Task RemoveApplicationAsync(WintainiumApplicationModel application)
    {
        if (string.IsNullOrWhiteSpace(application.ManifestPath))
        {
            await ShowExceptionAsync(
                "Software could not be removed",
                new InvalidOperationException("The application does not have a managed manifest path."));
            return;
        }

        var confirmation = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = $"Remove {application.DisplayName}?",
            Content = "This removes the software from your Wintainium collection. It does not uninstall the application from Windows.",
            PrimaryButtonText = "Remove",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Close
        };
        App.ApplyThemeToElement(confirmation);

        if (await confirmation.ShowAsync() != ContentDialogResult.Primary)
        {
            return;
        }

        try
        {
            var result = await _services.ApplicationRemoval.RemoveFromCollectionAsync(
                application.ManifestPath,
                WintainiumDesktopPaths.ManifestRoot,
                CancellationToken.None);

            if (!result.IsSuccessful)
            {
                await ShowOperationFailureAsync(
                    "Software could not be removed",
                    result.Errors);
                return;
            }

            if (_applicationDetailsWindows.TryGetValue(application.ApplicationId, out var detailsWindow))
            {
                detailsWindow.Close();
                _applicationDetailsWindows.Remove(application.ApplicationId);
            }

            await RefreshApplicationCollectionAsync();
        }
        catch (Exception exception)
        {
            await ShowExceptionAsync("Software could not be removed", exception);
        }
    }

    private async void ApplicationGridView_ItemClick(object sender, ItemClickEventArgs e)
    {
        await OpenApplicationDetailsAsync(e.ClickedItem as WintainiumApplicationModel);
    }

    private async void ApplicationListView_ItemClick(object sender, ItemClickEventArgs e)
    {
        await OpenApplicationDetailsAsync(e.ClickedItem as WintainiumApplicationModel);
    }

    private async Task OpenApplicationDetailsAsync(WintainiumApplicationModel? application)
    {
        if (application is null)
        {
            return;
        }

        try
        {
            if (_applicationDetailsWindows.TryGetValue(application.ApplicationId, out var existing))
            {
                existing.Activate();
                return;
            }

            var window = new ApplicationDetailsWindow(
                application,
                _services.ApplicationRelease,
                _services.ApplicationUpdate,
                _services.ApplicationInstall,
                _services.ApplicationUpdateDecision,
                _services.InstalledApplicationState,
                _services.ApplicationIcon,
                RefreshApplicationCollectionAsync,
                BeginApplicationOperationAsync,
                CompleteApplicationOperationAsync);
            _applicationDetailsWindows[application.ApplicationId] = window;
            window.Closed += (_, _) => _applicationDetailsWindows.Remove(application.ApplicationId);
            App.TrackWindow(window);
            window.Activate();
        }
        catch (Exception exception)
        {
            await ShowExceptionAsync("Application details could not be opened", exception);
        }
    }

    private void MainWindow_Closed(object sender, WindowEventArgs args)
    {
        foreach (var window in _applicationDetailsWindows.Values.ToArray())
        {
            window.Close();
        }

        _applicationDetailsWindows.Clear();
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement content)
        {
            content.Loaded -= MainWindow_Loaded;
        }
        await RefreshApplicationCollectionAsync();
    }

    private async Task RefreshApplicationCollectionAsync()
    {
        if (_collectionLoadInProgress)
            return;

        _collectionRefreshCancellation?.Cancel();
        _collectionRefreshCancellation?.Dispose();
        _collectionRefreshCancellation = new CancellationTokenSource();
        var cancellationToken = _collectionRefreshCancellation.Token;

        var selectedApplicationId = GetSelectedApplicationId();
        _collectionLoadInProgress = true;
        UpdateCollectionVisibility();

        try
        {
            Directory.CreateDirectory(WintainiumDesktopPaths.ManifestRoot);

            // Stage 1: load only the manifest-backed collection and present it immediately.
            var result = await _services.ApplicationCollection.LoadAsync(
                WintainiumDesktopPaths.ManifestRoot,
                cancellationToken: cancellationToken);

            SetApplicationCollection(result.Applications);
            RestoreSelectedApplication(selectedApplicationId);

            _collectionLoadInProgress = false;
            UpdateCollectionVisibility();

            if (!result.IsSuccessful && result.Errors.Count > 0)
            {
                await ShowOperationFailureAsync("Software collection could not be loaded", result.Errors);
                return;
            }

            // Stage 2: hydrate the last persisted installed state before live discovery.
            // The Dashboard is already visible, and this local/Core state read avoids
            // showing a transient Unknown/Not installed value while reconciliation waits.
            await HydratePersistedApplicationStatesAsync(result.Applications, cancellationToken);

            // Stage 3: independently refresh every application. A slow provider
            // cannot block the Dashboard or another application's refresh.
            _ = RefreshApplicationStatesAsync(result.Applications, cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
        catch (Exception exception)
        {
            await ShowExceptionAsync("Software collection could not be loaded", exception);
        }
        finally
        {
            _collectionLoadInProgress = false;
            UpdateCollectionVisibility();
        }
    }

    private async Task HydratePersistedApplicationStatesAsync(
        IReadOnlyList<WintainiumApplicationModel> applications,
        CancellationToken cancellationToken)
    {
        try
        {
            var hydrated = await Task.WhenAll(applications.Select(async application =>
            {
                try
                {
                    return await _services.ApplicationCollection.HydratePersistedApplicationStateAsync(
                        application, cancellationToken);
                }
                catch (OperationCanceledException)
                {
                    throw;
                }
                catch
                {
                    return application;
                }
            })).ConfigureAwait(true);

            if (cancellationToken.IsCancellationRequested)
                return;

            foreach (var application in hydrated)
            {
                SetApplicationCollectionItem(application);
            }
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
        }
    }

    private Task BeginApplicationOperationAsync(string applicationId)
    {
        if (string.IsNullOrWhiteSpace(applicationId))
            return Task.CompletedTask;

        _activeApplicationOperations.Add(applicationId);
        IncrementApplicationRefreshGeneration(applicationId);
        return Task.CompletedTask;
    }

    private async Task CompleteApplicationOperationAsync(string applicationId)
    {
        if (string.IsNullOrWhiteSpace(applicationId))
            return;

        _activeApplicationOperations.Remove(applicationId);
        IncrementApplicationRefreshGeneration(applicationId);

        var application = _applicationCollection.Applications.FirstOrDefault(
            candidate => string.Equals(candidate.ApplicationId, applicationId, StringComparison.OrdinalIgnoreCase));

        if (application is null)
            return;

        await RefreshSingleApplicationAsync(
            application,
            _collectionRefreshCancellation?.Token ?? CancellationToken.None,
            allowDuringOperation: true);
    }

    private void IncrementApplicationRefreshGeneration(string applicationId)
    {
        _applicationRefreshGenerations.TryGetValue(applicationId, out var generation);
        _applicationRefreshGenerations[applicationId] = generation + 1;
    }

    private bool IsApplicationRefreshCurrent(string applicationId, long generation, bool allowDuringOperation = false)
    {
        if (!allowDuringOperation && _activeApplicationOperations.Contains(applicationId))
            return false;

        return _applicationRefreshGenerations.TryGetValue(applicationId, out var currentGeneration)
            && currentGeneration == generation;
    }

    private async Task RefreshApplicationStatesAsync(
        IReadOnlyList<WintainiumApplicationModel> applications,
        CancellationToken cancellationToken)
    {
        try
        {
            await Task.WhenAll(applications.Select(
                application => RefreshSingleApplicationAsync(application, cancellationToken))).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
        }
    }

    private async Task RefreshSingleApplicationAsync(
        WintainiumApplicationModel application,
        CancellationToken cancellationToken,
        bool allowDuringOperation = false)
    {
        try
        {
            _applicationRefreshGenerations.TryGetValue(application.ApplicationId, out var generation);

            if (!IsApplicationRefreshCurrent(application.ApplicationId, generation, allowDuringOperation))
                return;

            var result = await _services.ApplicationCollection.RefreshApplicationAsync(
                application, cancellationToken);

            if (!cancellationToken.IsCancellationRequested &&
                IsApplicationRefreshCurrent(application.ApplicationId, generation, allowDuringOperation))
            {
                SetApplicationCollectionItem(result.Application);
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch
        {
            // Keep the manifest-backed card visible if a background refresh fails.
        }
    }

    private void SetApplicationCollectionItem(WintainiumApplicationModel application)
    {
        _applicationCollection.UpdateApplication(application);
        UpdateCollectionVisibility();
    }

    private async void AddSoftwareButton_Click(object sender, RoutedEventArgs e)
    {
        var sourceTextBox = new TextBox
        {
            Header = "Source URL",
            PlaceholderText = "https://github.com/example/example",
            TextWrapping = TextWrapping.NoWrap
        };

        var progressRing = new ProgressRing
        {
            IsActive = false,
            Visibility = Visibility.Collapsed,
            Width = 20,
            Height = 20
        };

        var statusText = new TextBlock
        {
            TextWrapping = TextWrapping.Wrap,
            Visibility = Visibility.Collapsed
        };

        Grid.SetColumn(statusText, 1);

        var recoveryButton = new Button
        {
            Content = "Open Source",
            Visibility = Visibility.Collapsed
        };

        var content = new StackPanel
        {
            Spacing = 12,
            Children =
            {
                sourceTextBox,
                new Grid
                {
                    ColumnDefinitions =
                    {
                        new ColumnDefinition { Width = GridLength.Auto },
                        new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) }
                    },
                    Children =
                    {
                        progressRing,
                        statusText
                    }
                },
                recoveryButton
            }
        };

        var dialog = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = "Add Software",
            Content = content,
            PrimaryButtonText = "Add",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary
        };
        App.ApplyThemeToElement(dialog);

        var onboardingComplete = false;
        var sourceUri = string.Empty;

        recoveryButton.Click += async (_, _) =>
        {
            if (string.IsNullOrWhiteSpace(sourceUri))
            {
                return;
            }

            try
            {
                await Launcher.LaunchUriAsync(new Uri(sourceUri));
            }
            catch (Exception exception)
            {
                await ShowExceptionAsync("Source could not be opened", exception);
            }
        };

        dialog.PrimaryButtonClick += async (_, args) =>
        {
            if (onboardingComplete)
            {
                return;
            }

            var deferral = args.GetDeferral();
            try
            {
                sourceUri = sourceTextBox.Text.Trim();
                if (string.IsNullOrWhiteSpace(sourceUri))
                {
                    args.Cancel = true;
                    statusText.Text = "Enter a source URL to add software.";
                    statusText.Visibility = Visibility.Visible;
                    return;
                }

                args.Cancel = true;
                sourceTextBox.IsEnabled = false;
                dialog.IsPrimaryButtonEnabled = false;
                dialog.IsSecondaryButtonEnabled = false;
                recoveryButton.Visibility = Visibility.Collapsed;
                progressRing.Visibility = Visibility.Visible;
                progressRing.IsActive = true;
                statusText.Text = "Resolving source…";
                statusText.Visibility = Visibility.Visible;
                dialog.PrimaryButtonText = "Adding…";

                try
                {
                    var result = await _services.ApplicationOnboarding.OnboardAsync(
                        sourceUri,
                        WintainiumDesktopPaths.ManifestRoot,
                        cancellationToken: CancellationToken.None);

                    if (!result.IsSuccessful)
                    {
                        var (_, message, canOpenSource) = GetOnboardingFailurePresentation(result);
                        var diagnostics = result.Errors.Count == 0
                            ? string.Empty
                            : string.Join(Environment.NewLine, result.Errors.Select(FormatDiagnostic));

                        statusText.Text = string.IsNullOrWhiteSpace(diagnostics)
                            ? message
                            : $"{message}{Environment.NewLine}{Environment.NewLine}{diagnostics}";
                        statusText.Visibility = Visibility.Visible;
                        recoveryButton.Visibility = canOpenSource ? Visibility.Visible : Visibility.Collapsed;
                        sourceTextBox.IsEnabled = true;
                        dialog.IsPrimaryButtonEnabled = true;
                        dialog.IsSecondaryButtonEnabled = true;
                        dialog.PrimaryButtonText = "Try Again";
                        progressRing.IsActive = false;
                        progressRing.Visibility = Visibility.Collapsed;
                        return;
                    }

                    await RefreshApplicationCollectionAsync();

                    onboardingComplete = true;
                    sourceTextBox.Visibility = Visibility.Collapsed;
                    recoveryButton.Visibility = Visibility.Collapsed;
                    progressRing.IsActive = false;
                    progressRing.Visibility = Visibility.Collapsed;
                    statusText.Text = "Software was added to your Wintainium collection.";
                    statusText.Visibility = Visibility.Visible;
                    dialog.Title = "Software Added";
                    dialog.PrimaryButtonText = "Done";
                    dialog.CloseButtonText = null;
                    dialog.IsPrimaryButtonEnabled = true;
                    dialog.IsSecondaryButtonEnabled = false;
                }
                catch (Exception exception)
                {
                    statusText.Text = $"Software could not be added.{Environment.NewLine}{Environment.NewLine}{exception.Message}";
                    statusText.Visibility = Visibility.Visible;
                    sourceTextBox.IsEnabled = true;
                    dialog.IsPrimaryButtonEnabled = true;
                    dialog.IsSecondaryButtonEnabled = true;
                    dialog.PrimaryButtonText = "Try Again";
                    progressRing.IsActive = false;
                    progressRing.Visibility = Visibility.Collapsed;
                }
            }
            finally
            {
                deferral.Complete();
            }
        };

        await dialog.ShowAsync();
    }

    private static (string Title, string Message, bool CanOpenSource) GetOnboardingFailurePresentation(
        WintainiumApplicationOnboardingResult result)
    {
        return result.Status switch
        {
            "SourceUnsupported" => (
                "Source not supported",
                "Wintainium could not identify a supported source provider for this URL. No application was added.",
                false),
            "SourceAmbiguous" => (
                "Source is ambiguous",
                "More than one source provider resolved this URL. Wintainium did not choose one automatically, and no application was added.",
                false),
            "SourceUnavailable" => (
                "Source is unavailable",
                "The source could not be resolved because the upstream source is currently unavailable. No application was added.",
                false),
            "AuthenticationRequired" => (
                "Authentication required",
                "The source requires authentication before Wintainium can resolve it. You can open the source in your browser and then try again.",
                true),
            "InteractiveResolutionRequired" => (
                "Interactive resolution required",
                "This source requires interactive browser resolution. You can open the source in your browser and then try again.",
                true),
            "SourceResponseInvalid" => (
                "Source response could not be resolved",
                "The source returned information that Wintainium could not validate as a deterministic application identity. No application was added.",
                false),
            _ => (
                "Software could not be added",
                "Wintainium could not add this software. No application was added.",
                false)
        };
    }

    private async Task ShowOperationFailureAsync(
        string title,
        IReadOnlyList<WintainiumOperationDiagnostic> errors)
    {
        var message = errors.Count == 0
            ? "The operation failed without a structured diagnostic."
            : string.Join(Environment.NewLine, errors.Select(FormatDiagnostic));

        var dialog = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = title,
            Content = new TextBlock
            {
                Text = message,
                TextWrapping = TextWrapping.Wrap
            },
            CloseButtonText = "Close",
            DefaultButton = ContentDialogButton.Close
        };
        App.ApplyThemeToElement(dialog);

        await dialog.ShowAsync();
    }

    private async Task ShowExceptionAsync(string title, Exception exception)
    {
        var dialog = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = title,
            Content = new TextBlock
            {
                Text = exception.Message,
                TextWrapping = TextWrapping.Wrap
            },
            CloseButtonText = "Close",
            DefaultButton = ContentDialogButton.Close
        };
        App.ApplyThemeToElement(dialog);

        await dialog.ShowAsync();
    }

    private static string FormatDiagnostic(WintainiumOperationDiagnostic diagnostic)
    {
        var prefix = string.IsNullOrWhiteSpace(diagnostic.Code) ? "Error" : diagnostic.Code;
        var path = string.IsNullOrWhiteSpace(diagnostic.Path) ? string.Empty : $" ({diagnostic.Path})";
        return $"{prefix}{path}: {diagnostic.Message}";
    }

    private async void SortAndFilterButton_Click(object sender, RoutedEventArgs e)
    {
        var sortComboBox = new ComboBox
        {
            Header = "Sort by",
            Width = 320,
            SelectedIndex = (int)_applicationCollection.Query.Sort,
            ItemsSource = new[]
            {
                "Name A–Z",
                "Name Z–A",
                "Update status",
                "Installed status",
                "Source"
            }
        };

        var filterComboBox = new ComboBox
        {
            Header = "Filter",
            Width = 320,
            SelectedIndex = (int)_applicationCollection.Query.Filter,
            ItemsSource = new[]
            {
                "All software",
                "Update available",
                "Up to date",
                "Installed",
                "Not installed"
            }
        };

        var content = new StackPanel
        {
            Spacing = 16,
            Children =
            {
                sortComboBox,
                filterComboBox
            }
        };

        var dialog = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = "Sort & Filter",
            Content = content,
            PrimaryButtonText = "Apply",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary
        };
        App.ApplyThemeToElement(dialog);

        if (await dialog.ShowAsync() != ContentDialogResult.Primary)
        {
            return;
        }

        if (sortComboBox.SelectedIndex < 0 || filterComboBox.SelectedIndex < 0)
        {
            return;
        }

        SetApplicationQuery(
            new WintainiumApplicationQuery(
                (WintainiumApplicationSort)sortComboBox.SelectedIndex,
                (WintainiumApplicationFilter)filterComboBox.SelectedIndex));
    }

    private async void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            _settingsWindow ??= CreateSettingsWindow();
            _settingsWindow.Activate();
        }
        catch (Exception exception)
        {
            await ShowExceptionAsync("Settings could not be opened", exception);
        }
    }

    private SettingsWindow CreateSettingsWindow()
    {
        var window = new SettingsWindow(App.Settings);
        window.Closed += SettingsWindow_Closed;
        App.TrackWindow(window);
        window.Activate();
        return window;
    }

    private void SettingsWindow_Closed(object sender, WindowEventArgs args)
    {
        if (ReferenceEquals(sender, _settingsWindow))
        {
            _settingsWindow = null;
        }
    }
}
