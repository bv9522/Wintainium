function Invoke-WintainiumInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Invocation
    )

    [pscustomobject][ordered]@{
        ExecutablePath = (Get-Process -Id $PID).Path
        Arguments = @('-NoProfile', '-Command', "Write-Output 'fixture-installer-completed'")
        WorkingDirectory = $null
        EnvironmentVariables = @{}
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
