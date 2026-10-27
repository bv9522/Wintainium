using System.Collections;
using System.Management.Automation;
using Wintainium.Desktop.Engine;

namespace Wintainium.Desktop.Models;

internal sealed record WintainiumRegistryIdentityCandidate(
    string DisplayName,
    string? DisplayVersion,
    string? Publisher,
    string? RegistrySubKey,
    string? Scope,
    string? View,
    int Score,
    string? Confidence,
    string? Reason);

/// <summary>
/// Coordinates human-confirmed registry identity discovery. Suggestions never
/// alter installed-state matching unless the user explicitly selects one.
/// </summary>
internal sealed class WintainiumApplicationRegistryIdentityService
{
    private readonly WintainiumCoreClient _coreClient;

    public WintainiumApplicationRegistryIdentityService(WintainiumCoreClient coreClient)
    {
        _coreClient = coreClient ?? throw new ArgumentNullException(nameof(coreClient));
    }

    public async Task<IReadOnlyList<WintainiumRegistryIdentityCandidate>> DiscoverAsync(
        string applicationName,
        string? publisher,
        CancellationToken cancellationToken = default)
    {
        var invocation = await _coreClient.DiscoverApplicationRegistryIdentityCandidatesAsync(
            applicationName, publisher, cancellationToken).ConfigureAwait(false);
        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation, "Get-WintainiumApplicationRegistryIdentityCandidates", cancellationToken);

        if (!Boolean(result, "IsSuccessful"))
            return [];

        var value = result.Properties["Candidates"]?.Value;
        if (value is null)
            return [];

        var candidates = value is IEnumerable enumerable and not string
            ? enumerable.Cast<object>().Select(PSObject.AsPSObject)
            : new[] { PSObject.AsPSObject(value) };

        return candidates.Select(candidate => new WintainiumRegistryIdentityCandidate(
            Required(candidate, "DisplayName"),
            Nullable(candidate, "DisplayVersion"),
            Nullable(candidate, "Publisher"),
            Nullable(candidate, "RegistrySubKey"),
            Nullable(candidate, "Scope"),
            Nullable(candidate, "View"),
            Integer(candidate, "Score"),
            Nullable(candidate, "Confidence"),
            Nullable(candidate, "Reason"))).ToArray();
    }

    public async Task<bool> ConfigureAsync(
        string manifestPath,
        WintainiumRegistryIdentityCandidate candidate,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(manifestPath);
        ArgumentNullException.ThrowIfNull(candidate);

        var locations = new object[]
        {
            new Hashtable { ["scope"] = "machine", ["view"] = "64" },
            new Hashtable { ["scope"] = "machine", ["view"] = "32" },
            new Hashtable { ["scope"] = "user", ["view"] = "native" }
        };

        var predicates = new List<object>();
        if (!string.IsNullOrWhiteSpace(candidate.DisplayName))
        {
            var displayName = candidate.DisplayName.Trim();
            var baseName = System.Text.RegularExpressions.Regex.Replace(
                displayName, @"\s+\d+(?:\.\d+)*(?:[a-z])?$", "").Trim();
            var hasVersionSuffix = !string.Equals(baseName, displayName, StringComparison.Ordinal);
            predicates.Add(new Hashtable
            {
                ["value"] = "DisplayName",
                ["equals"] = hasVersionSuffix ? baseName : displayName,
                ["matchType"] = hasVersionSuffix ? "nameOrVersionSuffix" : "exact"
            });
        }

        if (!string.IsNullOrWhiteSpace(candidate.RegistrySubKey))
        {
            predicates.Add(new Hashtable
            {
                ["value"] = "subkey",
                ["equals"] = candidate.RegistrySubKey,
                ["matchType"] = "exact"
            });
        }

        if (predicates.Count == 0)
            return false;

        var settings = new Hashtable
        {
            ["registry"] = new Hashtable
            {
                ["matchMode"] = "any",
                ["locations"] = locations,
                ["match"] = predicates.ToArray()
            }
        };

        var invocation = await _coreClient.SetApplicationReconciliationSettingsAsync(
            manifestPath, settings, cancellationToken).ConfigureAwait(false);
        var result = WintainiumCoreInvocationGuard.RequireSingleResult(
            invocation, "Set-WintainiumApplicationReconciliationSettings", cancellationToken);
        return Boolean(result, "IsSuccessful");
    }

    private static string Required(PSObject source, string name)
    {
        var value = Nullable(source, name);
        if (string.IsNullOrWhiteSpace(value))
            throw new InvalidOperationException($"Registry identity candidate is missing '{name}'.");
        return value;
    }

    private static string? Nullable(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? null : Convert.ToString(source.Properties[name]!.Value);

    private static int Integer(PSObject source, string name) =>
        source.Properties[name]?.Value is null ? 0 : Convert.ToInt32(source.Properties[name]!.Value);

    private static bool Boolean(PSObject source, string name) =>
        source.Properties[name]?.Value is not null && Convert.ToBoolean(source.Properties[name]!.Value);
}
