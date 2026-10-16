using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Xaml.Shapes;
using Windows.Foundation;
using Windows.UI.ViewManagement;
using Wintainium.Desktop.Settings;
using System.Collections.Generic;

namespace Wintainium.Desktop;

public partial class App : Application
{
    private Window? _window;
    private WintainiumDesktopServices? _services;
    private readonly UISettings _uiSettings;
    private static readonly Dictionary<WindowId, (ResourceDictionary VisualStyle, ResourceDictionary ActiveTheme)> WindowVisualStyleResources = new();

    internal static Dictionary<WindowId, Window> ActiveWindows { get; } = new();

    internal static WintainiumDesktopSettingsService Settings { get; } = new();

    internal static bool IsDarkThemeActive => Settings.Current.Theme == WintainiumThemePreference.Dark
        || (Settings.Current.Theme == WintainiumThemePreference.System
            && GetSystemElementTheme() == ElementTheme.Dark);

    internal WintainiumDesktopServices Services =>
        _services ??= new WintainiumDesktopServices();

    public App()
    {
        DispatcherShutdownMode = DispatcherShutdownMode.OnExplicitShutdown;
        InitializeComponent();

        _uiSettings = new UISettings();
        _uiSettings.ColorValuesChanged += SystemColors_Changed;
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        if (_window is null)
        {
            _window = new MainWindow();
            TrackWindow(_window);
            ApplyVisualStylePreference();
            _window.Closed += MainWindow_Closed;
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
        window.Closed += (_, _) =>
        {
            ActiveWindows.Remove(windowId);
            WindowVisualStyleResources.Remove(windowId);
        };
        ApplyThemeToWindow(window);
        ApplyVisualStyleToWindow(window);
        RefreshThemeResources(window);

        if (window.Content is FrameworkElement content)
        {
            void ApplyVisualStyleAfterLoaded(object sender, RoutedEventArgs args)
            {
                content.Loaded -= ApplyVisualStyleAfterLoaded;
                ApplyVisualStyleToWindow(window);
                RefreshThemeResources(window);
                if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
                {
                    QueueY2KTextColorPass(content);
                }
                else if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                    && !IsDarkThemeActive)
                {
                    ApplyFrutigerAeroTypography(content, preserveSoftwareCardTypography: window is MainWindow);
                }
                else if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                    && IsDarkThemeActive
                    && window is not MainWindow)
                {
                    ApplyFrutigerMetroDarkAppearance(content);
                }
            }

            content.Loaded += ApplyVisualStyleAfterLoaded;
        }
    }

    internal static void ApplyVisualStylePreference()
    {
        foreach (var window in ActiveWindows.Values.ToArray())
        {
            ApplyThemeToWindow(window);
            ApplyVisualStyleToWindow(window);
            RefreshThemeResources(window);
            if (window.Content is FrameworkElement content)
            {
                if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
                {
                    QueueY2KTextColorPass(content);
                }
                else if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                    && !IsDarkThemeActive)
                {
                    ApplyFrutigerAeroTypography(content, preserveSoftwareCardTypography: window is MainWindow);
                }
            }

            if (window is MainWindow mainWindow)
            {
                mainWindow.RefreshSoftwareCardTextColors();
            }

            if (window is SettingsWindow settingsWindow)
            {
                settingsWindow.RefreshAppearance();
            }
        }
    }

    private static void RefreshThemeResources(Window window)
    {
        if (window.Content is not FrameworkElement content)
        {
            return;
        }

        var effectiveTheme = Settings.Current.Theme switch
        {
            WintainiumThemePreference.Light => ElementTheme.Light,
            WintainiumThemePreference.Dark => ElementTheme.Dark,
            _ => GetSystemElementTheme()
        };

        var alternateTheme = effectiveTheme == ElementTheme.Light
            ? ElementTheme.Dark
            : ElementTheme.Light;

        content.RequestedTheme = alternateTheme;

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K
            || (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                && !IsDarkThemeActive))
        {
            // Re-applying RequestedTheme forces ThemeResource brushes to refresh after
            // a runtime dictionary swap, including open Settings windows and dropdowns.
            content.DispatcherQueue.TryEnqueue(() => content.RequestedTheme = effectiveTheme);
        }
        else
        {
            content.RequestedTheme = effectiveTheme;
        }
    }

    private static void ApplyVisualStyleToWindow(Window window)
    {
        if (window.Content is not FrameworkElement content)
        {
            return;
        }

        var windowId = window.AppWindow.Id;
        ApplyWindows11BlissBackdrop(content);
        var isFrutigerMetroDark = Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && IsDarkThemeActive;

        if (!isFrutigerMetroDark
            && content.FindName("FrutigerMetroBackdrop") is FrameworkElement previousMetroBackdrop)
        {
            previousMetroBackdrop.Visibility = Visibility.Collapsed;
        }

        if (!isFrutigerMetroDark)
        {
            ClearFrutigerMetroDarkAppearance(content);
        }

        if (WindowVisualStyleResources.TryGetValue(windowId, out var existing))
        {
            content.Resources.MergedDictionaries.Remove(existing.ActiveTheme);
            content.Resources.MergedDictionaries.Remove(existing.VisualStyle);
            WindowVisualStyleResources.Remove(windowId);
        }

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && !IsDarkThemeActive)
        {
            var aeroStyle = new ResourceDictionary
            {
                Source = new Uri("ms-appx:///Themes/FrutigerAero-Light.xaml")
            };
            content.Resources.MergedDictionaries.Add(aeroStyle);
            var activeAeroTheme = new ResourceDictionary();
            WindowVisualStyleResources[windowId] = (aeroStyle, activeAeroTheme);
            ApplyFrutigerAeroTypography(content, preserveSoftwareCardTypography: window is MainWindow);
            ApplyWindowChromeForCurrentVisualStyle(window);
            return;
        }

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && IsDarkThemeActive)
        {
            if (content.FindName("FrutigerMetroBackdrop") is FrameworkElement metroBackdrop)
            {
                metroBackdrop.Visibility = Visibility.Visible;
            }

            // MainWindow owns its compact card surfaces and typography. Do not recursively
            // paint every Control/Border here; doing so makes the ListView a giant opaque panel.
            if (window is MainWindow mainWindow)
            {
                mainWindow.ApplyWindowChromeForCurrentVisualStyle();
                return;
            }

            ApplyFrutigerMetroDarkAppearance(content);
            ApplyWindowChromeForCurrentVisualStyle(window);
            return;
        }

        if (content.FindName("FrutigerMetroBackdrop") is FrameworkElement hiddenMetroBackdrop)
        {
            hiddenMetroBackdrop.Visibility = Visibility.Collapsed;
        }

        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            ClearY2KTextColor(content);
            ApplyWindowChromeForCurrentVisualStyle(window);
            return;
        }

        var visualStyle = new ResourceDictionary
        {
            Source = new Uri("ms-appx:///Themes/Y2K.xaml")
        };

        content.Resources.MergedDictionaries.Add(visualStyle);

        var themeKey = IsDarkThemeActive ? "Dark" : "Light";

        var activeTheme = new ResourceDictionary();
        if (visualStyle.ThemeDictionaries.TryGetValue(themeKey, out var selectedTheme)
            && selectedTheme is ResourceDictionary selectedThemeDictionary)
        {
            foreach (var key in selectedThemeDictionary.Keys)
            {
                activeTheme[key] = selectedThemeDictionary[key];
            }
        }

        content.Resources.MergedDictionaries.Add(activeTheme);
        WindowVisualStyleResources[windowId] = (visualStyle, activeTheme);

        ApplyY2KTextColor(content);
        ApplyWindowChromeForCurrentVisualStyle(window);
    }

    private static void ApplyWindowChromeForCurrentVisualStyle(Window window)
    {
        if (window.Content is not FrameworkElement content)
        {
            return;
        }

        if (window is MainWindow mainWindow)
        {
            mainWindow.ApplyWindowChromeForCurrentVisualStyle();
            return;
        }

        if (content.FindName("Y2KDarkTelemetryBackdrop") is Y2KDarkTelemetryBackdrop telemetryBackdrop)
        {
            telemetryBackdrop.Visibility = Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K
                && IsDarkThemeActive
                    ? Visibility.Visible
                    : Visibility.Collapsed;
        }

        var titleBar = content.FindName("Y2KTitleBar") as Grid;
        var titleText = content.FindName("Y2KTitleBarText") as TextBlock;
        if (titleBar is null || titleText is null)
        {
            return;
        }

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && !IsDarkThemeActive)
        {
            ApplyFrutigerAeroTitleBar(window, titleBar, titleText);
            return;
        }

        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K ||
            !AppWindowTitleBar.IsCustomizationSupported())
        {
            titleBar.Visibility = Visibility.Collapsed;
            window.SetTitleBar(null);
            window.ExtendsContentIntoTitleBar = false;
            window.AppWindow.TitleBar.ResetToDefault();
            return;
        }

        var title = window switch
        {
            SettingsWindow => "Wintainium Settings",
            ApplicationDetailsWindow => window.Title,
            _ => window.Title
        };

        titleText.Text = title;
        titleText.FontFamily = GetY2KDisplayFont();
        titleText.Foreground = GetY2KTextBrush();
        if (WindowVisualStyleResources.TryGetValue(window.AppWindow.Id, out var resources)
            && resources.ActiveTheme.TryGetValue("WintainiumY2KTitleBarBrush", out var titleBarBrush)
            && titleBarBrush is Brush titleBarBackground)
        {
            titleBar.Background = titleBarBackground;
        }
        titleBar.Visibility = Visibility.Visible;
        window.ExtendsContentIntoTitleBar = true;
        window.SetTitleBar(titleBar);

        var nativeTitleBar = window.AppWindow.TitleBar;
        var textColor = IsDarkThemeActive
            ? ColorHelper.FromArgb(255, 0x39, 0xFF, 0x9A)
            : ColorHelper.FromArgb(255, 0x76, 0x5C, 0xFF);
        var textHover = ColorHelper.FromArgb(48, textColor.R, textColor.G, textColor.B);
        var textPressed = ColorHelper.FromArgb(80, textColor.R, textColor.G, textColor.B);
        nativeTitleBar.ButtonBackgroundColor = Colors.Transparent;
        nativeTitleBar.ButtonForegroundColor = textColor;
        nativeTitleBar.ButtonHoverBackgroundColor = textHover;
        nativeTitleBar.ButtonHoverForegroundColor = textColor;
        nativeTitleBar.ButtonPressedBackgroundColor = textPressed;
        nativeTitleBar.ButtonPressedForegroundColor = textColor;
        nativeTitleBar.ButtonInactiveBackgroundColor = Colors.Transparent;
        nativeTitleBar.ButtonInactiveForegroundColor = textColor;
    }

    internal static void ApplyFrutigerAeroTitleBar(Window window, Grid titleBar, TextBlock titleText)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
            || IsDarkThemeActive)
        {
            return;
        }

        if (!AppWindowTitleBar.IsCustomizationSupported())
        {
            titleBar.Visibility = Visibility.Collapsed;
            window.SetTitleBar(null);
            window.ExtendsContentIntoTitleBar = false;
            window.AppWindow.TitleBar.ResetToDefault();
            return;
        }

        titleText.Text = window.Title;
        titleText.FontFamily = new FontFamily("ms-appx:///Horatio%20D%20Regular.ttf#Horatio D");
        titleText.Foreground = new SolidColorBrush(ColorHelper.FromArgb(255, 0x17, 0x4F, 0x67));
        titleText.FontSize = Math.Max(titleText.FontSize, 16);
        titleBar.Background = GetFrutigerAeroTitleBarBrush();
        titleBar.Visibility = Visibility.Visible;
        window.ExtendsContentIntoTitleBar = true;
        window.SetTitleBar(titleBar);

        var nativeTitleBar = window.AppWindow.TitleBar;
        var textColor = ColorHelper.FromArgb(255, 0x17, 0x4F, 0x67);
        nativeTitleBar.BackgroundColor = Colors.Transparent;
        nativeTitleBar.ForegroundColor = textColor;
        nativeTitleBar.InactiveBackgroundColor = Colors.Transparent;
        nativeTitleBar.InactiveForegroundColor = textColor;
        nativeTitleBar.ButtonBackgroundColor = Colors.Transparent;
        nativeTitleBar.ButtonForegroundColor = textColor;
        nativeTitleBar.ButtonHoverBackgroundColor = ColorHelper.FromArgb(42, 0xFF, 0xFF, 0xFF);
        nativeTitleBar.ButtonHoverForegroundColor = textColor;
        nativeTitleBar.ButtonPressedBackgroundColor = ColorHelper.FromArgb(72, 0x5B, 0xB9, 0xD0);
        nativeTitleBar.ButtonPressedForegroundColor = textColor;
        nativeTitleBar.ButtonInactiveBackgroundColor = ColorHelper.FromArgb(18, 0xFF, 0xFF, 0xFF);
        nativeTitleBar.ButtonInactiveForegroundColor = textColor;
    }

    internal static Brush GetFrutigerAeroTitleBarBrush()
    {
        return new LinearGradientBrush
        {
            StartPoint = new Windows.Foundation.Point(0, 0),
            EndPoint = new Windows.Foundation.Point(0, 1),
            GradientStops =
            {
                new GradientStop { Color = ColorHelper.FromArgb(242, 0xF4, 0xFD, 0xFF), Offset = 0 },
                new GradientStop { Color = ColorHelper.FromArgb(218, 0xD4, 0xF5, 0xFC), Offset = 0.18 },
                new GradientStop { Color = ColorHelper.FromArgb(190, 0x8D, 0xD7, 0xEB), Offset = 0.52 },
                new GradientStop { Color = ColorHelper.FromArgb(224, 0xC8, 0xF0, 0xF8), Offset = 0.78 },
                new GradientStop { Color = ColorHelper.FromArgb(238, 0xE9, 0xFA, 0xFC), Offset = 1 }
            }
        };
    }

    private static void ApplyWindows11BlissBackdrop(FrameworkElement root)
    {
        var enabled = Settings.Current.VisualStyle == WintainiumVisualStyle.Windows11;
        if (root.FindName("Windows11BlissBackdrop") is FrameworkElement backdrop)
        {
            backdrop.Visibility = enabled ? Visibility.Visible : Visibility.Collapsed;
        }

        if (root.FindName("Windows11BlissLightImage") is FrameworkElement lightImage)
        {
            lightImage.Visibility = enabled && !IsDarkThemeActive
                ? Visibility.Visible : Visibility.Collapsed;
        }

        if (root.FindName("Windows11BlissDarkImage") is FrameworkElement darkImage)
        {
            darkImage.Visibility = enabled && IsDarkThemeActive
                ? Visibility.Visible : Visibility.Collapsed;
        }
    }

    private static void EnsureWindows11DialogBackdrop(ContentDialog dialog)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Windows11)
        {
            return;
        }

        // Mirror the working Y2K ContentDialog setup: provide ContentDialogBackground
        // and ensure the ContentDialog style explicitly consumes that ThemeResource.
        dialog.Resources["ContentDialogBackground"] = new ImageBrush
        {
            ImageSource = new BitmapImage(new Uri(
                IsDarkThemeActive
                    ? "ms-appx:///Themes/Windows%2011%20Bliss%20Dark.png"
                    : "ms-appx:///Themes/Windows%2011%20Bliss%20Light.png")),
            Stretch = Stretch.UniformToFill
        };

        var dialogStyleDictionary = new ResourceDictionary
        {
            Source = new Uri("ms-appx:///Themes/Windows11Dialog.xaml")
        };
        dialog.Resources.MergedDictionaries.Add(dialogStyleDictionary);
        dialog.Loaded -= Windows11ContentDialog_Loaded;
        dialog.Loaded += Windows11ContentDialog_Loaded;
    }

    private static void Windows11ContentDialog_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is ContentDialog dialog
            && Settings.Current.VisualStyle == WintainiumVisualStyle.Windows11)
        {
            ApplyWindows11DialogFooterSurface(dialog);
        }
    }

    private static void ApplyWindows11DialogFooterSurface(FrameworkElement element)
    {
        // Keep the Windows 11 wallpaper on the main dialog body, but give the
        // button/footer row its own opaque surface so the image cannot show there.
        if (element.Name is "CommandSpace" or "Button1Host" or "Button2Host" or "Button3Host")
        {
            var footerBrush = new SolidColorBrush(IsDarkThemeActive
                ? ColorHelper.FromArgb(255, 32, 32, 32)
                : ColorHelper.FromArgb(255, 243, 243, 243));

            if (element is Panel panel)
            {
                panel.Background = footerBrush;
            }
            else if (element is Border border)
            {
                border.Background = footerBrush;
            }
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyWindows11DialogFooterSurface(child);
            }
        }
    }

    private static void EnsureFrutigerMetroDialogBackdrop(ContentDialog dialog)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
            || !IsDarkThemeActive)
        {
            return;
        }

        // Paint the ContentDialog body itself, matching the proven Windows 11 and
        // Y2K dialog-backdrop pattern. Hosting the artwork inside dialog.Content or
        // its content presenter constrains it to the fields' smaller layout area.
        var metroArtwork = new ImageBrush
        {
            ImageSource = new SvgImageSource
            {
                UriSource = new Uri("ms-appx:///Themes/Frutiger-Metro-Dialog.svg")
            },
            Stretch = Stretch.UniformToFill
        };

        dialog.Resources["ContentDialogBackground"] = metroArtwork;
        dialog.Resources["ContentDialogTopOverlay"] =
            new SolidColorBrush(ColorHelper.FromArgb(0, 0, 0, 0));
        dialog.Background = metroArtwork;

        if (!dialog.Resources.MergedDictionaries.Any(dictionary =>
            dictionary.Source?.OriginalString == "ms-appx:///Themes/Windows11Dialog.xaml"))
        {
            dialog.Resources.MergedDictionaries.Add(new ResourceDictionary
            {
                Source = new Uri("ms-appx:///Themes/Windows11Dialog.xaml")
            });
        }
    }

    private static void ApplyFrutigerMetroDialogFooterSurface(FrameworkElement element)
    {
        // Like the Windows 11 footer pass, isolate the command row from the body
        // artwork. Use an opaque Metro surface, not transparency or a light gray fill.
        if (element.Name is "CommandSpace" or "Button1Host" or "Button2Host" or "Button3Host")
        {
            var footerBrush = new SolidColorBrush(ColorHelper.FromArgb(210, 28, 7, 12));
            if (element is Panel panel)
            {
                panel.Background = footerBrush;
            }
            else if (element is Border border)
            {
                border.Background = footerBrush;
                border.BorderBrush = new SolidColorBrush(ColorHelper.FromArgb(255, 255, 90, 31));
                border.BorderThickness = new Thickness(1);
            }

            return;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyFrutigerMetroDialogFooterSurface(child);
            }
        }
    }

    private static void ApplyFrutigerMetroDialogAppearance(FrameworkElement element)
    {
        var font = new FontFamily("ms-appx:///Themes/CutieTopRegular-VArx.ttf#Cutie Top");
        var gold = new SolidColorBrush(ColorHelper.FromArgb(255, 0xFF, 0xC9, 0x28));
        var controlBackground = new SolidColorBrush(ColorHelper.FromArgb(220, 28, 7, 12));
        var controlBorder = new SolidColorBrush(ColorHelper.FromArgb(255, 255, 90, 31));

        // Preserve the image-bearing ContentDialog and its layout surfaces. Style
        // text and actual input/action controls without painting every Border/Control.
        switch (element)
        {
            case TextBlock textBlock:
                if (!(textBlock.FontFamily?.Source?.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase) ?? false))
                {
                    textBlock.FontFamily = font;
                    textBlock.Foreground = gold;
                }
                break;
            case Control control when control is Button
                or TextBox or ComboBox or CheckBox or RadioButton
                or ToggleSwitch or PasswordBox or Slider:
                if (!(control.FontFamily?.Source?.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase) ?? false))
                {
                    control.FontFamily = font;
                    control.Foreground = gold;
                }
                control.Background = controlBackground;
                control.BorderBrush = controlBorder;
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyFrutigerMetroDialogAppearance(child);
            }
        }
    }

    private static void EnsureFrutigerAeroLightDialogBackdrop(ContentDialog dialog)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
            || IsDarkThemeActive)
        {
            return;
        }

        // Keep the NYC artwork confined to the main dialog body. Explicitly
        // clear the template overlay so the artwork/glass treatment appears above
        // the command row rather than allowing the page backdrop to show through.
        var dialogBackground = new ImageBrush
        {
            ImageSource = new BitmapImage(new Uri("ms-appx:///Themes/Frutiger%20Aero%20NYC%20Skyline.png")),
            Stretch = Stretch.UniformToFill
        };
        dialog.Resources["ContentDialogBackground"] = dialogBackground;
        dialog.Resources["ContentDialogTopOverlay"] =
            new SolidColorBrush(ColorHelper.FromArgb(217, 255, 255, 255));
        dialog.Background = dialogBackground;

        // Reuse the proven dialog template style so body and footer use separate
        // surfaces. Do not modify the main window's own page background.
        if (!dialog.Resources.MergedDictionaries.Any(dictionary =>
            dictionary.Source?.OriginalString == "ms-appx:///Themes/Windows11Dialog.xaml"))
        {
            dialog.Resources.MergedDictionaries.Add(new ResourceDictionary
            {
                Source = new Uri("ms-appx:///Themes/Windows11Dialog.xaml")
            });
        }
    }

    private static void EnsureY2KDarkTelemetryDialogBackdrop(ContentDialog dialog)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K
            || !IsDarkThemeActive)
        {
            return;
        }

        // Use the same resource-driven ContentDialog pattern that fixed Y2K Light
        // and Windows 11 dialogs. The dialog template consumes ContentDialogBackground
        // through ThemeResource; assigning dialog.Background directly paints the
        // outer ContentDialog surface and can make the artwork scale/crop incorrectly.
        dialog.Resources["ContentDialogTopOverlay"] =
            new SolidColorBrush(ColorHelper.FromArgb(0, 0, 0, 0));
        dialog.Resources["ContentDialogBackground"] = new ImageBrush
        {
            ImageSource = new SvgImageSource
            {
                UriSource = new Uri("ms-appx:///Themes/Y2K-DarkMainGrid.svg")
            },
            // Preserve the central W emblem and its original proportions. Telemetry
            // labels are rendered separately by the native WinUI overlay below.
            Stretch = Stretch.UniformToFill
        };

        var dialogStyleDictionary = new ResourceDictionary
        {
            Source = new Uri("ms-appx:///Themes/Windows11Dialog.xaml")
        };
        if (!dialog.Resources.MergedDictionaries.Any(dictionary =>
            dictionary.Source?.OriginalString == "ms-appx:///Themes/Windows11Dialog.xaml"))
        {
            dialog.Resources.MergedDictionaries.Add(dialogStyleDictionary);
        }
    }

    private static readonly Brush TransparentDialogBrush =
        new SolidColorBrush(ColorHelper.FromArgb(0, 0, 0, 0));

    private static void FrutigerMetroContentDialog_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is ContentDialog dialog
            && Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && IsDarkThemeActive)
        {
            // Use a dialog-specific FM pass: unlike ordinary FM windows, the dialog's
            // layout surfaces must not be painted over the ContentDialogBackground image.
            EnsureFrutigerMetroDialogBackdrop(dialog);
            ApplyFrutigerMetroDialogAppearance(dialog);
            ApplyFrutigerMetroDialogFooterSurface(dialog);
        }
    }

    private static void FrutigerAeroContentDialog_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is ContentDialog dialog
            && Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && !IsDarkThemeActive)
        {
            ApplyFrutigerAeroTypography(dialog);

            // Use the main Frutiger Aero artwork on the dialog surface, following
            // the working Y2K Light ContentDialogBackground ImageBrush pattern.
            EnsureFrutigerAeroLightDialogBackdrop(dialog);
            if (dialog.Content is FrameworkElement contentRoot)
            {
                // Do not paint opaque container gradients over the backdrop.
                QueueFrutigerAeroDialogTypography(contentRoot, 8);
            }
        }
    }

    private static void ApplyFrutigerAeroDialogSurface(FrameworkElement root)
    {
        var surface = CreateFrutigerAeroDialogSurfaceBrush();

        // ContentDialog's footer and its content presenter are separate surfaces.
        // Paint the content-side layout containers too; styling only the dialog
        // Background leaves the body white while controls inherit the FA typography.
        switch (root)
        {
            case Panel panel:
                panel.Background = surface;
                break;
            case Border border:
                border.Background = surface;
                break;
            case Control control when control is not TextBox && control is not ComboBox:
                control.Background = surface;
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(root);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(root, index) is FrameworkElement child)
            {
                // Preserve input surfaces; only replace default white container
                // surfaces, not TextBox/ComboBox fields or button styling.
                if (child is TextBox || child is ComboBox || child is PasswordBox)
                {
                    continue;
                }

                switch (child)
                {
                    case Panel panel:
                        panel.Background = surface;
                        break;
                    case Border border when border.Background is null
                        || (border.Background is SolidColorBrush solid
                            && solid.Color.A == 255 && solid.Color.R == 255
                            && solid.Color.G == 255 && solid.Color.B == 255):
                        border.Background = surface;
                        break;
                }

                ApplyFrutigerAeroDialogSurface(child);
            }
        }
    }

    private static Brush CreateFrutigerAeroDialogSurfaceBrush() =>
        new LinearGradientBrush
        {
            StartPoint = new Point(0, 0),
            EndPoint = new Point(0, 1),
            GradientStops =
            {
                new GradientStop { Color = ColorHelper.FromArgb(255, 0xBD, 0xEE, 0xFF), Offset = 0 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0xEA, 0xFB, 0xFF), Offset = 0.42 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0xB4, 0xE7, 0xE5), Offset = 0.76 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0x72, 0xC8, 0xC5), Offset = 1 }
            }
        };

    private static void QueueFrutigerAeroDialogTypography(FrameworkElement root, int remainingPasses)
    {
        if (remainingPasses <= 0
            || Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
            || IsDarkThemeActive)
        {
            return;
        }

        root.DispatcherQueue.TryEnqueue(() =>
        {
            if (Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
                || IsDarkThemeActive)
            {
                return;
            }

            ApplyFrutigerAeroTypography(root);
            QueueFrutigerAeroDialogTypography(root, remainingPasses - 1);
        });
    }

    internal static void ApplyThemePreference()
    {
        foreach (var window in ActiveWindows.Values.ToArray())
        {
            ApplyThemeToWindow(window);
            ApplyVisualStyleToWindow(window);
            RefreshThemeResources(window);

            if (window.Content is FrameworkElement content)
            {
                if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
                {
                    QueueY2KTextColorPass(content);
                }
                else if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
                    && !IsDarkThemeActive)
                {
                    ApplyFrutigerAeroTypography(content, preserveSoftwareCardTypography: window is MainWindow);
                }
            }

            if (window is MainWindow mainWindow)
            {
                mainWindow.RefreshSoftwareCardTextColors();
            }

            if (window is SettingsWindow settingsWindow)
            {
                settingsWindow.RefreshAppearance();
            }
        }
    }


    internal static void ApplyFrutigerMetroDarkAppearance(FrameworkElement root)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
            || !IsDarkThemeActive)
        {
            return;
        }

        var font = new FontFamily("ms-appx:///Themes/CutieTopRegular-VArx.ttf#Cutie Top");
        var gold = new SolidColorBrush(ColorHelper.FromArgb(255, 0xFF, 0xC9, 0x28));
        ApplyFrutigerMetroDarkElement(root, font, gold);
    }

    private static void ApplyFrutigerMetroDarkElement(FrameworkElement element, FontFamily font, Brush gold)
    {
        switch (element)
        {
            case TextBlock textBlock:
                if (!(textBlock.FontFamily?.Source?.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase) ?? false))
                {
                    textBlock.FontFamily = font;
                    textBlock.Foreground = gold;
                }
                break;
            case Control control:
                if (!(control.FontFamily?.Source?.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase) ?? false))
                {
                    control.FontFamily = font;
                    control.Foreground = gold;
                }
                control.Background = new SolidColorBrush(ColorHelper.FromArgb(210, 38, 8, 13));
                control.BorderBrush = new SolidColorBrush(ColorHelper.FromArgb(255, 255, 90, 31));
                break;
            case Border border:
                border.Background = new SolidColorBrush(ColorHelper.FromArgb(170, 38, 8, 13));
                border.BorderBrush = new SolidColorBrush(ColorHelper.FromArgb(255, 255, 90, 31));
                border.BorderThickness = new Thickness(1);
                break;
        }

        var childCount = Microsoft.UI.Xaml.Media.VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (Microsoft.UI.Xaml.Media.VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyFrutigerMetroDarkElement(child, font, gold);
            }
        }
    }

    internal static void ClearFrutigerMetroDarkAppearance(FrameworkElement root)
    {
        ClearFrutigerMetroDarkAppearanceCore(root);
    }

    private static void ClearFrutigerMetroDarkAppearanceCore(FrameworkElement element)
    {
        static bool IsMetroGold(Brush? brush) =>
            brush is SolidColorBrush solid && solid.Color.A == 255
            && solid.Color.R == 0xFF && solid.Color.G == 0xC9 && solid.Color.B == 0x28;

        static bool IsMetroPanel(Brush? brush, byte alpha) =>
            brush is SolidColorBrush solid && solid.Color.A == alpha
            && solid.Color.R == 38 && solid.Color.G == 8 && solid.Color.B == 13;

        static bool IsMetroEdge(Brush? brush) =>
            brush is SolidColorBrush solid && solid.Color.R == 255
            && solid.Color.G == 90 && solid.Color.B == 31;

        switch (element)
        {
            case TextBlock textBlock:
                if (textBlock.FontFamily?.Source?.Contains("CutieTopRegular-VArx.ttf", StringComparison.OrdinalIgnoreCase) == true
                    || textBlock.FontFamily?.Source?.Contains("Cutie Top", StringComparison.OrdinalIgnoreCase) == true)
                {
                    textBlock.ClearValue(TextBlock.FontFamilyProperty);
                }
                if (IsMetroGold(textBlock.Foreground))
                {
                    textBlock.ClearValue(TextBlock.ForegroundProperty);
                }
                break;
            case Control control:
                if (control.FontFamily?.Source?.Contains("CutieTopRegular-VArx.ttf", StringComparison.OrdinalIgnoreCase) == true
                    || control.FontFamily?.Source?.Contains("Cutie Top", StringComparison.OrdinalIgnoreCase) == true)
                {
                    control.ClearValue(Control.FontFamilyProperty);
                }
                if (IsMetroGold(control.Foreground))
                {
                    control.ClearValue(Control.ForegroundProperty);
                }
                if (IsMetroPanel(control.Background, 210))
                {
                    control.ClearValue(Control.BackgroundProperty);
                }
                if (IsMetroEdge(control.BorderBrush))
                {
                    control.ClearValue(Control.BorderBrushProperty);
                }
                break;
            case Border border:
                if (IsMetroPanel(border.Background, 170)
                    || IsMetroPanel(border.Background, 205)
                    || IsMetroPanel(border.Background, 210))
                {
                    border.ClearValue(Border.BackgroundProperty);
                }
                if (IsMetroEdge(border.BorderBrush))
                {
                    border.ClearValue(Border.BorderBrushProperty);
                    border.ClearValue(Border.BorderThicknessProperty);
                }
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ClearFrutigerMetroDarkAppearanceCore(child);
            }
        }
    }

    internal static void ApplyThemeToElement(FrameworkElement element)
    {
        ArgumentNullException.ThrowIfNull(element);
        if (element is ContentDialog windows11Dialog)
        {
            EnsureWindows11DialogBackdrop(windows11Dialog);
        }

        var preference = Settings.Current.Theme;
        element.RequestedTheme = preference switch
        {
            WintainiumThemePreference.Light => ElementTheme.Light,
            WintainiumThemePreference.Dark => ElementTheme.Dark,
            _ => GetSystemElementTheme()
        };

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && !IsDarkThemeActive)
        {
            var aeroStyle = new ResourceDictionary
            {
                Source = new Uri("ms-appx:///Themes/FrutigerAero-Light.xaml")
            };
            element.Resources.MergedDictionaries.Add(aeroStyle);
            ApplyFrutigerAeroTypography(element);
            if (element is ContentDialog aeroDialog)
            {
                EnsureFrutigerAeroLightDialogBackdrop(aeroDialog);
                aeroDialog.Loaded -= FrutigerAeroContentDialog_Loaded;
                aeroDialog.Loaded += FrutigerAeroContentDialog_Loaded;
            }
            return;
        }

        if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero
            && IsDarkThemeActive)
        {
            if (element is ContentDialog metroDialog)
            {
                EnsureFrutigerMetroDialogBackdrop(metroDialog);
            }
            ApplyFrutigerMetroDarkAppearance(element);
            if (element is ContentDialog metroDialogForLoaded)
            {
                metroDialogForLoaded.Loaded -= FrutigerMetroContentDialog_Loaded;
                metroDialogForLoaded.Loaded += FrutigerMetroContentDialog_Loaded;
            }
            return;
        }

        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            ClearY2KTextColor(element);
            return;
        }

        var visualStyle = new ResourceDictionary
        {
            Source = new Uri("ms-appx:///Themes/Y2K.xaml")
        };

        element.Resources.MergedDictionaries.Add(visualStyle);

        var themeKey = IsDarkThemeActive ? "Dark" : "Light";

        if (visualStyle.ThemeDictionaries.TryGetValue(themeKey, out var selectedTheme)
            && selectedTheme is ResourceDictionary selectedThemeDictionary)
        {
            var activeTheme = new ResourceDictionary();
            foreach (var key in selectedThemeDictionary.Keys)
            {
                activeTheme[key] = selectedThemeDictionary[key];
            }

            element.Resources.MergedDictionaries.Add(activeTheme);
        }

        if (element is ContentDialog darkY2KDialog && IsDarkThemeActive)
        {
            EnsureY2KDarkTelemetryDialogBackdrop(darkY2KDialog);
            EnsureY2KDarkDialogTelemetryOverlay(darkY2KDialog);
        }

        ApplyY2KTextColor(element);

        if (element is ContentDialog dialog)
        {
            ApplyY2KContentDialogPresentation(dialog);
            dialog.Loaded -= Y2KContentDialog_Loaded;
            dialog.Loaded += Y2KContentDialog_Loaded;
        }
    }

    private static void EnsureY2KDarkDialogTelemetryOverlay(ContentDialog dialog)
    {
        if (dialog.Content is not FrameworkElement content)
        {
            return;
        }

        // Keep the telemetry in the dialog's actual content surface. The ContentDialog
        // template can place opaque background elements over root-level children, which
        // caused the words to disappear when we tried to extend them into the header.
        // This single overlay stays in the body and never paints behind footer buttons.
        var overlayGrid = content as Grid ?? new Grid
        {
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch
        };

        if (content is not Grid)
        {
            dialog.Content = null;
            overlayGrid.Children.Add(content);
            dialog.Content = overlayGrid;
        }

        if (overlayGrid.Children.OfType<Canvas>().Any(canvas => canvas.Name == "Y2KDarkTelemetryCanvas"))
        {
            return;
        }

        var dialogTitle = dialog.Title switch
        {
            string titleText => titleText,
            TextBlock titleBlock => titleBlock.Text,
            _ => dialog.Title?.ToString()
        };
        var normalizedDialogTitle = dialogTitle?.Trim();
        var telemetryLayoutTitle =
            string.Equals(normalizedDialogTitle, "Add Software", StringComparison.OrdinalIgnoreCase)
                ? "Add Software"
                : string.Equals(normalizedDialogTitle, "Sort and Filter", StringComparison.OrdinalIgnoreCase)
                    || string.Equals(normalizedDialogTitle, "Sort & Filter", StringComparison.OrdinalIgnoreCase)
                    ? "Sort and Filter"
                    : null;

        var telemetryCanvas = new Canvas
        {
            Name = "Y2KDarkTelemetryCanvas",
            IsHitTestVisible = false,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch
        };
        var telemetryBackdrop = new Y2KDarkTelemetryBackdrop
        {
            DialogTitle = telemetryLayoutTitle,
            Visibility = Visibility.Visible,
            IsHitTestVisible = false,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch
        };
        telemetryCanvas.Children.Add(telemetryBackdrop);

        void LayoutTelemetryOverlay()
        {
            var width = overlayGrid.ActualWidth;
            var height = overlayGrid.ActualHeight;
            if (width <= 0 || height <= 0)
            {
                return;
            }

            telemetryCanvas.Width = width;
            telemetryCanvas.Height = height;
            telemetryBackdrop.Width = width;
            telemetryBackdrop.Height = height;
            telemetryBackdrop.ClearValue(UIElement.RenderTransformProperty);
        }

        overlayGrid.SizeChanged += (_, _) => LayoutTelemetryOverlay();
        overlayGrid.Loaded += (_, _) => LayoutTelemetryOverlay();
        telemetryCanvas.SizeChanged += (_, _) => LayoutTelemetryOverlay();
        telemetryCanvas.Loaded += (_, _) => LayoutTelemetryOverlay();

        // Insert behind all dialog content controls. Since this is the body grid,
        // the telemetry cannot extend into the header or footer button row.
        overlayGrid.Children.Insert(0, telemetryCanvas);
        LayoutTelemetryOverlay();
    }

    private static void EnsureY2KDarkDialogHeaderTelemetryOverlay(ContentDialog dialog)
    {
        // ContentDialog's private template tree is not a stable extension point: inserting
        // into an arbitrary descendant Panel can target a body/footer panel or a panel
        // whose layout size is zero. Instead, use the public Title object contract and
        // make the title itself a transparent, measured layout host. This guarantees the
        // telemetry is rendered in the actual title presenter, above the existing dialog
        // background, without duplicating the SVG/W artwork or touching the footer.
        if (dialog.Title is Grid existingTitleHost
            && existingTitleHost.Name == "Y2KDarkHeaderTitleHost")
        {
            return;
        }

        var titleText = dialog.Title switch
        {
            string text => text,
            TextBlock textBlock => textBlock.Text,
            _ => dialog.Title?.ToString()
        };
        var normalizedTitle = titleText?.Trim();
        if (!string.Equals(normalizedTitle, "Add Software", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(normalizedTitle, "Sort and Filter", StringComparison.OrdinalIgnoreCase)
            && !string.Equals(normalizedTitle, "Sort & Filter", StringComparison.OrdinalIgnoreCase))
        {
            return;
        }

        var titleHost = new Grid
        {
            Name = "Y2KDarkHeaderTitleHost",
            Height = 62,
            MinHeight = 62,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            Background = TransparentDialogBrush,
            IsHitTestVisible = true
        };

        var telemetryCanvas = new Canvas
        {
            Name = "Y2KDarkHeaderTelemetryCanvas",
            IsHitTestVisible = false,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch
        };

        // The title host is deliberately taller than the default text-only title so
        // two small telemetry rows can occupy the upper header band. The title itself
        // stays readable below them. Coordinates are within the 480px dialog width.
        var placements = new (string Text, double Left, double Top)[] 
        {
            ("W1NTA1N1UM", 8, 3),
            ("M4NAGE", 132, 3),
            ("1NSTALL", 252, 3),
            ("UPD4TE", 365, 3),
            ("5OFTWARE", 22, 21),
            ("V3R1FY", 350, 21)
        };

        foreach (var placement in placements)
        {
            var word = new TextBlock
            {
                Text = placement.Text,
                Foreground = new SolidColorBrush(ColorHelper.FromArgb(78, 0x39, 0xFF, 0x9A)),
                FontFamily = new FontFamily("Consolas"),
                FontSize = 10,
                CharacterSpacing = 100,
                IsHitTestVisible = false
            };
            Canvas.SetLeft(word, placement.Left);
            Canvas.SetTop(word, placement.Top);
            telemetryCanvas.Children.Add(word);
        }

        var titleLabel = new TextBlock
        {
            Text = normalizedTitle.Equals("Sort and Filter", StringComparison.OrdinalIgnoreCase)
                ? "Sort & Filter"
                : normalizedTitle,
            FontFamily = GetY2KDisplayFont(),
            Foreground = GetY2KTextBrush(),
            FontSize = 18,
            FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Bottom,
            HorizontalAlignment = HorizontalAlignment.Left,
            Margin = new Thickness(0, 0, 0, 1),
            IsHitTestVisible = false
        };

        // Add the telemetry first so the title remains the foreground element.
        titleHost.Children.Add(telemetryCanvas);
        titleHost.Children.Add(titleLabel);
        dialog.Title = titleHost;
    }

    private static void Y2KContentDialog_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is ContentDialog dialog && Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K)
        {
            ApplyY2KContentDialogPresentation(dialog);
            if (IsDarkThemeActive)
            {
                // The ContentDialog template does not exist during some initial calls.
                // Retry now that Loaded has fired, then lay telemetry above the template
                // background surface but beneath the dialog controls.
                EnsureY2KDarkTelemetryDialogBackdrop(dialog);
                EnsureY2KDarkDialogTelemetryOverlay(dialog);
                EnsureY2KDarkDialogHeaderTelemetryOverlay(dialog);
                ApplyY2KDarkDialogFooterSurface(dialog);
                ClearY2KDialogInputBorders(dialog);
            }
        }
    }

    private static void ApplyY2KDarkDialogFooterSurface(FrameworkElement element)
    {
        // Keep the action/footer row fully opaque and visually distinct from the
        // upper artwork. This deliberately does not place artwork in the footer.
        if (element.Name is "CommandSpace" or "Button1Host" or "Button2Host" or "Button3Host")
        {
            var footerBrush = new SolidColorBrush(ColorHelper.FromArgb(255, 3, 8, 14));
            if (element is Panel panel)
            {
                panel.Background = footerBrush;
            }
            else if (element is Border border)
            {
                border.Background = footerBrush;
            }

            return;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyY2KDarkDialogFooterSurface(child);
            }
        }
    }

    private static void ClearY2KDialogInputBorders(FrameworkElement element)
    {
        // Y2K Dark's telemetry backdrop is intentionally detailed; remove the
        // default input outlines in these dialogs without changing other themes.
        if (element is TextBox or ComboBox)
        {
            if (element is Control control)
            {
                control.BorderThickness = new Thickness(0);
                control.BorderBrush = TransparentDialogBrush;
            }
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ClearY2KDialogInputBorders(child);
            }
        }
    }

    private static void ApplyY2KContentDialogPresentation(ContentDialog dialog)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            return;
        }

        if (dialog.Resources.TryGetValue("WintainiumY2KButtonStyle", out var buttonStyle)
            && buttonStyle is Style y2kButtonStyle)
        {
            dialog.PrimaryButtonStyle = y2kButtonStyle;
            dialog.SecondaryButtonStyle = y2kButtonStyle;
            dialog.CloseButtonStyle = y2kButtonStyle;
        }

        var textBrush = GetY2KTextBrush();
        var displayFont = GetY2KDisplayFont();
        ApplyY2KContentDialogTypography(dialog, textBrush, displayFont, dialog.CloseButtonStyle);
        ApplyY2KContentDialogButtonAreaBackground(dialog);
    }

    private static void ApplyY2KContentDialogButtonAreaBackground(FrameworkElement element)
    {
        var isButtonArea = element.Name is "CommandSpace" or "Button1Host" or "Button2Host" or "Button3Host";
        if (isButtonArea)
        {
            if (Settings.Current.VisualStyle == WintainiumVisualStyle.Y2K &&
                !IsDarkThemeActive)
            {
                var chromeBrush = GetY2KLightChromeBrush();
                if (element is Panel panel)
                {
                    panel.Background = chromeBrush;
                }
                else if (element is Border border)
                {
                    border.Background = chromeBrush;
                }
            }
            else
            {
                if (element is Panel panel)
                {
                    panel.ClearValue(Panel.BackgroundProperty);
                }
                else if (element is Border border)
                {
                    border.ClearValue(Border.BackgroundProperty);
                }
            }
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyY2KContentDialogButtonAreaBackground(child);
            }
        }
    }

    private static void ApplyY2KContentDialogTypography(
        FrameworkElement element,
        Brush textBrush,
        FontFamily displayFont,
        Style? buttonStyle)
    {
        switch (element)
        {
            case TextBlock textBlock:
                textBlock.Foreground = textBrush;
                textBlock.FontFamily = displayFont;
                break;
            case Button button:
                if (buttonStyle is not null)
                {
                    button.Style = buttonStyle;
                }

                button.Foreground = textBrush;
                button.FontFamily = displayFont;
                break;
            case Control control:
                control.Foreground = textBrush;
                control.FontFamily = displayFont;
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyY2KContentDialogTypography(child, textBrush, displayFont, buttonStyle);
            }
        }
    }

    private static void ClearY2KTextColor(FrameworkElement root)
    {
        ClearY2KTextColorCore(root);
    }

    private static void ClearY2KTextColorCore(FrameworkElement element)
    {
        switch (element)
        {
            case TextBlock textBlock:
                textBlock.ClearValue(TextBlock.ForegroundProperty);
                if (textBlock.FontFamily?.Source is string fontSource &&
                    (fontSource.Equals("Consolas", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Cyberwave2000-Regular.otf", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Horatio%20D%20Regular.ttf", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Horatio D Regular.ttf", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Horatio D", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("CutieTopRegular-VArx.ttf", StringComparison.OrdinalIgnoreCase) ||
                     fontSource.Contains("Cutie Top", StringComparison.OrdinalIgnoreCase)))
                {
                    textBlock.ClearValue(TextBlock.FontFamilyProperty);
                }
                break;
            case Control control:
                control.ClearValue(Control.ForegroundProperty);
                if (control.FontFamily?.Source is string controlFontSource &&
                    (controlFontSource.Equals("Consolas", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Cyberwave2000-Regular.otf", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Horatio%20D%20Regular.ttf", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Horatio D Regular.ttf", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Horatio D", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("CutieTopRegular-VArx.ttf", StringComparison.OrdinalIgnoreCase) ||
                     controlFontSource.Contains("Cutie Top", StringComparison.OrdinalIgnoreCase)))
                {
                    control.ClearValue(Control.FontFamilyProperty);
                }
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ClearY2KTextColorCore(child);
            }
        }
    }

    internal static void ApplyFrutigerAeroTypography(
        FrameworkElement root,
        bool preserveSoftwareCardTypography = false)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero
            || IsDarkThemeActive)
        {
            return;
        }

        var font = new FontFamily("ms-appx:///Horatio%20D%20Regular.ttf#Horatio D");
        var textBrush = new SolidColorBrush(ColorHelper.FromArgb(255, 0x17, 0x4F, 0x67));
        var visited = new HashSet<FrameworkElement>();
        ApplyFrutigerAeroTypographyCore(root, font, textBrush, visited,
            preserveSoftwareCardTypography);
    }

    private static void ApplyFrutigerAeroTypographyCore(
        FrameworkElement element,
        FontFamily font,
        Brush textBrush,
        HashSet<FrameworkElement> visited,
        bool isMainWindowRoot)
    {
        if (!visited.Add(element))
        {
            return;
        }

        switch (element)
        {
            case TextBlock textBlock:
                if (!(textBlock.FontFamily?.Source?.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase) ?? false))
                {
                    textBlock.FontFamily = font;
                    textBlock.Foreground = textBrush;
                    textBlock.FontSize = Math.Max(textBlock.FontSize, 16);
                }
                break;
            case Control control:
                control.FontFamily = font;
                control.Foreground = textBrush;
                control.FontSize = Math.Max(control.FontSize, 16);
                break;
        }

        // ComboBox items may be detached from the visual tree while a popup is closed.
        if (element is ComboBox comboBox)
        {
            // ComboBox headers and item elements can be outside the visual tree
            // while a popup is closed, so style them explicitly as well.
            if (comboBox.Header is FrameworkElement headerElement)
            {
                ApplyFrutigerAeroTypographyCore(headerElement, font, textBrush, visited, false);
            }

            foreach (var item in comboBox.Items)
            {
                if (item is FrameworkElement itemElement)
                {
                    ApplyFrutigerAeroTypographyCore(itemElement, font, textBrush, visited, false);
                }
            }
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyFrutigerAeroTypographyCore(child, font, textBrush, visited, isMainWindowRoot);
            }
        }
    }

    internal static void ApplyY2KTextColor(FrameworkElement root)
    {
        if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            return;
        }

        ApplyY2KTextColor(root, GetY2KTextBrush(), GetY2KDisplayFont());
    }

    private static void QueueY2KTextColorPass(FrameworkElement root, int remainingPasses = 8)
    {
        if (remainingPasses <= 0 || Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
        {
            return;
        }

        root.DispatcherQueue.TryEnqueue(() =>
        {
            if (Settings.Current.VisualStyle != WintainiumVisualStyle.Y2K)
            {
                return;
            }

            ApplyY2KTextColor(root);
            QueueY2KTextColorPass(root, remainingPasses - 1);
        });
    }

    private static void ApplyY2KTextColor(FrameworkElement element, Brush brush, FontFamily font)
    {
        switch (element)
        {
            case TextBlock textBlock:
                textBlock.Foreground = brush;
                if (textBlock.FontFamily?.Source is not string fontSource ||
                    !fontSource.Contains("Segoe MDL2 Assets", StringComparison.OrdinalIgnoreCase))
                {
                    textBlock.FontFamily = font;
                }
                break;
            case Control control:
                control.Foreground = brush;
                control.FontFamily = font;
                break;
        }

        var childCount = VisualTreeHelper.GetChildrenCount(element);
        for (var index = 0; index < childCount; index++)
        {
            if (VisualTreeHelper.GetChild(element, index) is FrameworkElement child)
            {
                ApplyY2KTextColor(child, brush, font);
            }
        }
    }

    internal static Brush GetY2KLightChromeBrush()
    {
        return new LinearGradientBrush
        {
            StartPoint = new Windows.Foundation.Point(0, 0),
            EndPoint = new Windows.Foundation.Point(0, 1),
            GradientStops =
            {
                new GradientStop { Color = ColorHelper.FromArgb(255, 0xF4, 0xF7, 0xF9), Offset = 0 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0xC7, 0xD2, 0xD9), Offset = 0.22 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0x71, 0x82, 0x8C), Offset = 0.48 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0xD9, 0xE2, 0xE7), Offset = 0.70 },
                new GradientStop { Color = ColorHelper.FromArgb(255, 0x8A, 0x9A, 0xA4), Offset = 1 }
            }
        };
    }

    internal static Brush GetY2KLightChromeEdgeBrush() =>
        new SolidColorBrush(ColorHelper.FromArgb(255, 0x60, 0x78, 0x87));

    internal static Brush GetY2KTextBrush()
    {
        if (IsDarkThemeActive)
        {
            return new SolidColorBrush(ColorHelper.FromArgb(255, 0x39, 0xFF, 0x9A));
        }

        if (Application.Current.Resources.TryGetValue("WintainiumY2KTextBrush", out var resource)
            && resource is Brush brush)
        {
            return brush;
        }

        return new SolidColorBrush(ColorHelper.FromArgb(255, 0x76, 0x5C, 0xFF));
    }

    internal static FontFamily GetY2KDisplayFont()
    {
        return IsDarkThemeActive
            ? new FontFamily("Consolas")
            : new FontFamily("ms-appx:///Cyberwave2000-Regular.otf#Cyberwave 2000");
    }

    internal static void ApplyThemeToWindow(Window window)
    {
        if (window.Content is not FrameworkElement content)
        {
            return;
        }

        var preference = Settings.Current.Theme;
        var theme = preference switch
        {
            WintainiumThemePreference.Light => ElementTheme.Light,
            WintainiumThemePreference.Dark => ElementTheme.Dark,
            _ => GetSystemElementTheme()
        };

        content.RequestedTheme = theme;
    }

    private static ElementTheme GetSystemElementTheme()
    {
        var color = new UISettings().GetColorValue(UIColorType.Foreground);
        var luminance = (0.299 * color.R) + (0.587 * color.G) + (0.114 * color.B);
        return luminance >= 128 ? ElementTheme.Dark : ElementTheme.Light;
    }

    private static void SystemColors_Changed(UISettings sender, object args)
    {
        if (Settings.Current.Theme != WintainiumThemePreference.System)
        {
            return;
        }

        foreach (var window in ActiveWindows.Values.ToArray())
        {
            if (window.Content is FrameworkElement content)
            {
                content.DispatcherQueue.TryEnqueue(() =>
                {
                    ApplyThemeToWindow(window);
                    ApplyVisualStyleToWindow(window);
                    RefreshThemeResources(window);
                    if (Settings.Current.VisualStyle == WintainiumVisualStyle.FrutigerAero)
                    {
                        if (IsDarkThemeActive)
                        {
                            ApplyFrutigerMetroDarkAppearance(content);
                        }
                        else
                        {
                            ApplyFrutigerAeroTypography(content, preserveSoftwareCardTypography: window is MainWindow);
                        }
                    }

                    if (window is SettingsWindow settingsWindow)
                    {
                        settingsWindow.RefreshAppearance();
                    }

                    if (window is MainWindow mainWindow)
                    {
                        mainWindow.ApplyWindowChromeForCurrentVisualStyle();
                    }
                });
            }
        }
    }

    private async void MainWindow_Closed(object sender, WindowEventArgs args)
    {
        if (!ReferenceEquals(sender, _window))
        {
            return;
        }

        _window = null;

        if (_services is not null)
        {
            await _services.DisposeAsync();
            _services = null;
        }

        Exit();
    }
}
