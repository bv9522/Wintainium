using System.Management.Automation;

namespace Wintainium.Desktop.Engine;

/// <summary>
/// Captures one public Core command invocation without exposing PowerShell hosting
/// details to the rest of the desktop application.
/// </summary>
internal sealed record WintainiumPowerShellInvocationResult(
    string CommandName,
    IReadOnlyList<PSObject> Output,
    IReadOnlyList<ErrorRecord> Errors,
    bool WasCancelled);
