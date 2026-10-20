function Invoke-WintainiumInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [psobject]$Invocation
    )

    [pscustomobject][ordered]@{
        ExecutablePath = (Get-Command pwsh -CommandType Application | Where-Object { Test-Path -LiteralPath $_.Source -PathType Leaf } | Select-Object -First 1 -ExpandProperty Source)
        Arguments = @('-NoProfile', '-Command', "Write-Output 'fixture-installer-completed'")
        WorkingDirectory = $null
        EnvironmentVariables = @{}
    }
}

Export-ModuleMember -Function Invoke-WintainiumInstaller
