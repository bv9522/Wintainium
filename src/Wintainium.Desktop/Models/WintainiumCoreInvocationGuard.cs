using System.Management.Automation;
using Wintainium.Desktop.Engine;

namespace Wintainium.Desktop.Models;

internal static class WintainiumCoreInvocationGuard
{
    public static PSObject RequireSingleResult(
        WintainiumPowerShellInvocationResult invocation,
        string commandName,
        CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(invocation);

        if (invocation.WasCancelled)
        {
            throw new OperationCanceledException(cancellationToken);
        }

        if (invocation.Output.Count != 1)
        {
            var diagnostics = invocation.Errors.Count == 0
                ? "No PowerShell error diagnostics were returned."
                : string.Join(
                    Environment.NewLine,
                    invocation.Errors.Select(static error => error.ToString()));

            throw new InvalidOperationException(
                $"{commandName} returned {invocation.Output.Count} structured results; exactly one was expected.{Environment.NewLine}{diagnostics}");
        }

        return PSObject.AsPSObject(invocation.Output[0]);
    }
}
