function Invoke-WintainiumReconciliation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Request
    )

    switch ($Request.Settings.mode) {
        'unknown' {
            return [pscustomobject][ordered]@{
                OperationId = $Request.OperationId
                IsSuccessful = $true
                Status = 'Unknown'
                Evidence = [pscustomobject][ordered]@{
                    ApplicationId = $Request.ApplicationId
                    InstallationState = 'Unknown'
                    Version = $null
                    VersionSource = $null
                    Architecture = 'unknown'
                    Channel = 'unknown'
                    InstallationLocation = $null
                    EvidenceSource = 'Fixture'
                }
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
        }
        'not-installed' {
            return [pscustomobject][ordered]@{
                OperationId = $Request.OperationId
                IsSuccessful = $true
                Status = 'Reconciled'
                Evidence = [pscustomobject][ordered]@{
                    ApplicationId = $Request.ApplicationId
                    InstallationState = 'NotInstalled'
                    Version = $null
                    VersionSource = $null
                    Architecture = 'unknown'
                    Channel = 'unknown'
                    InstallationLocation = $null
                    EvidenceSource = 'Fixture'
                }
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
        }
        'bad-operation-id' {
            return [pscustomobject][ordered]@{
                OperationId = '00000000-0000-0000-0000-000000000099'
                IsSuccessful = $true
                Status = 'Reconciled'
                Evidence = $null
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
        }
        'bad-application-id' {
            return [pscustomobject][ordered]@{
                OperationId = $Request.OperationId
                IsSuccessful = $true
                Status = 'Reconciled'
                Evidence = [pscustomobject]@{
                    ApplicationId = 'different.application'
                    InstallationState = 'Installed'
                    EvidenceSource = 'Fixture'
                }
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
        }
        'bad-state' {
            return [pscustomobject][ordered]@{
                OperationId = $Request.OperationId
                IsSuccessful = $true
                Status = 'Reconciled'
                Evidence = [pscustomobject]@{
                    ApplicationId = $Request.ApplicationId
                    InstallationState = 'MaybeInstalled'
                    EvidenceSource = 'Fixture'
                }
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
        }
        'throw' {
            throw 'Simulated reconciliation failure.'
        }
        default {
            return [pscustomobject][ordered]@{
                OperationId = $Request.OperationId
                IsSuccessful = $true
                Status = 'Reconciled'
                Evidence = [pscustomobject][ordered]@{
                    ApplicationId = $Request.ApplicationId
                    InstallationState = 'Installed'
                    Version = '1.2.3'
                    VersionSource = 'Fixture'
                    Architecture = 'x64'
                    Channel = 'stable'
                    InstallationLocation = '/opt/example'
                    EvidenceSource = 'Fixture'
                }
                Errors = @()
                Warnings = @()
                LogEvents = @()
            }
        }
    }
}

Export-ModuleMember -Function Invoke-WintainiumReconciliation
