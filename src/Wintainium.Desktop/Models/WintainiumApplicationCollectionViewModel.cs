using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace Wintainium.Desktop.Models;

/// <summary>
/// Presentation state for the main application collection.
/// It owns only the currently selected presentation query; Core remains authoritative
/// for application facts and update state.
/// </summary>
internal sealed class WintainiumApplicationCollectionViewModel : INotifyPropertyChanged
{
    private readonly List<WintainiumApplicationModel> _allApplications = [];
    private WintainiumApplicationQuery _query = new();

    public ObservableCollection<WintainiumApplicationModel> Applications { get; } = [];

    public WintainiumApplicationQuery Query => _query;

    public event PropertyChangedEventHandler? PropertyChanged;

    public void SetApplications(IEnumerable<WintainiumApplicationModel> applications)
    {
        ArgumentNullException.ThrowIfNull(applications);

        _allApplications.Clear();
        _allApplications.AddRange(applications);
        RefreshVisibleApplications();
    }

    public void SetQuery(WintainiumApplicationQuery query)
    {
        ArgumentNullException.ThrowIfNull(query);

        if (_query == query)
        {
            return;
        }

        _query = query;
        RefreshVisibleApplications();
        OnPropertyChanged(nameof(Query));
    }

    private void RefreshVisibleApplications()
    {
        Applications.Clear();

        foreach (var application in WintainiumApplicationCollectionQuery.Apply(_allApplications, _query))
        {
            Applications.Add(application);
        }

        OnPropertyChanged(nameof(Applications));
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
