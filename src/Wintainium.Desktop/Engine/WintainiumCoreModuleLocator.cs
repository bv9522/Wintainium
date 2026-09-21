namespace Wintainium.Desktop.Engine;

internal static class WintainiumCoreModuleLocator
{
    public static string Locate()
    {
        foreach (var root in CandidateRoots())
        {
            var path = Path.Combine(root, "core", "Wintainium.Core", "Wintainium.Core.psd1");
            if (File.Exists(path))
            {
                return Path.GetFullPath(path);
            }
        }

        throw new FileNotFoundException(
            "Wintainium.Core could not be located. The desktop application expects the Core module under the release package's core/Wintainium.Core directory.");
    }

    private static IEnumerable<string> CandidateRoots()
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var startingPoint in new[]
        {
            AppContext.BaseDirectory,
            Environment.CurrentDirectory
        })
        {
            var directory = new DirectoryInfo(startingPoint);
            while (directory is not null)
            {
                if (seen.Add(directory.FullName))
                {
                    yield return directory.FullName;
                }

                directory = directory.Parent;
            }
        }
    }
}