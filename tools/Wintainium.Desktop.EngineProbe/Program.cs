using Wintainium.Desktop.Engine;
using Wintainium.Desktop.Models;
using Wintainium.Desktop.Settings;

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

var updateAvailableApplications = WintainiumApplicationCollectionQuery.Apply(
    queryApplications,
    new WintainiumApplicationQuery(
        WintainiumApplicationSort.NameAscending,
        WintainiumApplicationFilter.UpdateAvailable));
var upToDateApplications = WintainiumApplicationCollectionQuery.Apply(
    queryApplications,
    new WintainiumApplicationQuery(
        WintainiumApplicationSort.NameAscending,
        WintainiumApplicationFilter.UpToDate));
var notInstalledApplications = WintainiumApplicationCollectionQuery.Apply(
    queryApplications,
    new WintainiumApplicationQuery(
        WintainiumApplicationSort.NameAscending,
        WintainiumApplicationFilter.NotInstalled));
if (updateAvailableApplications.Count != 1 ||
    updateAvailableApplications[0].ApplicationId != "org.example.beta" ||
    upToDateApplications.Count != 1 ||
    upToDateApplications[0].ApplicationId != "org.example.alpha" ||
    notInstalledApplications.Count != 1 ||
    notInstalledApplications[0].ApplicationId != "org.example.beta")
{
    Console.Error.WriteLine("Application collection status filters failed.");
    return 1;
}

var reverseApplications = WintainiumApplicationCollectionQuery.Apply(
    queryApplications,
    new WintainiumApplicationQuery(WintainiumApplicationSort.NameDescending));
if (reverseApplications[0].Name != "Zeta" ||
    reverseApplications[2].Name != "Alpha")
{
    Console.Error.WriteLine("Application collection reverse name sorting failed.");
    return 1;
}

var sourceApplications = WintainiumApplicationCollectionQuery.Apply(
    queryApplications,
    new WintainiumApplicationQuery(WintainiumApplicationSort.Source));
if (sourceApplications[0].SourceProviderId != "provider.a" ||
    sourceApplications[1].SourceProviderId != "provider.b" ||
    sourceApplications[2].SourceProviderId != "provider.z")
{
    Console.Error.WriteLine("Application collection source sorting failed.");
    return 1;
}

var updateStatusApplications = WintainiumApplicationCollectionQuery.Apply(
    queryApplications,
    new WintainiumApplicationQuery(WintainiumApplicationSort.UpdateStatus));
if (updateStatusApplications[0].UpdateStatus != WintainiumUpdateStatus.Unknown ||
    updateStatusApplications[1].UpdateStatus != WintainiumUpdateStatus.UpdateAvailable ||
    updateStatusApplications[2].UpdateStatus != WintainiumUpdateStatus.UpToDate)
{
    Console.Error.WriteLine("Application collection update-status sorting failed.");
    return 1;
}

var viewModel = new WintainiumApplicationCollectionViewModel();
viewModel.SetApplications(queryApplications);

if (viewModel.Applications.Count != 3 ||
    viewModel.Applications[0].Name != "Alpha" ||
    viewModel.Applications[1].Name != "Beta" ||
    viewModel.Applications[2].Name != "Zeta")
{
    Console.Error.WriteLine("Application collection view model binding state failed.");
    return 1;
}

viewModel.SetQuery(
    new WintainiumApplicationQuery(
        WintainiumApplicationSort.NameAscending,
        WintainiumApplicationFilter.Installed));

if (viewModel.Applications.Count != 1 ||
    viewModel.Applications[0].ApplicationId != "org.example.alpha")
{
    Console.Error.WriteLine("Application collection view model query update failed.");
    return 1;
}

viewModel.SetQuery(
    new WintainiumApplicationQuery(
        WintainiumApplicationSort.InstallationStatus));

if (viewModel.Applications.Count != 3 ||
    viewModel.Applications[0].InstallationState != WintainiumInstallationState.Unknown)
{
    Console.Error.WriteLine("Application collection view model Unknown-state preservation failed.");
    return 1;
}

viewModel.SetViewMode(WintainiumApplicationViewMode.Grid);
if (viewModel.ViewMode != WintainiumApplicationViewMode.Grid)
{
    Console.Error.WriteLine("Application collection view mode update failed.");
    return 1;
}

viewModel.SetViewMode(WintainiumApplicationViewMode.List);
if (viewModel.ViewMode != WintainiumApplicationViewMode.List)
{
    Console.Error.WriteLine("Application collection view mode reset failed.");
    return 1;
}

var syntheticRelease = System.Management.Automation.PSObject.AsPSObject(
    new
    {
        OperationId = Guid.NewGuid().ToString(),
        IsSuccessful = true,
        Status = "Success",
        Releases = new[]
        {
            new
            {
                ReleaseId = "fixture-release-1",
                Version = "1.2.3",
                Channel = "stable",
                PublishedAt = DateTimeOffset.Parse("2026-01-01T00:00:00Z"),
                Artifacts = new[]
                {
                    new
                    {
                        Uri = "https://example.invalid/example-1.2.3-x64.zip",
                        FileName = "example-1.2.3-x64.zip",
                        Format = "zip",
                        Architecture = "x64",
                        Size = 12345L,
                        Hashes = new[] { new { Algorithm = "SHA256", Value = new string('a', 64) } }
                    }
                }
            }
        },
        Errors = Array.Empty<object>(),
        Warnings = Array.Empty<object>()
    });

var releaseResult = WintainiumApplicationReleaseMapper.Map(syntheticRelease);
if (releaseResult.Releases.Count != 1 ||
    releaseResult.Releases[0].Version != "1.2.3" ||
    releaseResult.Releases[0].Channel != "stable" ||
    releaseResult.Releases[0].Artifacts.Count != 1 ||
    releaseResult.Releases[0].Artifacts[0].Hashes.Count != 1)
{
    Console.Error.WriteLine("Application release mapping failed.");
    return 1;
}

var completedOperation = WintainiumOperationStateMapper.Map(
    System.Management.Automation.PSObject.AsPSObject(
        new
        {
            OperationId = "operation-complete",
            IsSuccessful = true,
            WasCancelled = false,
            Errors = Array.Empty<object>(),
            Warnings = Array.Empty<object>()
        }));

var failedOperation = WintainiumOperationStateMapper.Map(
    System.Management.Automation.PSObject.AsPSObject(
        new
        {
            OperationId = "operation-failed",
            IsSuccessful = false,
            WasCancelled = false,
            Errors = new[] { new { Code = "Example.Error", Path = "Example", Message = "Example failure." } },
            Warnings = Array.Empty<object>()
        }));

var cancelledOperation = WintainiumOperationStateMapper.Map(
    System.Management.Automation.PSObject.AsPSObject(
        new
        {
            OperationId = "operation-cancelled",
            IsSuccessful = false,
            WasCancelled = true,
            Errors = Array.Empty<object>(),
            Warnings = Array.Empty<object>()
        }));

if (completedOperation.State != WintainiumOperationState.Completed ||
    failedOperation.State != WintainiumOperationState.Failed ||
    cancelledOperation.State != WintainiumOperationState.Cancelled ||
    failedOperation.Errors.Count != 1 ||
    failedOperation.Errors[0].Code != "Example.Error" ||
    failedOperation.Errors[0].Path != "Example" ||
    failedOperation.Errors[0].Message != "Example failure.")
{
    Console.Error.WriteLine("Structured operation state mapping failed.");
    return 1;
}

Console.WriteLine("Structured operation state and diagnostics: PASS");

Console.WriteLine("Application release mapping: PASS");

Console.WriteLine("Application collection view mode: PASS");

Console.WriteLine("Application collection view model: PASS");

Console.WriteLine("Application collection query: PASS");

var settings = new WintainiumDesktopSettingsService();

if (settings.Current.Theme != WintainiumThemePreference.System ||
    settings.Current.VisualStyle != WintainiumVisualStyle.Windows11)
{
    Console.Error.WriteLine("Desktop settings defaults are not stable.");
    return 1;
}

settings.SetTheme(WintainiumThemePreference.Dark);
settings.SetVisualStyle(WintainiumVisualStyle.FrutigerAero);

if (settings.Current.Theme != WintainiumThemePreference.Dark ||
    settings.Current.VisualStyle != WintainiumVisualStyle.FrutigerAero)
{
    Console.Error.WriteLine("Desktop settings session state did not persist.");
    return 1;
}

var settingsReopenState = settings.Current;
if (settingsReopenState.Theme != WintainiumThemePreference.Dark ||
    settingsReopenState.VisualStyle != WintainiumVisualStyle.FrutigerAero)
{
    Console.Error.WriteLine("Desktop settings reopen state did not preserve session values.");
    return 1;
}

Console.WriteLine("Desktop settings model/service: PASS");

using (var alreadyCancelled = new CancellationTokenSource())
{
    alreadyCancelled.Cancel();

    try
    {
        await host.InvokeAsync(
            "Get-WintainiumManifest",
            new Dictionary<string, object?>
            {
                ["Path"] = Path.GetDirectoryName(modulePath)!
            },
            alreadyCancelled.Token);

        Console.Error.WriteLine("Pre-cancelled desktop operation did not honor the cancellation token.");
        return 1;
    }
    catch (OperationCanceledException)
    {
        // Expected: cancellation is honored before a new pipeline invocation starts.
    }
}

Console.WriteLine("Desktop cancellation boundary: PASS");

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
