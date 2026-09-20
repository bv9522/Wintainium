using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace Wintainium.Desktop;

public sealed partial class MainWindow : Window
{
    private SettingsWindow? _settingsWindow;

    public MainWindow()
    {
        InitializeComponent();
        Title = "Wintainium";
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
        var dialog = new ContentDialog
        {
            XamlRoot = Content.XamlRoot,
            Title = "Sort & Filter",
            Content = new StackPanel
            {
                Spacing = 16,
                Children =
                {
                    new ComboBox
                    {
                        Header = "Sort by",
                        Width = 320,
                        SelectedIndex = 0,
                        ItemsSource = new[]
                        {
                            "Name A–Z",
                            "Name Z–A",
                            "Update status",
                            "Installed status",
                            "Source"
                        }
                    },
                    new ComboBox
                    {
                        Header = "Filter",
                        Width = 320,
                        SelectedIndex = 0,
                        ItemsSource = new[]
                        {
                            "All software",
                            "Update available",
                            "Up to date",
                            "Installed",
                            "Not installed"
                        }
                    }
                }
            },
            CloseButtonText = "Done",
            DefaultButton = ContentDialogButton.Close
        };

        await dialog.ShowAsync();
    }

    private void SettingsButton_Click(object sender, RoutedEventArgs e)
    {
        _settingsWindow ??= CreateSettingsWindow();
        _settingsWindow.Activate();
    }

    private SettingsWindow CreateSettingsWindow()
    {
        var window = new SettingsWindow();
        window.Closed += SettingsWindow_Closed;
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
