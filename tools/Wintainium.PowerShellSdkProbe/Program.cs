using System.Collections;
using System.Management.Automation;
using System.Management.Automation.Runspaces;

if (args.Length is < 1 or > 2)
{
    Console.Error.WriteLine("Usage: dotnet run -- <path-to-Wintainium.Core.psd1> [<manifest-root-or-file>]");
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

var manifestPath = args.Length == 2
    ? Path.GetFullPath(args[1])
    : Path.Combine(Path.GetTempPath(), "Wintainium.PowerShellSdkProbe", Guid.NewGuid().ToString("N"));

if (args.Length == 1)
{
    Directory.CreateDirectory(manifestPath);
}

try
{
    powershell.AddCommand("Get-WintainiumManifest")
        .AddParameter("Path", manifestPath);

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

    Console.WriteLine("PowerShell SDK hosting: PASS");
    Console.WriteLine($"Imported module: {modulePath}");
    Console.WriteLine("Public command resolved: Get-WintainiumManifest");
    Console.WriteLine($"Manifest probe path: {manifestPath}");
    Console.WriteLine($"Pipeline result type: {pipelineResult.GetType().FullName}");
    Console.WriteLine($"Base object type: {baseObject.GetType().FullName}");
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

    PrintDetailedValue("Errors", pipelineResult.Properties["Errors"]?.Value);
    PrintDetailedValue("Warnings", pipelineResult.Properties["Warnings"]?.Value);
    PrintDetailedValue("Candidates", pipelineResult.Properties["Candidates"]?.Value);
    PrintDetailedValue("ManifestPaths", pipelineResult.Properties["ManifestPaths"]?.Value);

    var manifestsProperty = pipelineResult.Properties["Manifests"]?.Value;
    if (manifestsProperty is null)
    {
        Console.WriteLine("Manifest collection: <null or not exposed>");
        return 0;
    }

    var manifestItems = manifestsProperty is IEnumerable enumerable and not string
        ? enumerable.Cast<object?>().ToArray()
        : new object?[] { manifestsProperty };

    Console.WriteLine($"Manifest entries: {manifestItems.Length}");

    if (manifestItems.Length == 0)
    {
        return 0;
    }

    var manifest = PSObject.AsPSObject(manifestItems[0]);
    Console.WriteLine($"First manifest PSObject type: {manifest.GetType().FullName}");
    Console.WriteLine($"First manifest base object type: {manifest.BaseObject.GetType().FullName}");
    Console.WriteLine("First manifest properties:");

    foreach (var property in manifest.Properties.OrderBy(p => p.Name))
    {
        Console.WriteLine($"  {property.Name}: {property.Value?.GetType().FullName ?? "<null>"} = {property.Value}");
    }

    var sourceProperty = manifest.Properties["Source"];
    if (sourceProperty?.Value is null)
    {
        Console.WriteLine("Source property: <null or not exposed through PSObject.Properties>");
        return 0;
    }

    var source = PSObject.AsPSObject(sourceProperty.Value);
    Console.WriteLine($"Source PSObject type: {source.GetType().FullName}");
    Console.WriteLine($"Source base object type: {source.BaseObject.GetType().FullName}");
    Console.WriteLine($"Source base object string: {source.BaseObject}");
    Console.WriteLine("Source PSObject properties:");

    foreach (var property in source.Properties.OrderBy(p => p.Name))
    {
        Console.WriteLine($"  {property.Name}: {property.Value?.GetType().FullName ?? "<null>"} = {property.Value}");
    }

    if (source.BaseObject is IDictionary dictionary)
    {
        Console.WriteLine("Source dictionary entries:");
        foreach (DictionaryEntry entry in dictionary)
        {
            Console.WriteLine($"  [{entry.Key}] ({entry.Key?.GetType().FullName ?? "<null>"}) = {entry.Value} ({entry.Value?.GetType().FullName ?? "<null>"})");
        }
    }

    return 0;
}
finally
{
    if (args.Length == 1)
    {
        try
        {
            Directory.Delete(manifestPath, recursive: true);
        }
        catch
        {
            // Probe cleanup is best-effort.
        }
    }
}

static void PrintDetailedValue(string name, object? value)
{
    Console.WriteLine($"Detailed {name}:");

    if (value is null)
    {
        Console.WriteLine("  <null>");
        return;
    }

    if (value is string)
    {
        Console.WriteLine($"  {DescribeObject(value)}");
        return;
    }

    if (value is IEnumerable enumerable)
    {
        var items = enumerable.Cast<object?>().ToArray();
        Console.WriteLine($"  Count: {items.Length}");

        for (var index = 0; index < items.Length; index++)
        {
            Console.WriteLine($"  [{index}]");
            PrintObject(items[index], "    ");
        }

        return;
    }

    PrintObject(value, "  ");
}

static void PrintObject(object? value, string indent)
{
    if (value is null)
    {
        Console.WriteLine($"{indent}<null>");
        return;
    }

    var psObject = PSObject.AsPSObject(value);
    Console.WriteLine($"{indent}Type: {value.GetType().FullName}");
    Console.WriteLine($"{indent}BaseObject: {psObject.BaseObject?.GetType().FullName ?? "<null>"}");
    Console.WriteLine($"{indent}String: {value}");

    var properties = psObject.Properties
        .Where(property => property.Value is not null)
        .OrderBy(property => property.Name)
        .ToArray();

    if (properties.Length == 0)
    {
        return;
    }

    Console.WriteLine($"{indent}Properties:");

    foreach (var property in properties)
    {
        var propertyValue = property.Value;

        if (propertyValue is string || propertyValue is not IEnumerable)
        {
            Console.WriteLine($"{indent}  {property.Name}: {DescribeObject(propertyValue)}");
            continue;
        }

        var items = ((IEnumerable)propertyValue).Cast<object?>().ToArray();
        Console.WriteLine($"{indent}  {property.Name}: {propertyValue.GetType().FullName} Count={items.Length}");

        for (var index = 0; index < items.Length; index++)
        {
            Console.WriteLine($"{indent}    [{index}] {DescribeObject(items[index])}");
        }
    }
}

static string DescribeObject(object? value)
{
    if (value is null)
    {
        return "<null>";
    }

    var psObject = PSObject.AsPSObject(value);
    var baseObject = psObject.BaseObject;

    return $"{value.GetType().FullName} = {baseObject}";
}
