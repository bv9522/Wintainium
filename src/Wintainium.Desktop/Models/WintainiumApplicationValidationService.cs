using System.Collections;
using System.Management.Automation;
using Wintainium.Desktop.Engine;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Validates one application definition through the documented Core validation command.
/// This service does not perform discovery, update decisions, installation, or persistence.
/// </summary>
internal sealed class WintainiumApplicationValidationService
{
    private readonly WintainiumCoreClient _coreClient;

    public WintainiumApplicationValidationService(WintainiumCoreClient coreClient)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
    }

    public async Task<WintainiumApplicationValidationResult> ValidateAsync(
        string manifestPath,
        string? pluginRoot = null,
        string? schemaPath = null,
        string? operationId = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(manifestPath))
            throw new ArgumentException("The application manifest path is required.", nameof(manifestPath));

        var invocation = await _coreClient.ValidateApplicationDefinitionAsync(
            manifestPath,
            pluginRoot,
            schemaPath,
            operationId,
            cancellationToken).ConfigureAwait(false);

        if (invocation.WasCancelled)
            throw new OperationCanceledException(cancellationToken);

        if (invocation.Output.Count != 1)
        {
            throw new InvalidOperationException(
                $"Test-WintainiumApplicationDefinition returned {invocation.Output.Count} structured results; exactly one was expected.");
        }

        var result = PSObject.AsPSObject(invocation.Output[0]);
        var resolvedOperationId = Required(result, "OperationId");
        var isValid = Boolean(result, "IsValid");

        return new WintainiumApplicationValidationResult(
            resolvedOperationId,
            isValid,
            Diagnostics(result, "Errors"),
            Diagnostics(result, "Warnings"),
            isValid ? WintainiumOperationState.Completed : WintainiumOperationState.Failed);
    }

    private static IReadOnlyList<WintainiumOperationDiagnostic> Diagnostics(PSObject source, string name)
    {
        var value = source.Properties[name]?.Value;
        if (value is null)
            return [];

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
        source.Properties[name]?.Value is null
            ? null
            : Convert.ToString(source.Properties[name]!.Value);

    private static bool Boolean(PSObject source, string name) =>
        source.Properties[name]?.Value is not null &&
        Convert.ToBoolean(source.Properties[name]!.Value);
}
