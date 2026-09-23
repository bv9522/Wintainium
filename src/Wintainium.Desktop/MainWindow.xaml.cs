using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
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
        Loaded += MainWindow_Loaded;
    }

    internal void SetApplicationCollection(IEnumerable<WintainiumApplicationModel> applications)
    {
        _applicationCollection.SetApplications(applications);
        UpdateCollectionVisibility();
    }

    internal void SetApplicationQuery(WintainiumApplicationQuery query)
    {
        _applicationCollection.SetQuery(query);
        UpdateCollectionVisibility();
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
        var showList = hasApplications && _applicationCollection.ViewMode == WintainiumApplicationViewMode.List;
        var showGrid = hasApplications && _applicationCollection.ViewMode == WintainiumApplicationViewMode.Grid;

        ApplicationListView.Visibility = showList ? Visibility.Visible : Visibility.Collapsed;
        ApplicationGridView.Visibility = showGrid ? Visibility.Visible : Visibility.Collapsed;
        EmptyStatePanel.Visibility = hasApplications ? Visibility.Collapsed : Visibility.Visible;
    }

    private void ViewModeButton_Click(object sender, RoutedEventArgs e)
    {
        var nextMode = _applicationCollection.ViewMode == WintainiumApplicationViewMode.List
            ? WintainiumApplicationViewMode.Grid
            : WintainiumApplicationViewMode.List;

        _applicationCollection.SetViewMode(nextMode);
        UpdateViewModeButton();
        UpdateCollectionVisibility();
    }

    private void UpdateViewModeButton()
    {
        ViewModeButton.Content = _applicationCollection.ViewMode == WintainiumApplicationViewMode.List
            ? "List"
            : "Grid";
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

            var window = new ApplicationDetailsWindow(application, _services.ApplicationRelease);
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
        Loaded -= MainWindow_Loaded;
        await RefreshApplicationCollectionAsync();
    }

    private async Task RefreshApplicationCollectionAsync()
    {
        if (_collectionLoadInProgress)
        {
            return;
        }

        _collectionLoadInProgress = true;
        try
        {
            Directory.CreateDirectory(WintainiumDesktopPaths.ManifestRoot);

            var result = await _services.ApplicationCollection.LoadAsync(
                WintainiumDesktopPaths.ManifestRoot,
                cancellationToken: CancellationToken.None);

            SetApplicationCollection(result.Applications);

            if (!result.IsSuccessful && result.Errors.Count > 0)
            {
                await ShowOperationFailureAsync(
                    "Software collection could not be loaded",
                    result.Errors);
            }
        }
        catch (Exception exception)
        {
            await ShowExceptionAsync("Software collection could not be loaded", exception);
        }
        finally
        {
            _collectionLoadInProgress = false;
        }
    }

    private async void AddSoftwareButton_Click(object sender, RoutedEventArgs e)
    {
        var sourceTextBox = new TextBox
        {
            Header = "Source URL",
            PlaceholderText = "https://github.com/example/example",
            TextWrapping = TextWrapping.NoWrap
        };

        var dialog = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = "Add Software",
            Content = sourceTextBox,
            PrimaryButtonText = "Add",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary
        };

        if (await dialog.ShowAsync() != ContentDialogResult.Primary ||
            string.IsNullOrWhiteSpace(sourceTextBox.Text))
        {
            return;
        }

        try
        {
            var result = await _services.ApplicationOnboarding.OnboardAsync(
                sourceTextBox.Text.Trim(),
                WintainiumDesktopPaths.ManifestRoot,
                cancellationToken: CancellationToken.None);

            if (!result.IsSuccessful)
            {
                await ShowOperationFailureAsync(
                    "Software could not be added",
                    result.Errors);
                return;
            }

            await RefreshApplicationCollectionAsync();
        }
        catch (Exception exception)
        {
            await ShowExceptionAsync("Software could not be added", exception);
        }
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
