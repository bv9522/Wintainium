using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

if (args.Length != 2)
{
    Console.Error.WriteLine("Usage: Wintainium.IconGenerator <source.png> <output.ico>");
    return 2;
}

var sourcePath = Path.GetFullPath(args[0]);
var outputPath = Path.GetFullPath(args[1]);
if (!File.Exists(sourcePath))
{
    Console.Error.WriteLine($"Source icon not found: {sourcePath}");
    return 3;
}

using var source = new Bitmap(sourcePath);
var sizes = new[] { 16, 24, 32, 48, 64, 128, 256 };
var images = sizes.Select(size => CreateIconDib(source, size)).ToArray();
Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);

using var output = File.Create(outputPath);
using var writer = new BinaryWriter(output, Encoding.UTF8, leaveOpen: false);
writer.Write((ushort)0);
writer.Write((ushort)1);
writer.Write((ushort)images.Length);

var dataOffset = 6 + images.Length * 16;
for (var index = 0; index < images.Length; index++)
{
    var size = sizes[index];
    writer.Write((byte)(size == 256 ? 0 : size));
    writer.Write((byte)(size == 256 ? 0 : size));
    writer.Write((byte)0);
    writer.Write((byte)0);
    writer.Write((ushort)1);
    writer.Write((ushort)32);
    writer.Write((uint)images[index].Length);
    writer.Write((uint)dataOffset);
    dataOffset += images[index].Length;
}

foreach (var image in images)
{
    writer.Write(image);
}

return 0;

static byte[] CreateIconDib(Bitmap source, int size)
{
    using var canvas = new Bitmap(size, size, PixelFormat.Format32bppArgb);
    using (var graphics = Graphics.FromImage(canvas))
    {
        graphics.Clear(Color.Transparent);
        graphics.CompositingMode = CompositingMode.SourceCopy;
        graphics.CompositingQuality = CompositingQuality.HighQuality;
        graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
        graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
        var scale = Math.Min(size * 0.90 / source.Width, size * 0.90 / source.Height);
        var width = Math.Max(1, (int)Math.Round(source.Width * scale));
        var height = Math.Max(1, (int)Math.Round(source.Height * scale));
        var destination = new Rectangle((size - width) / 2, (size - height) / 2, width, height);
        graphics.DrawImage(source, destination);
    }

    var xorLength = size * size * 4;
    var maskStride = ((size + 31) / 32) * 4;
    var dib = new byte[40 + xorLength + maskStride * size];

    using (var stream = new MemoryStream(dib, writable: true))
    using (var writer = new BinaryWriter(stream))
    {
        writer.Write((uint)40);
        writer.Write(size);
        writer.Write(size * 2);
        writer.Write((ushort)1);
        writer.Write((ushort)32);
        writer.Write((uint)0);
        writer.Write((uint)xorLength);
        writer.Write(0);
        writer.Write(0);
        writer.Write((uint)0);
        writer.Write((uint)0);
    }

    var offset = 40;
    for (var y = size - 1; y >= 0; y--)
    {
        for (var x = 0; x < size; x++)
        {
            var pixel = canvas.GetPixel(x, y);
            dib[offset++] = pixel.B;
            dib[offset++] = pixel.G;
            dib[offset++] = pixel.R;
            dib[offset++] = pixel.A;
        }
    }

    // The all-zero AND mask is correct because every icon image carries an alpha channel.
    return dib;
}
