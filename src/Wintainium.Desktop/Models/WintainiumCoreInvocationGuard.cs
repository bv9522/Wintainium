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
            throw new InvalidOperationException(
                $"{commandName} returned {invocation.Output.Count} structured results; exactly one was expected.");
        }

        return PSObject.AsPSObject(invocation.Output[0]);
    }
}
