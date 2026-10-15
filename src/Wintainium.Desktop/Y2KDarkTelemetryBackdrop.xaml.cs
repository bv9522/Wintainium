using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Animation;

namespace Wintainium.Desktop;

public sealed partial class Y2KDarkTelemetryBackdrop : UserControl
{
    private string? _dialogTitle;

    public string? DialogTitle
    {
        get => _dialogTitle;
        set
        {
            _dialogTitle = value;
            if (TelemetryGrid is not null)
            {
                ApplyDialogSpacing();
            }
        }
    }

    public Y2KDarkTelemetryBackdrop()
    {
        InitializeComponent();
        InitializeAnimations();
    }

    private void ApplyDialogSpacing()
    {
        var readouts = new TextBlock[]
        {
            HexReadout1, HexReadout2, HexReadout3, HexReadout4,
            HexReadout5, HexReadout6, HexReadout7, HexReadout8,
            HexReadout9, HexReadout10, HexReadout11, HexReadout12,
            HexReadout13, HexReadout14, HexReadout15, HexReadout16,
            HexReadout17, HexReadout18, HexReadout19, HexReadout20,
            HexReadout21, HexReadout22, HexReadout23, HexReadout24
        };

        // Dialog cells are narrower than the main-window telemetry cells. Fit each
        // dialog label inside its assigned cell instead of relying on font-size changes
        // alone: inherited XAML margins and edge alignment can still clip a whole word.
        // The main window retains its exact authored sizes, spacing, alignment, and margins.
        int[] originalFontSizes = { 12, 11, 12, 11, 11, 12, 12, 11, 12, 11, 12, 11, 11, 12, 11, 12, 11, 12, 12, 11, 11, 12, 11, 12 };
        var isDialogLayout = !string.IsNullOrWhiteSpace(_dialogTitle);
        for (var i = 0; i < readouts.Length; i++)
        {
            if (isDialogLayout)
            {
                readouts[i].FontSize = 8;
                readouts[i].CharacterSpacing = 0;
                readouts[i].Margin = new Thickness(2);
                readouts[i].TextWrapping = TextWrapping.NoWrap;
                readouts[i].TextTrimming = TextTrimming.None;
            }
            else
            {
                readouts[i].FontSize = originalFontSizes[i];
                readouts[i].CharacterSpacing = 100;
            }
        }

        // Main-window telemetry remains on its original compact 6x4 grid.
        // Dialogs use a dedicated 8x6 grid with title-specific density.
        if (!isDialogLayout)
        {
            int[] compactRows = { 1, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5 };
            int[] compactColumns = { 2, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3 };
            for (var i = 0; i < readouts.Length; i++)
            {
                Grid.SetRow(readouts[i], compactRows[i]);
                Grid.SetColumn(readouts[i], compactColumns[i]);
                readouts[i].Visibility = Visibility.Visible;
            }
            return;
        }

        while (TelemetryGrid.RowDefinitions.Count < 8)
        {
            TelemetryGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        }
        while (TelemetryGrid.ColumnDefinitions.Count < 6)
        {
            TelemetryGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        }

        var isAddSoftware = string.Equals(_dialogTitle, "Add Software", StringComparison.OrdinalIgnoreCase);

        // Add Software has more open vertical space, so use 20 readouts distributed
        // across the full 8x6 canvas. Sort and Filter gets a calmer 14-readout pattern.
        int[] rows = isAddSoftware
            ? new[] { 0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5, 6, 6, 7, 7, 0, 2, 5, 7 }
            : new[] { 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 0, 2, 4, 6, 1, 3, 5, 7, 1, 7 };
        int[] columns = isAddSoftware
            ? new[] { 0, 4, 1, 5, 0, 2, 4, 1, 3, 5, 0, 2, 4, 1, 3, 5, 0, 4, 1, 5, 2, 5, 2, 3 }
            : new[] { 0, 4, 1, 5, 0, 4, 1, 5, 0, 4, 1, 5, 0, 4, 2, 3, 2, 3, 0, 5, 0, 5, 2, 3 };
        var visibleCount = isAddSoftware ? 20 : 14;

        for (var i = 0; i < readouts.Length; i++)
        {
            Grid.SetRow(readouts[i], rows[i]);
            Grid.SetColumn(readouts[i], columns[i]);
            readouts[i].Visibility = i < visibleCount ? Visibility.Visible : Visibility.Collapsed;
        }
    }

    private void InitializeAnimations()
    {
        var readouts = new TextBlock[]
        {
            HexReadout1, HexReadout2, HexReadout3, HexReadout4,
            HexReadout5, HexReadout6, HexReadout7, HexReadout8,
            HexReadout9, HexReadout10, HexReadout11, HexReadout12,
            HexReadout13, HexReadout14, HexReadout15, HexReadout16,
            HexReadout17, HexReadout18, HexReadout19, HexReadout20,
            HexReadout21, HexReadout22, HexReadout23, HexReadout24
        };

        for (var index = 0; index < readouts.Length; index++)
        {
            var animation = new DoubleAnimation
            {
                From = 0.16,
                To = index % 3 == 0 ? 0.62 : 0.46,
                Duration = new Duration(TimeSpan.FromSeconds(2.8 + (index % 4) * 0.45)),
                AutoReverse = true,
                RepeatBehavior = RepeatBehavior.Forever,
                BeginTime = TimeSpan.FromSeconds(index * 0.42)
            };
            Storyboard.SetTarget(animation, readouts[index]);
            Storyboard.SetTargetProperty(animation, "Opacity");
            var storyboard = new Storyboard();
            storyboard.Children.Add(animation);
            storyboard.Begin();
        }
    }
}
