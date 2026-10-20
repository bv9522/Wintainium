function Invoke-WintainiumInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Invocation
    )

    [pscustomobject][ordered]@{
        ExecutablePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        Arguments = @('-NoProfile', '-Command', "Write-Output 'fixture-installer-completed'")
        WorkingDirectory = $null
        EnvironmentVariables = @{}
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
