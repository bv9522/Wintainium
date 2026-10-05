using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.Graphics;
using Wintainium.Desktop.Settings;

namespace Wintainium.Desktop;

public sealed partial class SettingsWindow : Window
{
    private static readonly string[] CategoryNames =
    {
        "General",
        "Appearance",
        "Updates",
        "Sources",
        "Advanced"
    };

    private static readonly string[] CategoryDescriptions =
    {
        "General Wintainium behavior and preferences.",
        "Theme and visual style preferences.",
        "Global software update behavior.",
        "Configuration related to tracked software sources.",
        "Less-common and advanced application configuration."
    };

    private readonly WintainiumDesktopSettingsService _settings;
    private readonly ListView _categoryList;
    private readonly TextBlock _categoryTitle;
    private readonly TextBlock _categoryDescription;
    private readonly StackPanel _categoryContent;

    internal SettingsWindow(WintainiumDesktopSettingsService settings)
    {
        ArgumentNullException.ThrowIfNull(settings);

        _settings = settings;
        InitializeComponent();
        Title = "Wintainium Settings";
        AppWindow.Resize(new SizeInt32(760, 560));

        (_categoryList, _categoryTitle, _categoryDescription) = FindControls();

        _categoryContent = new StackPanel
        {
            Spacing = 16
        };

        var panel = (StackPanel)((Border)((Grid)((Grid)Content).Children[1]).Children[1]).Child;
        panel.Children.Add(_categoryContent);

        _categoryList.SelectionChanged += CategoryList_SelectionChanged;
        _categoryList.SelectedIndex = 0;
        UpdateCategoryContent(0);
    }

    private void CategoryList_SelectionChanged(object? sender, SelectionChangedEventArgs e)
    {
        UpdateCategoryContent(((ListView)sender!).SelectedIndex);
    }

    private void UpdateCategoryContent(int index)
    {
        if (index < 0 || index >= CategoryNames.Length)
        {
            return;
        }

        _categoryTitle.Text = CategoryNames[index];
        _categoryDescription.Text = CategoryDescriptions[index];
        _categoryContent.Children.Clear();

        switch (index)
        {
            case 0:
                AddGeneralControls();
                break;

            case 1:
                AddAppearanceControls();
                break;

            case 2:
                AddUpdateControls();
                break;

            case 3:
                AddPlaceholder("Source and provider configuration will be connected after the corresponding Core configuration contract exists.");
                break;

            case 4:
                AddPlaceholder("Advanced technical settings will be added only when their underlying application contracts exist.");
                break;
        }
    }

    private void AddGeneralControls()
    {
        AddSectionHeader("Startup");
        AddToggle(
            "Launch Wintainium when I sign in",
            "Start Wintainium automatically when you sign in to Windows.",
            _settings.Current.LaunchAtSignIn,
            value => _settings.SetLaunchAtSignIn(value));

        AddSectionHeader("Application Behavior");
        AddToggle(
            "Confirm before installing or updating software",
            "Ask for confirmation before Wintainium begins an install or update operation.",
            _settings.Current.ConfirmBeforeInstallOrUpdate,
            value => _settings.SetConfirmBeforeInstallOrUpdate(value));
        AddToggle(
            "Confirm before removing software",
            "Ask for confirmation before Wintainium removes software from your collection.",
            _settings.Current.ConfirmBeforeRemove,
            value => _settings.SetConfirmBeforeRemove(value));
        AddToggle(
            "Close Wintainium after an operation completes",
            "Close Wintainium when an install, update, or removal operation reaches its final state.",
            _settings.Current.CloseAfterOperation,
            value => _settings.SetCloseAfterOperation(value));

        AddSectionHeader("Notifications");
        AddToggle(
            "Show operation notifications",
            "Show user-facing notifications when Wintainium operations complete or fail.",
            _settings.Current.ShowOperationNotifications,
            value => _settings.SetShowOperationNotifications(value));
    }

    private void AddUpdateControls()
    {
        AddSectionHeader("Update Checking");
        var automaticChecking = AddToggle(
            "Automatically check for updates",
            "Periodically check your managed software for available updates.",
            _settings.Current.AutomaticallyCheckForUpdates,
            value =>
            {
                _settings.SetAutomaticallyCheckForUpdates(value);
                UpdateFrequencyState(automaticChecking, value);
            });

        var frequency = new ComboBox
        {
            Header = "Check frequency",
            Width = 360,
            ItemsSource = new[] { "Every day", "Every week", "Every two weeks", "Every month" },
            SelectedIndex = (int)_settings.Current.UpdateCheckFrequency,
            IsEnabled = _settings.Current.AutomaticallyCheckForUpdates
        };
        frequency.SelectionChanged += (_, _) =>
        {
            if (frequency.SelectedIndex >= 0)
            {
                _settings.SetUpdateCheckFrequency(
                    (WintainiumUpdateCheckFrequency)frequency.SelectedIndex);
            }
        };
        _categoryContent.Children.Add(frequency);

        AddSectionHeader("Automatic Updates");
        AddToggle(
            "Automatically install available updates",
            "Install available updates without waiting for you to start each operation. Application-specific policy will take precedence when that policy is introduced.",
            _settings.Current.AutomaticallyInstallUpdates,
            value => _settings.SetAutomaticallyInstallUpdates(value));

        AddSectionHeader("Notifications");
        AddToggle(
            "Notify me when updates are available",
            "Notify you when Wintainium discovers an available software update.",
            _settings.Current.NotifyWhenUpdatesAvailable,
            value => _settings.SetNotifyWhenUpdatesAvailable(value));
        AddToggle(
            "Notify me when updates are installed",
            "Notify you when an automatic or user-started update completes successfully.",
            _settings.Current.NotifyWhenUpdatesInstalled,
            value => _settings.SetNotifyWhenUpdatesInstalled(value));
        AddToggle(
            "Notify me when an update fails",
            "Notify you when an update operation cannot be completed.",
            _settings.Current.NotifyWhenUpdateFails,
            value => _settings.SetNotifyWhenUpdateFails(value));
    }

    private ToggleSwitch AddToggle(
        string header,
        string description,
        bool isOn,
        Action<bool> onChanged)
    {
        var toggle = new ToggleSwitch
        {
            Header = header,
            IsOn = isOn,
            HorizontalAlignment = HorizontalAlignment.Stretch
        };

        var descriptionText = new TextBlock
        {
            Text = description,
            TextWrapping = TextWrapping.Wrap,
            Opacity = 0.68,
            Margin = new Thickness(0, 2, 0, 0)
        };

        var panel = new StackPanel
        {
            Spacing = 2,
            Children =
            {
                toggle,
                descriptionText
            }
        };

        toggle.Toggled += (_, _) => onChanged(toggle.IsOn);
        _categoryContent.Children.Add(panel);

        return toggle;
    }

    private void UpdateFrequencyState(ToggleSwitch automaticChecking, bool isEnabled)
    {
        if (_categoryContent.Children.Count == 0)
        {
            return;
        }

        foreach (var child in _categoryContent.Children)
        {
            if (child is ComboBox comboBox && comboBox.Header is string header &&
                string.Equals(header, "Check frequency", StringComparison.Ordinal))
            {
                comboBox.IsEnabled = isEnabled;
                return;
            }
        }
    }

    private void AddSectionHeader(string text)
    {
        _categoryContent.Children.Add(
            new TextBlock
            {
                Text = text,
                FontSize = 16,
                FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
                Margin = new Thickness(0, 8, 0, 0)
            });
    }

    private void AddAppearanceControls()
    {
        var theme = new ComboBox
        {
            Header = "Theme",
            Width = 360,
            ItemsSource = new[] { "System", "Light", "Dark" },
            SelectedIndex = (int)_settings.Current.Theme
        };

        var visualStyle = new ComboBox
        {
            Header = "Visual style",
            Width = 360,
            ItemsSource = new[] { "Windows 11", "Y2K", "Frutiger Aero" },
            SelectedIndex = (int)_settings.Current.VisualStyle
        };

        theme.SelectionChanged += (_, _) =>
        {
            if (theme.SelectedIndex >= 0)
            {
                _settings.SetTheme((WintainiumThemePreference)theme.SelectedIndex);
            }
        };

        visualStyle.SelectionChanged += (_, _) =>
        {
            if (visualStyle.SelectedIndex >= 0)
            {
                _settings.SetVisualStyle((WintainiumVisualStyle)visualStyle.SelectedIndex);
            }
        };

        _categoryContent.Children.Add(theme);
        _categoryContent.Children.Add(visualStyle);
        AddPlaceholder("Appearance preferences are stored with Wintainium desktop settings. The visual system will be expanded here after the Appearance design is finalized.");
    }

    private void AddPlaceholder(string text)
    {
        _categoryContent.Children.Add(
            new Border
            {
                Padding = new Thickness(16),
                CornerRadius = new CornerRadius(8),
                Child = new TextBlock
                {
                    Text = text,
                    TextWrapping = TextWrapping.Wrap
                }
            });
    }

    private (ListView, TextBlock, TextBlock) FindControls()
    {
        var root = (Grid)Content;
        var body = (Grid)root.Children[1];
        var categoryList = (ListView)body.Children[0];
        var panel = (StackPanel)((Border)body.Children[1]).Child;

        return (
            categoryList,
            (TextBlock)panel.Children[0],
            (TextBlock)panel.Children[1]);
    }
}
