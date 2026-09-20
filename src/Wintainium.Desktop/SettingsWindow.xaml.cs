using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

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
        "Theme, visual style, and collection presentation preferences.",
        "Wintainium application version history and update information.",
        "Configuration related to tracked software sources.",
        "Less-common and advanced application configuration."
    };

    public SettingsWindow()
    {
        InitializeComponent();
        Title = "Wintainium Settings";
        CategoryList.SelectedIndex = 0;
        UpdateCategoryContent(0);
    }

    private void CategoryList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        UpdateCategoryContent(CategoryList.SelectedIndex);
    }

    private void UpdateCategoryContent(int index)
    {
        if (index < 0 || index >= CategoryNames.Length)
        {
            return;
        }

        CategoryTitle.Text = CategoryNames[index];
        CategoryDescription.Text = CategoryDescriptions[index];

        CategoryContent.Children.Clear();

        switch (index)
        {
            case 0:
                AddPlaceholder("General preferences will be added in a later Phase 11 batch.");
                break;

            case 1:
                AddPlaceholder("Theme and visual-style controls are reserved here for the Appearance implementation.");
                AddPlaceholder("Collection presentation controls will support List and Grid views.");
                break;

            case 2:
                AddPlaceholder("This section is for Wintainium itself: current version, release history, and future self-update controls.");
                break;

            case 3:
                AddPlaceholder("Source and provider configuration will be connected after the Core integration boundary is established.");
                break;

            case 4:
                AddPlaceholder("Advanced technical settings will be added only when their underlying application contracts exist.");
                break;
        }
    }

    private void AddPlaceholder(string text)
    {
        var background = Application.Current.Resources["CardBackgroundFillColorDefaultBrush"] as Brush;

        CategoryContent.Children.Add(
            new Border
            {
                Padding = new Thickness(16),
                CornerRadius = new CornerRadius(8),
                Background = background,
                Child = new TextBlock
                {
                    Text = text,
                    TextWrapping = TextWrapping.Wrap
                }
            });
    }
}
