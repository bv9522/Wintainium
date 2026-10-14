using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Animation;

namespace Wintainium.Desktop;

public sealed partial class Y2KDarkTelemetryBackdrop : UserControl
{
    private bool _useExpandedDialogSpacing;

    public bool UseExpandedDialogSpacing
    {
        get => _useExpandedDialogSpacing;
        set
        {
            if (_useExpandedDialogSpacing == value)
            {
                return;
            }

            _useExpandedDialogSpacing = value;
            if (TelemetryGrid is not null && value)
            {
                ApplyExpandedDialogSpacing();
            }
        }
    }

    public Y2KDarkTelemetryBackdrop()
    {
        InitializeComponent();
        InitializeAnimations();
    }

    private void ApplyExpandedDialogSpacing()
    {
        // The main-window telemetry keeps the original compact 6x4 layout.
        // Only ContentDialog instances opt into this expanded 8x6 arrangement.
        while (TelemetryGrid.RowDefinitions.Count < 8)
        {
            TelemetryGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        }

        while (TelemetryGrid.ColumnDefinitions.Count < 6)
        {
            TelemetryGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        }

        int[] expandedRows = { 1, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5 };
        int[] expandedColumns = { 3, 1, 3, 4, 0, 1, 3, 4, 0, 1, 3, 4, 0, 1, 3, 4, 0, 1, 3, 4, 0, 1, 3, 4 };
        TextBlock[] readouts =
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
            Grid.SetRow(readouts[index], expandedRows[index]);
            Grid.SetColumn(readouts[index], expandedColumns[index]);
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
