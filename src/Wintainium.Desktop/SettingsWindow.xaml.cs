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
        "Wintainium application version history and update information.",
        "Configuration related to tracked software sources.",
        "Less-common and advanced application configuration."
    };

    private readonly WintainiumDesktopSettingsService _settings;
    private readonly ListView _categoryList;
    private readonly TextBlock _categoryTitle;
    private readonly TextBlock _categoryDescription;
    private readonly StackPanel _categoryContent;

    public SettingsWindow(WintainiumDesktopSettingsService settings)
    {
        ArgumentNullException.ThrowIfNull(settings);

        _settings = settings;
        InitializeComponent();
        Title = "Wintainium Settings";
        AppWindow.Resize(new SizeInt32(760, 560));

        (_categoryList, _categoryTitle, _categoryDescription) = FindControls();

        _categoryContent = new StackPanel
        {
            Spacing = 12
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
                AddPlaceholder("General preferences will be added when their application contract is defined.");
                break;

            case 1:
                AddAppearanceControls();
                break;

            case 2:
                AddPlaceholder("This section is for Wintainium itself: current version, release history, and future self-update controls.");
                break;

            case 3:
                AddPlaceholder("Source and provider configuration will be connected after the corresponding Core configuration contract exists.");
                break;

            case 4:
                AddPlaceholder("Advanced technical settings will be added only when their underlying application contracts exist.");
                break;
        }
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
        AddPlaceholder("These preferences are currently session-scoped. Durable desktop configuration will be added only after its persistence boundary is defined.");
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
