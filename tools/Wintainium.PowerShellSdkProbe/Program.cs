using System.Management.Automation;
using System.Management.Automation.Runspaces;

if (args.Length != 1)
{
    Console.Error.WriteLine("Usage: dotnet run -- <path-to-Wintainium.Core.psd1>");
    return 2;
}

var modulePath = Path.GetFullPath(args[0]);

var initialState = InitialSessionState.CreateDefault();
initialState.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Unrestricted;

using var powershell = PowerShell.Create(initialState);

powershell.AddCommand("Get-ExecutionPolicy");
var executionPolicyResults = powershell.Invoke();
if (powershell.HadErrors || executionPolicyResults.Count != 1)
{
    Console.Error.WriteLine("PowerShell SDK execution-policy probe failed.");
    foreach (var error in powershell.Streams.Error)
    {
        Console.Error.WriteLine(error.ToString());
    }

    return 1;
}

Console.WriteLine($"Hosted execution policy: {executionPolicyResults[0].BaseObject}");
powershell.Commands.Clear();
powershell.Streams.Error.Clear();

powershell.AddCommand("Import-Module")
    .AddParameter("Name", modulePath)
    .AddParameter("Force");

_ = powershell.Invoke();
if (powershell.HadErrors)
{
    Console.Error.WriteLine("PowerShell module import failed.");
    foreach (var error in powershell.Streams.Error)
    {
        Console.Error.WriteLine(error.ToString());
    }

    return 1;
}

powershell.Commands.Clear();
powershell.Streams.Error.Clear();

powershell.AddCommand("Get-Command")
    .AddParameter("Name", "Get-WintainiumManifest");

var commandResults = powershell.Invoke();
if (powershell.HadErrors || commandResults.Count != 1)
{
    Console.Error.WriteLine("Wintainium public command discovery failed.");
    foreach (var error in powershell.Streams.Error)
    {
        Console.Error.WriteLine(error.ToString());
    }

    return 1;
}

powershell.Commands.Clear();
powershell.Streams.Error.Clear();

var manifestRoot = Path.Combine(Path.GetTempPath(), "Wintainium.PowerShellSdkProbe", Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(manifestRoot);

try
{
    powershell.AddCommand("Get-WintainiumManifest")
        .AddParameter("Path", manifestRoot);

    var results = powershell.Invoke();

    if (powershell.HadErrors || results.Count != 1)
    {
        Console.Error.WriteLine("Wintainium public command invocation failed.");
        foreach (var error in powershell.Streams.Error)
        {
            Console.Error.WriteLine(error.ToString());
        }

        return 1;
    }

    var pipelineResult = results[0];
    var baseObject = pipelineResult.BaseObject;
    var runtimeType = baseObject.GetType();

    Console.WriteLine("PowerShell SDK hosting: PASS");
    Console.WriteLine($"Imported module: {modulePath}");
    Console.WriteLine("Public command resolved: Get-WintainiumManifest");
    Console.WriteLine($"Pipeline result type: {pipelineResult.GetType().FullName}");
    Console.WriteLine($"Base object type: {runtimeType.FullName}");
    Console.WriteLine($"Base object string: {baseObject}");

    var properties = pipelineResult.Properties
        .Select(property => new
        {
            property.Name,
            ValueType = property.Value?.GetType().FullName ?? "<null>",
            Value = property.Value?.ToString() ?? "<null>"
        })
        .OrderBy(property => property.Name)
        .ToArray();

    Console.WriteLine("Returned properties:");
    foreach (var property in properties)
    {
        Console.WriteLine($"  {property.Name}: {property.ValueType} = {property.Value}");
    }

    return 0;
}
finally
{
    try
    {
        Directory.Delete(manifestRoot, recursive: true);
    }
    catch
    {
        // Probe cleanup is best-effort.
    }
}
