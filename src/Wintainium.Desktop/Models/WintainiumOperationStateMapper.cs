using System.Collections;
using System.Management.Automation;

namespace Wintainium.Desktop.Models;

internal static class WintainiumOperationStateMapper
{
    public static WintainiumOperationStateModel Map(PSObject result)
    {
        ArgumentNullException.ThrowIfNull(result);

        var operationId = Required(result, "OperationId");
        var isSuccessful = Boolean(result, "IsSuccessful");
        var wasCancelled = Boolean(result, "WasCancelled");

        return new WintainiumOperationStateModel(
            operationId,
            DetermineState(isSuccessful, wasCancelled),
            isSuccessful,
            wasCancelled,
            Diagnostics(result, "Errors"),
            Diagnostics(result, "Warnings"));
    }

    private static WintainiumOperationState DetermineState(bool isSuccessful, bool wasCancelled) =>
        wasCancelled ? WintainiumOperationState.Cancelled :
        isSuccessful ? WintainiumOperationState.Completed :
        WintainiumOperationState.Failed;

    private static IReadOnlyList<WintainiumOperationDiagnostic> Diagnostics(PSObject source, string name)
    {
        var value = source.Properties[name]?.Value;
        if (value is null) return [];

        if (value is IEnumerable enumerable and not string)
        {
            return enumerable.Cast<object>()
                .Select(PSObject.AsPSObject)
                .Select(MapDiagnostic)
                .ToArray();
        }

        return [MapDiagnostic(PSObject.AsPSObject(value))];
    }

    private static WintainiumOperationDiagnostic MapDiagnostic(PSObject value) =>
        new(
            Code: Nullable(value, "Code"),
            Path: Nullable(value, "Path"),
            Message: Nullable(value, "Message"));

    private static string Required(PSObject source, string name)
    {
        var value = Nullable(source, name);
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException($"Core result is missing required property '{name}'.");
        return value;
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToString(source.Properties[name]!.Value);

    private static bool Boolean(PSObject source, string name) =>
        source.Properties[name]?.Value is not null && Convert.ToBoolean(source.Properties[name]!.Value);
}
