using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Windows.Graphics;

namespace Wintainium.Desktop;

public sealed partial class SettingsWindow : Window
{
    public SettingsWindow()
    {
        InitializeComponent();
        Title = "Wintainium Settings";

        AppWindow.Resize(new SizeInt32(760, 560));
    }
}
