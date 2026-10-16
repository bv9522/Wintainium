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

        // Twelve evenly sized vertical bands give each pair of words its own row.
        while (TelemetryGrid.RowDefinitions.Count < 12)
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
        // Add Software leaves the five header terms out of the body and uses a quieter
        // 16-word field, reducing clutter around the central W. Sort & Filter retains
        // its existing 20-word treatment.
        int[] rows =
        {
            0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5,
            6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11
        };
        int[] columns =
        {
            0, 2, 1, 3, 0, 2, 1, 3, 0, 2, 1, 3,
            0, 2, 1, 3, 0, 2, 1, 3, 0, 2, 1, 3
        };
        int[] visibleIndices = isAddSoftware
            ? new[] { 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 }
            : new[] { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 };
        var visibleCount = visibleIndices.Length;
        var layoutRowCount = visibleCount / 2;

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
            if (Array.IndexOf(visibleIndices, i) < 0)
            {
                readouts[i].Visibility = Visibility.Collapsed;
                continue;
            }

            readouts[i].Visibility = Visibility.Visible;
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
            var cellHeight = height / layoutRowCount;
            for (var slot = 0; slot < visibleCount; slot++)
            {
                var index = visibleIndices[slot];
                var label = readouts[index];
                var left = columns[slot] * cellWidth;
                var top = rows[slot] * cellHeight + (slot % 2 == 0 ? 2 : cellHeight * 0.12);
                var widthRemaining = Math.Max(0, width - left - 4);
                var desiredLabelWidth = Math.Max(40, (label.Text?.Length ?? 0) * 6.5 + 8);
                // Keep labels within their own column to prevent neighboring words colliding.
                label.Width = Math.Min(
                    desiredLabelWidth,
                    Math.Min(widthRemaining, Math.Max(40, cellWidth - 8)));
                Canvas.SetLeft(label, left);
                Canvas.SetTop(label, Math.Min(top, Math.Max(0, height - label.FontSize - 4)));
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
