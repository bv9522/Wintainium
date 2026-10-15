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
                // Grid cells impose a narrow layout slot (one sixth of the dialog
                // width). Give each label enough intrinsic width for its full word;
                // otherwise long telemetry strings can look sliced at an invisible
                // column boundary even when wrapping and trimming are disabled.
                readouts[i].Width = Math.Max(40, (readouts[i].Text?.Length ?? 0) * 6.5 + 8);
            }
            else
            {
                readouts[i].FontSize = originalFontSizes[i];
                readouts[i].CharacterSpacing = 100;
                readouts[i].Width = double.NaN;
            }
        }

        // Main-window telemetry remains on its original compact 6x4 grid.
        // Dialog labels use a Canvas instead of Grid cells: Grid column boundaries
        // can constrain or clip long labels even when TextBlock.Width is explicit.
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
        // Use the full height of the dialog for the telemetry instead of leaving
        // the upper and lower rows mostly empty. Add Software gets all 24 readouts;
        // Sort & Filter gets 20 to keep its smaller dialog a little less busy.
        int[] rows = isAddSoftware
            ? new[] { 0, 7, 0, 7, 1, 6, 1, 6, 2, 5, 2, 5, 3, 4, 3, 4, 0, 7, 1, 6, 2, 5, 0, 7 }
            : new[] { 0, 7, 0, 7, 1, 6, 1, 6, 2, 5, 2, 5, 3, 4, 0, 7, 1, 6, 2, 5, 3, 4, 0, 7 };
        int[] columns = isAddSoftware
            ? new[] { 0, 5, 2, 3, 1, 4, 4, 1, 0, 5, 2, 3, 1, 4, 4, 1, 3, 2, 5, 0, 4, 1, 2, 3 }
            : new[] { 0, 5, 2, 3, 1, 4, 4, 1, 0, 5, 2, 3, 1, 4, 4, 1, 3, 2, 5, 0, 4, 1, 2, 3 };
        var visibleCount = isAddSoftware ? 24 : 20;

        var dialogCanvas = new Canvas
        {
            IsHitTestVisible = false,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch
        };
        Grid.SetRowSpan(dialogCanvas, TelemetryGrid.RowDefinitions.Count);
        Grid.SetColumnSpan(dialogCanvas, TelemetryGrid.ColumnDefinitions.Count);
        for (var i = 0; i < readouts.Length; i++)
        {
            TelemetryGrid.Children.Remove(readouts[i]);
            dialogCanvas.Children.Add(readouts[i]);
            if (i >= visibleCount)
            {
                readouts[i].Visibility = Visibility.Collapsed;
                continue;
            }

            readouts[i].Width = Math.Min(
                Math.Max(40, (readouts[i].Text?.Length ?? 0) * 6.5 + 8),
                190);
            readouts[i].HorizontalAlignment = HorizontalAlignment.Left;
            readouts[i].VerticalAlignment = VerticalAlignment.Top;
            readouts[i].Visibility = Visibility.Visible;
            Canvas.SetLeft(readouts[i], columns[i] * 100.0);
            Canvas.SetTop(readouts[i], rows[i] * 12.5 + (i % 2 == 0 ? 1 : 4));
        }

        TelemetryGrid.Children.Add(dialogCanvas);
        dialogCanvas.SizeChanged += (_, args) =>
        {
            var cellWidth = args.NewSize.Width / 6.0;
            var cellHeight = args.NewSize.Height / 8.0;
            for (var i = 0; i < visibleCount; i++)
            {
                var label = readouts[i];
                var left = columns[i] * cellWidth;
                var top = rows[i] * cellHeight + (i % 2 == 0 ? 2 : cellHeight * 0.35);
                var width = Math.Min(label.Width, Math.Max(0, args.NewSize.Width - left - 4));
                label.Width = width;
                Canvas.SetLeft(label, left);
                Canvas.SetTop(label, top);
            }
        };
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
