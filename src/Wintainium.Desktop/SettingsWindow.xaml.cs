using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace Wintainium.Desktop;

public sealed partial class SettingsWindow : Window
{
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
    }

    private void CategoryList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (CategoryList.SelectedIndex < 0)
        {
            return;
        }

        CategoryTitle.Text = ((ListViewItem)CategoryList.SelectedItem).Content?.ToString() ?? "Settings";
        CategoryDescription.Text = CategoryDescriptions[CategoryList.SelectedIndex];
    }
}
