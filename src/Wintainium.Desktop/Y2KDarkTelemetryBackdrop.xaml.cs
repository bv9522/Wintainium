using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media.Animation;
using System.Collections.Generic;

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
                // Dialogs have a shorter content viewport than the main window.
                // Use a modestly smaller, still legible 9–10px size here; keep the
                // glyphs unscaled and let their positions follow the available height.
                readouts[i].FontSize = originalFontSizes[i] - 2;
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

        // Fourteen distinct vertical bands give the words finer placement control
        // across short dialogs. More rows means each word can sit at its own vertical
        // level instead of repeatedly sharing one of only ten bands.
        while (TelemetryGrid.RowDefinitions.Count < 14)
        {
            TelemetryGrid.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        }
        // Four columns give each label enough horizontal room at dialog scale.
        // Six columns made long words cross neighboring cells and visually collide.
        while (TelemetryGrid.ColumnDefinitions.Count < 4)
        {
            TelemetryGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        }

        var isAddSoftware = string.Equals(_dialogTitle, "Add Software", StringComparison.OrdinalIgnoreCase);
        // Alternate labels across the full content height instead of bunching them
        // into the same few vertical bands. Add Software uses all 24 readouts;
        // Sort & Filter uses 20 to keep its smaller dialog less busy.
        int[] rows =
        {
            0, 7, 2, 10, 4, 12, 1, 8, 5, 13, 3, 9,
            6, 11, 0, 7, 2, 10, 4, 12, 1, 8, 5, 13
        };
        // Each visible word gets a unique row/column slot. The prior six-column
        // map reused (row 1, column 4), (row 2, column 2), and (row 7, column 3),
        // stacking words on top of each other; Add Software exposed all three.
        int[] columns =
        {
            0, 1, 2, 3, 1, 2, 3, 0, 2, 3, 0, 1,
            3, 0, 2, 3, 0, 1, 3, 0, 1, 2, 1, 2
        };
        var visibleCount = isAddSoftware ? 24 : 20;
        var isSortAndFilter = string.Equals(_dialogTitle, "Sort and Filter", StringComparison.OrdinalIgnoreCase)
            || string.Equals(_dialogTitle, "Sort & Filter", StringComparison.OrdinalIgnoreCase);
        var showGridFillNumbers = isAddSoftware || isSortAndFilter;
        var testCellLabels = new List<(TextBlock Label, int Row, int Column)>();
        if (showGridFillNumbers)
        {
            var occupiedCells = new bool[14, 4];
            for (var i = 0; i < visibleCount; i++)
            {
                occupiedCells[rows[i], columns[i]] = true;
            }

            // Temporary grid-extent test: preserve every existing word in its current
            // cell and put a numbered marker only in cells that otherwise have no word.
            // This diagnostic fill is intentionally limited to Add Software and
            // Sort and Filter; other dialogs and the main window remain unchanged.
            for (var row = 0; row < 14; row++)
            {
                for (var column = 0; column < 4; column++)
                {
                    if (occupiedCells[row, column])
                    {
                        continue;
                    }

                    var marker = new TextBlock
                    {
                        Text = (row * 4 + column + 1).ToString("00"),
                        Foreground = readouts[0].Foreground,
                        FontFamily = readouts[0].FontFamily,
                        FontSize = 9,
                        Opacity = 0.78,
                        IsHitTestVisible = false,
                        TextWrapping = TextWrapping.NoWrap
                    };
                    testCellLabels.Add((marker, row, column));
                }
            }
        }

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
            Canvas.SetTop(readouts[i], rows[i] * 10.0 + (i % 2 == 0 ? 1 : 4));
        }

        foreach (var testCell in testCellLabels)
        {
            dialogCanvas.Children.Add(testCell.Label);
        }

        TelemetryGrid.Children.Add(dialogCanvas);

        // A Canvas has no intrinsic desired size. When a ContentDialog measures its
        // body with unconstrained height, relying on Canvas.SizeChanged can leave its
        // coordinate space much shorter than the visible content viewport. Drive the
        // overlay from the stretched parent grid instead and explicitly size the Canvas.
        void LayoutDialogTelemetry(double width, double height)
        {
            if (width <= 0 || height <= 0)
            {
                return;
            }

            dialogCanvas.Width = width;
            dialogCanvas.Height = height;
            var cellWidth = width / 4.0;
            var cellHeight = height / 14.0;
            for (var i = 0; i < visibleCount; i++)
            {
                var label = readouts[i];
                var left = columns[i] * cellWidth;
                // Distribute words across fourteen vertical bands spanning the actual
                // measured content height, from the top through the bottom of the body.
                var top = rows[i] * cellHeight + (i % 2 == 0 ? 2 : cellHeight * 0.12);
                var widthRemaining = Math.Max(0, width - left - 4);
                var desiredLabelWidth = Math.Max(40, (label.Text?.Length ?? 0) * 6.5 + 8);
                // Keep labels within their own column. The six-column layout allowed
                // long strings to overlap adjacent words even when their coordinates
                // were distinct.
                label.Width = Math.Min(
                    desiredLabelWidth,
                    Math.Min(widthRemaining, Math.Max(40, cellWidth - 8)));
                Canvas.SetLeft(label, left);
                Canvas.SetTop(label, Math.Min(top, Math.Max(0, height - label.FontSize - 4)));
            }

            foreach (var testCell in testCellLabels)
            {
                var marker = testCell.Label;
                marker.Width = Math.Min(32, Math.Max(24, cellWidth - 8));
                Canvas.SetLeft(marker, testCell.Column * cellWidth + 4);
                var markerTop = testCell.Row * cellHeight + Math.Max(0, (cellHeight - marker.FontSize) / 2);
                Canvas.SetTop(marker, Math.Min(markerTop, Math.Max(0, height - marker.FontSize - 2)));
            }
        }

        TelemetryGrid.SizeChanged += (_, args) =>
            LayoutDialogTelemetry(args.NewSize.Width, args.NewSize.Height);
        TelemetryGrid.Loaded += (_, _) =>
            LayoutDialogTelemetry(TelemetryGrid.ActualWidth, TelemetryGrid.ActualHeight);
        dialogCanvas.Loaded += (_, _) =>
            LayoutDialogTelemetry(TelemetryGrid.ActualWidth, TelemetryGrid.ActualHeight);
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
