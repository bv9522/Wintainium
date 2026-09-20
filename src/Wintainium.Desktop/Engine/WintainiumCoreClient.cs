using System.Management.Automation;

namespace Wintainium.Desktop.Engine;

/// <summary>
/// Presentation-neutral adapter for the four documented Wintainium.Core public commands.
/// </summary>
public sealed class WintainiumCoreClient
{
    private readonly WintainiumPowerShellHost _host;

    public WintainiumCoreClient(WintainiumPowerShellHost host)
    {
        _host = host ?? throw new ArgumentNullException(nameof(host));
    }

    public Task<WintainiumPowerShellInvocationResult> GetManifestsAsync(
        string path,
        bool recurse = false,
        string? schemaPath = null,
        CancellationToken cancellationToken = default)
    {
        var parameters = new Dictionary<string, object?>
        {
            ["Path"] = path
        };

        if (recurse)
        {
            parameters["Recurse"] = true;
        }

        if (!string.IsNullOrWhiteSpace(schemaPath))
        {
            parameters["SchemaPath"] = schemaPath;
        }

        return _host.InvokeAsync(
            "Get-WintainiumManifest",
            parameters,
            cancellationToken);
    }

    public Task<WintainiumPowerShellInvocationResult> ValidateApplicationDefinitionAsync(
        string manifestPath,
        string? pluginRoot = null,
        string? schemaPath = null,
        string? operationId = null,
        CancellationToken cancellationToken = default)
    {
        var parameters = new Dictionary<string, object?>
        {
            ["ManifestPath"] = manifestPath
        };

        AddOptional(parameters, "PluginRoot", pluginRoot);
        AddOptional(parameters, "SchemaPath", schemaPath);
        AddOptional(parameters, "OperationId", operationId);

        return _host.InvokeAsync(
            "Test-WintainiumApplicationDefinition",
            parameters,
            cancellationToken);
    }

    public Task<WintainiumPowerShellInvocationResult> GetApplicationReleaseAsync(
        string manifestPath,
        string? pluginRoot = null,
        string? schemaPath = null,
        string? operationId = null,
        CancellationToken cancellationToken = default)
    {
        var parameters = new Dictionary<string, object?>
        {
            ["ManifestPath"] = manifestPath
        };

        AddOptional(parameters, "PluginRoot", pluginRoot);
        AddOptional(parameters, "SchemaPath", schemaPath);
        AddOptional(parameters, "OperationId", operationId);

        return _host.InvokeAsync(
            "Get-WintainiumApplicationRelease",
            parameters,
            cancellationToken);
    }

    public Task<WintainiumPowerShellInvocationResult> UpdateApplicationAsync(
        string manifestPath,
        string stateRoot,
        string machineArchitecture,
        string downloadRoot,
        string? pluginRoot = null,
        string? schemaPath = null,
        int installerTimeoutMilliseconds = 600_000,
        CancellationToken cancellationToken = default)
    {
        var parameters = new Dictionary<string, object?>
        {
            ["ManifestPath"] = manifestPath,
            ["StateRoot"] = stateRoot,
            ["MachineArchitecture"] = machineArchitecture,
            ["DownloadRoot"] = downloadRoot,
            ["InstallerTimeoutMilliseconds"] = installerTimeoutMilliseconds,
            ["CancellationToken"] = cancellationToken
        };

        AddOptional(parameters, "PluginRoot", pluginRoot);
        AddOptional(parameters, "SchemaPath", schemaPath);

        return _host.InvokeAsync(
            "Invoke-WintainiumApplicationUpdate",
            parameters,
            cancellationToken);
    }

    private static void AddOptional(
        IDictionary<string, object?> parameters,
        string name,
        string? value)
    {
        if (!string.IsNullOrWhiteSpace(value))
        {
            parameters[name] = value;
        }
    }
}
