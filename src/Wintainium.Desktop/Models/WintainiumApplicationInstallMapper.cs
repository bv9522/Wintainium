using System.Collections;
using System.Management.Automation;

namespace Wintainium.Desktop.Models;

internal static class WintainiumApplicationInstallMapper
{
    public static WintainiumApplicationInstallResult Map(PSObject result)
    {
        ArgumentNullException.ThrowIfNull(result);

        return new WintainiumApplicationInstallResult(
            OperationId: Nullable(result, "OperationId"),
            IsSuccessful: Boolean(result, "IsSuccessful"),
            WasCancelled: Boolean(result, "WasCancelled"),
            Status: Nullable(result, "Status"),
            ApplicationId: Nullable(result, "ApplicationId"),
            Stages: Collection(result, "Stages").Select(MapStage).ToArray(),
            Errors: Diagnostics(result, "Errors"),
            Warnings: Diagnostics(result, "Warnings"),
            LogEvents: Diagnostics(result, "LogEvents"),
            Error: Diagnostic(result, "Error"),
            OperationState: DetermineState(Boolean(result, "IsSuccessful"), Boolean(result, "WasCancelled")));
    }

    private static WintainiumApplicationInstallStageModel MapStage(PSObject stage) =>
        new(
            Sequence: Integer(stage, "Sequence"),
            Name: Nullable(stage, "Name"),
            Status: Nullable(stage, "Status"),
            ReasonCode: Nullable(stage, "ReasonCode"),
            Reason: Nullable(stage, "Reason"),
            IsSuccessful: Boolean(stage, "IsSuccessful"),
            WasCancelled: Boolean(stage, "WasCancelled"),
            Error: Diagnostic(stage, "Error"));

    private static WintainiumOperationDiagnostic? Diagnostic(PSObject source, string name)
    {
        var value = source.Properties[name]?.Value;
        return IsNullLike(value) ? null : MapDiagnostic(PSObject.AsPSObject(value));
    }

    private static bool IsNullLike(object? value) =>
        value is null ||
        value is PSObject { BaseObject: null } ||
        value is PSObject psObject && psObject.Properties.Count() == 0;

    private static WintainiumOperationState DetermineState(bool isSuccessful, bool wasCancelled) =>
        wasCancelled ? WintainiumOperationState.Cancelled :
        isSuccessful ? WintainiumOperationState.Completed :
        WintainiumOperationState.Failed;

    private static IReadOnlyList<WintainiumOperationDiagnostic> Diagnostics(PSObject source, string name) =>
        Collection(source, name).Select(MapDiagnostic).ToArray();

    private static WintainiumOperationDiagnostic MapDiagnostic(PSObject source) =>
        new(
            Code: Nullable(source, "Code"),
            Path: Nullable(source, "Path"),
            Message: Nullable(source, "Message"));

    private static List<PSObject> Collection(PSObject source, string name)
    {
        var value = source.Properties[name]?.Value;
        if (value is null) return [];

        if (value is IEnumerable enumerable and not string)
            return enumerable.Cast<object>().Select(PSObject.AsPSObject).ToList();

        return [PSObject.AsPSObject(value)];
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null
            ? null
            : Convert.ToString(source.Properties[name]!.Value);

    private static bool Boolean(PSObject source, string name) =>
        source.Properties[name]?.Value is not null &&
        Convert.ToBoolean(source.Properties[name]!.Value);

    private static int Integer(PSObject source, string name) =>
        source.Properties[name]?.Value is null
            ? 0
            : Convert.ToInt32(source.Properties[name]!.Value);
}
