function Invoke-WintainiumInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Invocation
    )

    [pscustomobject][ordered]@{
        ExecutablePath = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
        Arguments = @('-NoProfile', '-Command', "Write-Output 'fixture-installer-completed'")
        WorkingDirectory = $null
        EnvironmentVariables = @{}
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
