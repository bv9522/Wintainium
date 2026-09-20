using System.Management.Automation;
using System.Management.Automation.Runspaces;

namespace Wintainium.Desktop.Engine;

/// <summary>
/// Owns the in-process PowerShell SDK hosting boundary used by the desktop client.
/// </summary>
internal sealed class WintainiumPowerShellHost : IAsyncDisposable
{
    private readonly Runspace _runspace;
    private readonly SemaphoreSlim _invocationGate = new(1, 1);
    private readonly string _modulePath;
    private bool _disposed;

    public WintainiumPowerShellHost(string modulePath)
    {
        if (string.IsNullOrWhiteSpace(modulePath))
        {
            throw new ArgumentException("The Wintainium.Core module path is required.", nameof(modulePath));
        }

        _modulePath = Path.GetFullPath(modulePath);

        if (!File.Exists(_modulePath))
        {
            throw new FileNotFoundException("The Wintainium.Core module was not found.", _modulePath);
        }

        var initialState = InitialSessionState.CreateDefault();
        initialState.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Unrestricted;

        _runspace = RunspaceFactory.CreateRunspace(initialState);
        _runspace.Open();
        ImportCoreModule();
    }

    public async Task<WintainiumPowerShellInvocationResult> InvokeAsync(
        string commandName,
        IReadOnlyDictionary<string, object?>? parameters = null,
        CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);

        if (string.IsNullOrWhiteSpace(commandName))
        {
            throw new ArgumentException("A PowerShell command name is required.", nameof(commandName));
        }

        await _invocationGate.WaitAsync(cancellationToken).ConfigureAwait(false);

        try
        {
            using var powershell = PowerShell.Create();
            powershell.Runspace = _runspace;
            powershell.AddCommand(commandName);

            if (parameters is not null)
            {
                foreach (var parameter in parameters)
                {
                    if (parameter.Value is not null)
                    {
                        powershell.AddParameter(parameter.Key, parameter.Value);
                    }
                }
            }

            using var cancellationRegistration = cancellationToken.Register(
                static state =>
                {
                    var pipeline = (PowerShell)state!;
                    try
                    {
                        pipeline.Stop();
                    }
                    catch (InvalidOperationException)
                    {
                        // The pipeline may already have completed.
                    }
                },
                powershell);

            IReadOnlyList<PSObject> output;

            try
            {
                var invocation = await powershell.InvokeAsync().ConfigureAwait(false);
                output = invocation.ToArray();
            }
            catch (PipelineStoppedException) when (cancellationToken.IsCancellationRequested)
            {
                return new WintainiumPowerShellInvocationResult(
                    commandName,
                    Array.Empty<PSObject>(),
                    powershell.Streams.Error.ToArray(),
                    WasCancelled: true);
            }

            return new WintainiumPowerShellInvocationResult(
                commandName,
                output,
                powershell.Streams.Error.ToArray(),
                WasCancelled: cancellationToken.IsCancellationRequested);
        }
        finally
        {
            _invocationGate.Release();
        }
    }

    public ValueTask DisposeAsync()
    {
        if (_disposed)
        {
            return ValueTask.CompletedTask;
        }

        _disposed = true;
        _runspace.Dispose();
        _invocationGate.Dispose();
        return ValueTask.CompletedTask;
    }

    private void ImportCoreModule()
    {
        using var powershell = PowerShell.Create();
        powershell.Runspace = _runspace;
        powershell.AddCommand("Import-Module")
            .AddParameter("Name", _modulePath)
            .AddParameter("Force");

        _ = powershell.Invoke();

        if (powershell.HadErrors)
        {
            var message = string.Join(
                Environment.NewLine,
                powershell.Streams.Error.Select(error => error.ToString()));

            throw new InvalidOperationException(
                $"Wintainium.Core could not be imported.{Environment.NewLine}{message}");
        }
    }
}
