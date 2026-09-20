using Microsoft.UI;
using Microsoft.UI.Xaml;

namespace Wintainium.Desktop;

public partial class App : Application
{
    private Window? _window;

    internal static Dictionary<WindowId, Window> ActiveWindows { get; } = new();

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        if (_window is null)
        {
            _window = new MainWindow();
            TrackWindow(_window);
            _window.Activate();
        }
        else
        {
            _window.Activate();
        }
    }

    internal static void TrackWindow(Window window)
    {
        ArgumentNullException.ThrowIfNull(window);

        var windowId = window.AppWindow.Id;
        ActiveWindows[windowId] = window;
        window.Closed += (_, _) => ActiveWindows.Remove(windowId);
    }
}
