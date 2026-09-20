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

var models = WintainiumApplicationModelMapper.MapManifestResult(output);
if (models.Count != 0)
{
    Console.Error.WriteLine("Expected the repository Core directory to contain no recognized manifests.");
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
        Manifests = new[] { syntheticManifest }
    });

var syntheticModels = WintainiumApplicationModelMapper.MapManifestResult(syntheticResult);
if (syntheticModels.Count != 1 ||
    syntheticModels[0].ApplicationId != "org.example.app" ||
    syntheticModels[0].Name != "Example App" ||
    syntheticModels[0].InstallationState != WintainiumInstallationState.Unknown ||
    syntheticModels[0].UpdateStatus != WintainiumUpdateStatus.Unknown ||
    syntheticModels[0].InstalledVersion is not null)
{
    Console.Error.WriteLine("Application model mapping did not preserve the required initial Unknown state.");
    return 1;
}

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
