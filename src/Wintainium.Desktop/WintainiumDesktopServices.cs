using Wintainium.Desktop.Engine;
using Wintainium.Desktop.Models;

namespace Wintainium.Desktop;

/// <summary>
/// Application composition root for the desktop/Core integration boundary.
///
/// The service graph owns one Core host and one adapter instance so presentation
/// windows do not create independent PowerShell runspaces or application services.
/// </summary>
internal sealed class WintainiumDesktopServices : IAsyncDisposable
{
    private readonly WintainiumPowerShellHost _powerShellHost;
    private bool _disposed;

    public WintainiumDesktopServices()
    {
        _powerShellHost = new WintainiumPowerShellHost(WintainiumCoreModuleLocator.Locate());
        CoreClient = new WintainiumCoreClient(_powerShellHost);
        InstalledApplicationState = new WintainiumApplicationInstalledStateService(CoreClient);
        ApplicationCollection = new WintainiumApplicationCollectionService(CoreClient, InstalledApplicationState);
        ApplicationValidation = new WintainiumApplicationValidationService(CoreClient);
        ApplicationRelease = new WintainiumApplicationReleaseService(CoreClient);
        ApplicationUpdate = new WintainiumApplicationUpdateService(CoreClient);
        ApplicationOnboarding = new WintainiumApplicationOnboardingService(CoreClient);
    }

    public WintainiumCoreClient CoreClient { get; }

    public WintainiumApplicationCollectionService ApplicationCollection { get; }

    public WintainiumApplicationInstalledStateService InstalledApplicationState { get; }

    public WintainiumApplicationValidationService ApplicationValidation { get; }

    public WintainiumApplicationReleaseService ApplicationRelease { get; }

    public WintainiumApplicationUpdateService ApplicationUpdate { get; }

    public WintainiumApplicationOnboardingService ApplicationOnboarding { get; }

    public ValueTask DisposeAsync()
    {
        if (_disposed)
            return ValueTask.CompletedTask;

        _disposed = true;
        return _powerShellHost.DisposeAsync();
    }
}
