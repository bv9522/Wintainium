using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Wintainium.Desktop.Models;

namespace Wintainium.Desktop;

public sealed partial class MainWindow : Window
{
    private readonly WintainiumApplicationCollectionViewModel _applicationCollection;
    private SettingsWindow? _settingsWindow;

    public MainWindow()
    {
        InitializeComponent();
        Title = "Wintainium";

        _applicationCollection = new WintainiumApplicationCollectionViewModel();
        ApplicationListView.ItemsSource = _applicationCollection.Applications;
        ApplicationGridView.ItemsSource = _applicationCollection.Applications;
        UpdateViewModeButton();
        _applicationCollection.Applications.CollectionChanged += Applications_CollectionChanged;
        UpdateCollectionVisibility();
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

    private void ApplicationGridView_ItemClick(object sender, ItemClickEventArgs e)
    {
        // Application details are intentionally deferred to Phase 11F.
    }

    private void ApplicationListView_ItemClick(object sender, ItemClickEventArgs e)
    {
        // Application details are intentionally deferred to Phase 11F.
    }

    private async void AddSoftwareButton_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = "Add Software",
            Content = new TextBox
            {
                Header = "Source URL",
                PlaceholderText = "https://github.com/example/example"
            },
            PrimaryButtonText = "Add",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary
        };

        await dialog.ShowAsync();
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
            var dialog = new ContentDialog
            {
                XamlRoot = Content.XamlRoot,
                Title = "Settings could not be opened",
                Content = new TextBlock
                {
                    Text = exception.ToString(),
                    TextWrapping = TextWrapping.Wrap
                },
                CloseButtonText = "Close",
                DefaultButton = ContentDialogButton.Close
            };

            await dialog.ShowAsync();
        }
    }

    private SettingsWindow CreateSettingsWindow()
    {
        var window = new SettingsWindow();
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
