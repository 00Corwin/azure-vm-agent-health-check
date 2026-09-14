<#
.SYNOPSIS
    Collects Azure Windows VM Agent health and WireServer connectivity data.

.PARAMETER LogTail
    Number of WaAppAgent.log lines to include.

.PARAMETER OutputPath
    Optional JSON output path.
#>

[CmdletBinding()]
param(
    [ValidateRange(1,5000)]
    [int]$LogTail = 100,

    [string]$WireServerIp = '168.63.129.16',

    [string]$OutputPath
)

$ServiceNames = @('RdAgent','WindowsAzureGuestAgent','Winmgmt','KeyIso')
$ProcessNames = @('WaAppAgent','WindowsAzureGuestAgent')
$AgentLog = 'C:\WindowsAzure\Logs\WaAppAgent.log'

$Services = foreach ($Name in $ServiceNames) {
    try {
        Get-Service -Name $Name -ErrorAction Stop |
            Select-Object Name, Status, StartType
    }
    catch {
        [PSCustomObject]@{
            Name      = $Name
            Status    = 'NotFound'
            StartType = $null
        }
    }
}

$Processes = foreach ($Name in $ProcessNames) {
    Get-Process -Name $Name -ErrorAction SilentlyContinue |
        Select-Object ProcessName, Id, StartTime
}

$OsDisk = try {
    Get-Volume -DriveLetter C -ErrorAction Stop |
        Select-Object DriveLetter,
            @{Name='SizeGB';Expression={[math]::Round($_.Size / 1GB, 2)}},
            @{Name='FreeGB';Expression={[math]::Round($_.SizeRemaining / 1GB, 2)}}
}
catch {
    $null
}

$PortTests = foreach ($Port in 80,32526) {
    $Test = Test-NetConnection -ComputerName $WireServerIp -Port $Port -WarningAction SilentlyContinue
    [PSCustomObject]@{
        Address          = $WireServerIp
        Port             = $Port
        TcpTestSucceeded = $Test.TcpTestSucceeded
        SourceAddress    = $Test.SourceAddress
    }
}

$WireServerApi = try {
    $Response = Invoke-RestMethod `
        -Headers @{ Metadata = 'true' } `
        -Method GET `
        -Uri "http://$WireServerIp/?comp=versions" `
        -TimeoutSec 15 `
        -ErrorAction Stop

    [PSCustomObject]@{
        Success  = $true
        Response = $Response
        Error    = $null
    }
}
catch {
    [PSCustomObject]@{
        Success  = $false
        Response = $null
        Error    = $_.Exception.Message
    }
}

$Proxy = (& netsh winhttp show proxy 2>&1 | Out-String).Trim()
$LogLines = if (Test-Path $AgentLog) {
    Get-Content -Path $AgentLog -Tail $LogTail
}
else {
    @("Agent log not found: $AgentLog")
}

$Report = [PSCustomObject]@{
    ComputerName = $env:COMPUTERNAME
    CollectedAt  = (Get-Date).ToString('o')
    Services     = @($Services)
    Processes    = @($Processes)
    OsDisk       = $OsDisk
    PortTests    = @($PortTests)
    WireServer   = $WireServerApi
    WinHttpProxy = $Proxy
    AgentLogTail = @($LogLines)
}

if ($OutputPath) {
    $Report |
        ConvertTo-Json -Depth 8 |
        Set-Content -Path $OutputPath -Encoding UTF8

    Write-Output "Report written to: $OutputPath"
}

$Report
