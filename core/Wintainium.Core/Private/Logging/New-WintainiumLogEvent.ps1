function New-WintaniumLogEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity,

        [Parameter(Mandatory)]
        [string]$OperationId,

        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$EventName,

        [Parameter(Mandatory)]
        [string]$Message,

        [hashtable]$Context = @{}
    )

    [pscustomobject][ordered]@{
        Timestamp = [DateTimeOffset]::UtcNow
        Severity = $Severity
        OperationId = $OperationId
        Component = $Component
        EventName = $EventName
        Message = $Message
        Context = $Context
    }
}
