using Wintainium.Desktop.Engine;
using Wintainium.Desktop.Models;

if (args.Length != 1)
{
    Console.Error.WriteLine("Usage: dotnet run -- <path-to-Wintainium.Core.psd1>");
    return 2;
}

var modulePath = Path.GetFullPath(args[0]);

await using var host = new WintainiumPowerShellHost(modulePath);
var client = new WintainiumCoreClient(host);

var collectionService = new WintainiumApplicationCollectionService(client);
var collectionResult = await collectionService.LoadAsync(Path.GetDirectoryName(modulePath)!);

if (collectionResult.Applications.Count != 0 ||
    !collectionResult.IsSuccessful ||
    collectionResult.Errors.Count != 0 ||
    collectionResult.Warnings.Count != 0)
{
    Console.Error.WriteLine("Unexpected application collection service result for the repository Core directory.");
    return 1;
}

var result = await client.GetManifestsAsync(Path.GetDirectoryName(modulePath)!);

if (result.CommandName != "Get-WintainiumManifest")
{
    Console.Error.WriteLine("Unexpected command name.");
    return 1;
}

if (result.WasCancelled)
{
    Console.Error.WriteLine("Manifest discovery was unexpectedly cancelled.");
    return 1;
}

if (result.Output.Count != 1)
{
    Console.Error.WriteLine($"Expected one structured result, received {result.Output.Count}.");
    return 1;
}

var output = result.Output[0];

var requiredProperties = new[]
{
    "OperationId",
    "IsSuccessful",
    "Candidates",
    "ManifestPaths",
    "Manifests",
    "Errors",
    "Warnings",
    "LogEvents"
};

foreach (var propertyName in requiredProperties)
{
    if (output.Properties[propertyName] is null)
    {
        Console.Error.WriteLine($"Missing required public result property: {propertyName}");
        return 1;
    }
}

var collection = WintainiumApplicationModelMapper.MapManifestResult(output);
if (collection.Applications.Count != 0 ||
    !collection.IsSuccessful ||
    collection.OperationId.Length == 0 ||
    collection.Errors.Count != 0 ||
    collection.Warnings.Count != 0)
{
    Console.Error.WriteLine("Unexpected application collection mapping for the repository Core directory.");
    return 1;
}

var syntheticManifest = System.Management.Automation.PSObject.AsPSObject(
    new
    {
        Id = "org.example.app",
        Name = "Example App",
        Description = "Example description",
        Homepage = "https://example.com/",
        Publisher = "Example Publisher",
        Source = new { PluginId = "Wintainium.provider.example" }
    });

var syntheticResult = System.Management.Automation.PSObject.AsPSObject(
    new
    {
        OperationId = Guid.NewGuid().ToString(),
        IsSuccessful = true,
        Manifests = new[] { syntheticManifest },
        Errors = Array.Empty<object>(),
        Warnings = Array.Empty<object>()
    });

var syntheticCollection = WintainiumApplicationModelMapper.MapManifestResult(syntheticResult);
if (syntheticCollection.Applications.Count != 1 ||
    syntheticCollection.Applications[0].ApplicationId != "org.example.app" ||
    syntheticCollection.Applications[0].Name != "Example App" ||
    syntheticCollection.Applications[0].InstallationState != WintainiumInstallationState.Unknown ||
    syntheticCollection.Applications[0].UpdateStatus != WintainiumUpdateStatus.Unknown ||
    syntheticCollection.Applications[0].InstalledVersion is not null)
{
    Console.Error.WriteLine("Application model mapping did not preserve the required initial Unknown state.");
    return 1;
}

var queryApplications = new[]
{
    new WintainiumApplicationModel(
        "org.example.zeta",
        "Zeta",
        null,
        null,
        null,
        null,
        WintainiumInstallationState.Unknown,
        null,
        null,
        WintainiumUpdateStatus.Unknown,
        "provider.z"),
    new WintainiumApplicationModel(
        "org.example.alpha",
        "Alpha",
        null,
        null,
        null,
        null,
        WintainiumInstallationState.Installed,
        "1.0.0",
        null,
        WintainiumUpdateStatus.UpToDate,
        "provider.a"),
    new WintainiumApplicationModel(
        "org.example.beta",
        "Beta",
        null,
        null,
        null,
        null,
        WintainiumInstallationState.NotInstalled,
        null,
        null,
        WintainiumUpdateStatus.UpdateAvailable,
        "provider.b")
};

var sortedApplications = WintainiumApplicationCollectionQuery.Apply(
    queryApplications,
    new WintainiumApplicationQuery(WintainiumApplicationSort.NameAscending));
if (sortedApplications.Count != 3 ||
    sortedApplications[0].Name != "Alpha" ||
    sortedApplications[1].Name != "Beta" ||
    sortedApplications[2].Name != "Zeta")
{
    Console.Error.WriteLine("Application collection name sorting failed.");
    return 1;
}

var installedApplications = WintainiumApplicationCollectionQuery.Apply(
    queryApplications,
    new WintainiumApplicationQuery(
        WintainiumApplicationSort.NameAscending,
        WintainiumApplicationFilter.Installed));
if (installedApplications.Count != 1 ||
    installedApplications[0].ApplicationId != "org.example.alpha")
{
    Console.Error.WriteLine("Application collection Installed filter failed.");
    return 1;
}

var unknownApplications = WintainiumApplicationCollectionQuery.Apply(
    queryApplications,
    new WintainiumApplicationQuery(
        WintainiumApplicationSort.InstallationStatus));
if (unknownApplications.Count != 3 ||
    unknownApplications[0].InstallationState != WintainiumInstallationState.Unknown)
{
    Console.Error.WriteLine("Application collection Unknown-state ordering failed.");
    return 1;
}

Console.WriteLine("Application collection query: PASS");

try
{
    await host.InvokeAsync("Get-Command");
    Console.Error.WriteLine("Arbitrary PowerShell command invocation was not rejected.");
    return 1;
}
catch (ArgumentException)
{
    // Expected: the hosting primitive is constrained to the documented Core surface.
}

Console.WriteLine("Desktop engine contract probe: PASS");
Console.WriteLine("In-process PowerShell hosting: PASS");
Console.WriteLine("Public Core command invocation: PASS");
Console.WriteLine("Structured manifest result shape: PASS");
Console.WriteLine("Application model mapping: PASS");
Console.WriteLine("Public command allow-list: PASS");
return 0;
