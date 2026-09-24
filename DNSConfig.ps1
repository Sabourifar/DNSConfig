$ErrorActionPreference = 'Stop'
[Console]::Title = "DNSConfig"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$script:SYM_OK     = [string][char]0x2713
$script:SYM_ERR    = [string][char]0x2717
$script:SYM_WARN   = [string][char]0x26A0
$script:SYM_INFO   = [string][char]0x24D8
$script:SYM_PROMPT = [string][char]0x203A
$script:SYM_DOT    = [string][char]0x25CF
$script:SYM_BULLET = [string][char]0x00B7
$script:SYM_EMDASH = [string][char]0x2014
$script:CH_H       = [string][char]0x2500

$script:RuleWidth = 120
$script:NetData   = $null

if (-not ('Win32.Dns' -as [type])) {
    Add-Type -Namespace Win32 -Name Dns -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dnsapi.dll", EntryPoint="DnsFlushResolverCache")]
public static extern bool DnsFlushResolverCache();
'@
}

$script:DnsProviders = [ordered]@{
    "1"  = @{ Name = "Asiatech";           IPv4Primary = "185.98.113.113"; IPv4Secondary = "185.98.114.114"; IPv6Primary = $null; IPv6Secondary = $null }
    "2"  = @{ Name = "Shatel";             IPv4Primary = "85.15.1.14";     IPv4Secondary = "85.15.1.15";     IPv6Primary = $null; IPv6Secondary = $null }
    "3"  = @{ Name = "Mokhaberat (TCI)";   IPv4Primary = "5.200.200.200";  IPv4Secondary = $null;             IPv6Primary = $null; IPv6Secondary = $null }
    "4"  = @{ Name = "Pishgaman";          IPv4Primary = "5.202.100.100";  IPv4Secondary = "5.202.100.101";  IPv6Primary = $null; IPv6Secondary = $null }
    "5"  = @{ Name = "Shelter";            IPv4Primary = "94.103.125.157"; IPv4Secondary = "94.103.125.158"; IPv6Primary = $null; IPv6Secondary = $null }
    "6"  = @{ Name = "Electro Team";       IPv4Primary = "78.157.42.100";  IPv4Secondary = "78.157.42.101";  IPv6Primary = $null; IPv6Secondary = $null }
    "7"  = @{ Name = "Zeus DNS";           IPv4Primary = "37.32.5.60";     IPv4Secondary = "37.32.5.61";     IPv6Primary = $null; IPv6Secondary = $null }
    "8"  = @{ Name = "Vanilla";            IPv4Primary = "194.146.68.68";  IPv4Secondary = "194.146.68.66";  IPv6Primary = $null; IPv6Secondary = $null }
    "9"  = @{ Name = "Shecan";             IPv4Primary = "178.22.122.100"; IPv4Secondary = "185.51.200.2";   IPv6Primary = $null; IPv6Secondary = $null }
    "10" = @{ Name = "Begzar";             IPv4Primary = "185.55.226.26";  IPv4Secondary = "185.55.226.25";  IPv6Primary = $null; IPv6Secondary = $null }
    "11" = @{ Name = "AliDNS (Alibaba)";   IPv4Primary = "223.5.5.5";      IPv4Secondary = "223.6.6.6";      IPv6Primary = $null; IPv6Secondary = $null }
    "12" = @{ Name = "NextDNS";            IPv4Primary = "45.90.28.0";     IPv4Secondary = "45.90.30.0";     IPv6Primary = $null; IPv6Secondary = $null }
    "13" = @{ Name = "DynX Anti-Sanction"; IPv4Primary = "10.139.177.18";  IPv4Secondary = "10.139.177.16";  IPv6Primary = $null; IPv6Secondary = $null }
    "14" = @{ Name = "DynX Adblocker";     IPv4Primary = "109.70.74.38";   IPv4Secondary = "109.70.74.68";   IPv6Primary = "2a00:c98:2050:a04d:1::400"; IPv6Secondary = $null }
    "15" = @{ Name = "Cloudflare";         IPv4Primary = "1.1.1.1";        IPv4Secondary = "1.0.0.1";        IPv6Primary = "2606:4700:4700::1111"; IPv6Secondary = "2606:4700:4700::1001" }
    "16" = @{ Name = "Google";             IPv4Primary = "8.8.8.8";        IPv4Secondary = "8.8.4.4";        IPv6Primary = "2001:4860:4860::8888"; IPv6Secondary = "2001:4860:4860::8844" }
    "17" = @{ Name = "OpenDNS";            IPv4Primary = "208.67.222.222"; IPv4Secondary = "208.67.220.220"; IPv6Primary = "2620:119:35::35"; IPv6Secondary = "2620:119:53::53" }
    "18" = @{ Name = "Quad9";              IPv4Primary = "9.9.9.9";        IPv4Secondary = "149.112.112.112"; IPv6Primary = "2620:fe::fe"; IPv6Secondary = "2620:fe::9" }
    "19" = @{ Name = "AdGuard";            IPv4Primary = "94.140.14.14";   IPv4Secondary = "94.140.15.15";   IPv6Primary = "2a10:50c0::ad1:ff"; IPv6Secondary = "2a10:50c0::ad2:ff" }
    "20" = @{ Name = "Yandex DNS";         IPv4Primary = "77.88.8.8";      IPv4Secondary = "77.88.8.1";      IPv6Primary = "2a02:6b8::feed:0ff"; IPv6Secondary = "2a02:6b8:0:1::feed:0ff" }
}

$scriptPath = $PSCommandPath
if (-not $scriptPath) {
    Write-Host ''
    Write-Host "    $($script:SYM_ERR) This script must be downloaded and run as a file, not piped via" -ForegroundColor Red
    Write-Host '            "irm ... | iex" or similar. Save DNSConfig.ps1 locally and run it.' -ForegroundColor Red
    Write-Host ''
    exit 1
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $wt = Get-Command wt.exe -ErrorAction SilentlyContinue
    try {
        if ($wt) {
            Start-Process wt.exe -ArgumentList "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        } else {
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
        }
    } catch {}
    exit
}

function Format-Leader {
    param([string]$Label, [int]$Width)
    $dotsLen = $Width - $Label.Length - 2
    if ($dotsLen -lt 1) { $dotsLen = 1 }
    return "$Label " + ('.' * $dotsLen) + ' '
}

function Write-SectionHeader {
    param([string]$Label)
    $prefix = "  $Label "
    $dashCount = $script:RuleWidth - $prefix.Length
    if ($dashCount -lt 1) { $dashCount = 1 }
    Write-Host "$prefix$($script:CH_H * $dashCount)"
}

function Write-AppHeader {
    Write-Host "  DNSConfig v26.09.2 $($script:SYM_BULLET) by Sabourifar"
    Write-Host ''
}

function Write-LeaderValue {
    param([string]$Label, [string]$Value, [int]$Width = 31)
    Write-Host ("    " + (Format-Leader $Label $Width) + $Value)
}

function Write-MenuRow {
    param([string]$Key, [string]$Text, [int]$Width = 0)
    $w = [Math]::Max($Width, $Key.Length)
    Write-Host ("    " + $Key.PadRight($w) + '   ' + $Text)
}

function Write-ProviderRow {
    param([string]$Num, $Provider)

    $primary = if ($Provider.IPv4Primary) { $Provider.IPv4Primary } else { $script:SYM_EMDASH }
    $secondary = if ($Provider.IPv4Secondary) { $Provider.IPv4Secondary } else { $script:SYM_EMDASH }

    Write-Host ("    {0,-4} {1,-22} {2,-38} {3}" -f $Num, $Provider.Name, $primary, $secondary)

    if ($Provider.IPv6Primary -or $Provider.IPv6Secondary) {
        $primary6 = if ($Provider.IPv6Primary) { $Provider.IPv6Primary } else { $script:SYM_EMDASH }
        $secondary6 = if ($Provider.IPv6Secondary) { $Provider.IPv6Secondary } else { $script:SYM_EMDASH }
        Write-Host ("    {0,-4} {1,-22} {2,-38} {3}" -f '', '', $primary6, $secondary6)
    }
}

function Get-Prompt {
    param([string]$Label)
    return "  $Label $($script:SYM_PROMPT) "
}

function Read-Trimmed {
    param([string]$Prompt)
    Write-Host -NoNewline $Prompt
    $val = Read-Host
    return $val.Trim()
}

function Write-ErrorLine {
    param([string]$Text)
    Write-Host "    $($script:SYM_ERR) $Text" -ForegroundColor Red
}

function Write-OkLine {
    param([string]$Text)
    Write-Host "    $($script:SYM_OK) $Text" -ForegroundColor Green
}

function Confirm-YesNo {
    param([string]$PromptText)

    while ($true) {
        $yn = Read-Trimmed (Get-Prompt $PromptText)
        Write-Host ''

        if ($yn -in 'y', 'yes', '') { return $true }
        if ($yn -in 'n', 'no', 'b') { return $false }
        if ($yn -eq '0') { exit 0 }

        Write-ErrorLine 'Please answer Y or N.'
        Write-Host ''
    }
}

function Read-DnsInput {
    param(
        [string]$PromptText,
        [scriptblock]$Validator,
        [string]$InvalidMessage,
        [switch]$AllowSkip
    )

    while ($true) {
        $val = Read-Trimmed (Get-Prompt $PromptText)
        Write-Host ''

        if ($AllowSkip -and $val -match '^[Ss]$') { return @{ Back = $false; Value = $null } }
        if ($val -eq '') { return @{ Back = $true; Value = $null } }
        if ($val -eq '0') { exit 0 }

        if (& $Validator $val) { return @{ Back = $false; Value = $val } }

        Write-ErrorLine $InvalidMessage
        Write-Host ''
    }
}

function Read-ProtocolChoice {
    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''

        if ($choice -eq '') { return $null }
        if ($choice -eq '0') { exit 0 }
        if ($choice -eq '1') { return 'IPv4' }
        if ($choice -eq '2') { return 'IPv6' }
        if ($choice -eq '3') { return 'Both' }

        Write-ErrorLine 'Invalid option. Please try again.'
        Write-Host ''
    }
}

function Test-ValidIPv4 {
    param([string]$Ip)
    if ([string]::IsNullOrWhiteSpace($Ip)) { return $false }
    if ($Ip -notmatch '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$') { return $false }
    return $true
}

function Test-ValidIPv6 {
    param([string]$Ip)

    if ([string]::IsNullOrWhiteSpace($Ip)) { return $false }
    if ($Ip -notmatch ':') { return $false }
    if ($Ip -match '[.%]') { return $false }

    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($Ip, [ref]$parsed)) { return $false }
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) { return $false }
    if ($parsed.IsIPv6LinkLocal -or $parsed.IsIPv6Multicast) { return $false }
    if ($parsed.ToString() -eq '::') { return $false }

    return $true
}

function Test-ServerLatency {
    param([string]$Ip, [int]$TimeoutMs = 700, [int]$Count = 2)

    if (-not $Ip) { return 'N/A' }

    $ping = [System.Net.NetworkInformation.Ping]::new()
    $sum = 0
    $successCount = 0
    $successStatus = [System.Net.NetworkInformation.IPStatus]::Success

    try {
        for ($i = 0; $i -lt $Count; $i++) {
            try {
                $reply = $ping.Send($Ip, $TimeoutMs)
                if ($reply.Status -eq $successStatus) {
                    $sum += $reply.RoundtripTime
                    $successCount++
                }
            } catch {}

            if ($i -lt ($Count - 1)) { Start-Sleep -Milliseconds 50 }
        }
    } finally {
        $ping.Dispose()
    }

    if ($successCount -eq 0) { return 'N/A' }

    $avg = $sum / $successCount
    if ($avg -lt 1) { return '<1ms' }

    return "$([math]::Round($avg))ms"
}

function Start-PublicIpLookup {
    param([ValidateSet('IPv4', 'IPv6')][string]$Family)

    $lookup = [pscustomobject]@{ Process = $null; Family = $Family; StdOutTask = $null }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $curl) { return $lookup }

    $flag = if ($Family -eq 'IPv4') { '-4' } else { '-6' }
    $url = 'http://icanhazip.com'

    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = 'curl.exe'
        $psi.Arguments = "-s --connect-timeout 1 --max-time 2 $flag $url"
        $psi.RedirectStandardOutput = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        $lookup.Process = $proc
        $lookup.StdOutTask = $proc.StandardOutput.ReadToEndAsync()
    } catch {}

    return $lookup
}

function Complete-PublicIpLookup {
    param($Lookup)

    if (-not $Lookup -or -not $Lookup.Process) { return 'Not available' }

    try {
        if (-not $Lookup.Process.WaitForExit(2500)) {
            try { $Lookup.Process.Kill() } catch {}
            return 'Not available'
        }

        $ip = $Lookup.StdOutTask.GetAwaiter().GetResult().Trim()

        if (($Lookup.Family -eq 'IPv4' -and (Test-ValidIPv4 $ip)) -or ($Lookup.Family -eq 'IPv6' -and (Test-ValidIPv6 $ip))) {
            return $ip
        }
    } catch {}

    return 'Not available'
}

function Stop-PublicIpLookup {
    param($Lookup)

    if ($Lookup -and $Lookup.Process -and -not $Lookup.Process.HasExited) {
        try { $Lookup.Process.Kill() } catch {}
    }
}

function Get-InterfaceDns {
    param([int]$IfIndex, [string]$NicGuid)

    $v4 = @()
    $v6 = @()

    try {
        $v4 = @(Get-DnsClientServerAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 -ErrorAction Stop |
            Select-Object -ExpandProperty ServerAddresses |
            Where-Object { $_ } |
            ForEach-Object { $_.Trim() } |
            Where-Object { Test-ValidIPv4 $_ })
    } catch {}

    try {
        $v6 = @(Get-DnsClientServerAddress -InterfaceIndex $IfIndex -AddressFamily IPv6 -ErrorAction Stop |
            Select-Object -ExpandProperty ServerAddresses |
            Where-Object { $_ } |
            ForEach-Object { $_.Trim() } |
            Where-Object { Test-ValidIPv6 $_ })
    } catch {}

    if (($v4.Count -eq 0 -or $v6.Count -eq 0) -and $NicGuid) {
        foreach ($family in @('IPv4', 'IPv6')) {
            $service = if ($family -eq 'IPv4') { 'Tcpip' } else { 'Tcpip6' }
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$service\Parameters\Interfaces\{$NicGuid}"

            if (Test-Path $regPath) {
                try {
                    $regProps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
                    if ($regProps) {
                        $ns = $null

                        if ($regProps.PSObject.Properties.Name -contains 'NameServer') {
                            if ($regProps.NameServer) { $ns = $regProps.NameServer }
                        }

                        if (-not $ns -and $regProps.PSObject.Properties.Name -contains 'DhcpNameServer') {
                            if ($regProps.DhcpNameServer) { $ns = $regProps.DhcpNameServer }
                        }

                        if ($ns) {
                            $servers = @($ns -split '[,\s]' | Where-Object { $_ })
                            if ($family -eq 'IPv4' -and $v4.Count -eq 0) {
                                $v4 = @($servers | Where-Object { Test-ValidIPv4 $_ })
                            }
                            if ($family -eq 'IPv6' -and $v6.Count -eq 0) {
                                $v6 = @($servers | Where-Object { Test-ValidIPv6 $_ })
                            }
                        }
                    }
                } catch {}
            }
        }
    }

    return @{ IPv4 = $v4; IPv6 = $v6 }
}

function Invoke-Action {
    param([string]$ProgressText, [string]$SuccessText, [string]$FailText, [scriptblock]$Action)

    Write-Host "    $ProgressText"
    $ok = $true
    try { & $Action } catch { $ok = $false }

    if ($ok) { Write-OkLine $SuccessText } else { Write-ErrorLine $FailText }
    return $ok
}

function Invoke-Step {
    param(
        [string]$Label,
        [scriptblock]$Action,
        [int[]]$AllowedCodes = @(0, 3010)
    )

    $failed = $false
    $global:LASTEXITCODE = $null

    try {
        & $Action | Out-Null
        if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -notin $AllowedCodes) { $failed = $true }
    } catch {
        $failed = $true
    }

    Write-Host -NoNewline ("    " + (Format-Leader $Label 57))
    if ($failed) { Write-Host $script:SYM_ERR -ForegroundColor Red }
    else { Write-Host $script:SYM_OK -ForegroundColor Green }

    return $failed
}

function Clear-DnsCache {
    Invoke-Action -ProgressText 'Clearing DNS cache...' `
        -SuccessText 'DNS cache cleared successfully.' `
        -FailText 'DNS cache flush failed.' `
        -Action { if (-not [Win32.Dns]::DnsFlushResolverCache()) { throw 'DnsFlushResolverCache failed' } } | Out-Null
}

function Set-DnsServersForProtocol {
    param(
        [ValidateSet('IPv4', 'IPv6')][string]$Protocol,
        [string]$Primary,
        [string]$Secondary,
        [int]$IfIndex,
        [string]$InterfaceName
    )

    if (-not $Primary) { return $false }

    $servers = @($Primary)
    if ($Secondary) { $servers += $Secondary }

    Write-Host "    Applying $Protocol DNS..."

    try {
        Set-DnsClientServerAddress -InterfaceIndex $IfIndex -ServerAddresses $servers -ErrorAction Stop
        Write-OkLine "$Protocol DNS servers updated successfully."
        return $true
    } catch {
        $family = if ($Protocol -eq 'IPv4') { 'ipv4' } else { 'ipv6' }
        $nameArg = 'name="' + $InterfaceName + '"'

        try {
            $output = & netsh interface $family set dnsservers $nameArg source=static address=$Primary validate=no 2>&1
            if ($LASTEXITCODE -ne 0) { throw ($output | Out-String) }

            if ($Secondary) {
                $output = & netsh interface $family add dnsservers $nameArg address=$Secondary index=2 validate=no 2>&1
                if ($LASTEXITCODE -ne 0) { throw ($output | Out-String) }
            }

            Write-OkLine "$Protocol DNS servers updated successfully."
            return $true
        } catch {
            Write-ErrorLine "Failed to update $Protocol DNS servers."
            return $false
        }
    }
}

function Set-DhcpDns {
    param([ValidateSet('IPv4', 'IPv6')][string]$Protocol)

    if (-not $script:NetData) { Show-MainMenu; return }

    Clear-Host
    Write-SectionHeader "AUTOMATIC DNS $Protocol · DHCP"
    Write-Host ''

    Write-Host "    Applying $Protocol DNS settings..."
    $ok = $true

    try {
        $nameArg = 'name="' + $script:NetData.IfName + '"'
        $family = $Protocol.ToLower()
        $null = & netsh interface $family set dnsservers $nameArg source=dhcp 2>&1
        if ($LASTEXITCODE -ne 0) { $ok = $false }
    } catch { $ok = $false }

    if ($ok) { Write-OkLine "$Protocol DNS servers updated successfully." }
    else { Write-ErrorLine "Failed to reset $Protocol DNS servers." }

    Write-Host ''
    Clear-DnsCache
    Write-Host ''
    Show-BackPrompt
}

function Reset-NetworkSettings {
    Clear-Host
    Write-SectionHeader 'RESET NETWORK SETTINGS'
    Write-Host ''

    Write-Host "    $($script:SYM_WARN)  Warning: this will temporarily interrupt network connectivity." -ForegroundColor Yellow
    Write-Host ''

    Write-Host '    The following actions will be performed:'
    Write-Host ''

    foreach ($item in 'Reset Winsock catalog', 'Reset TCP/IP stack', 'Reset Windows Firewall', 'Clear DNS cache', 'Release and renew IP configuration') {
        Write-Host "      $($script:SYM_BULLET) $item"
    }

    Write-Host ''

    if (-not (Confirm-YesNo 'Continue? Y/n')) { Show-MainMenu; return }

    Clear-Host
    Write-SectionHeader 'RESET NETWORK SETTINGS'
    Write-Host ''

    Write-Host '    Resetting network settings...'
    Write-Host ''

    $anyFailed = $false

    if (Invoke-Step 'Resetting Winsock catalog' { netsh winsock reset }) { $anyFailed = $true }

    if (Invoke-Step 'Resetting TCP/IP stack' {
        $null = netsh int ipv4 reset 2>&1
        $code4 = $LASTEXITCODE
        $null = netsh int ipv6 reset 2>&1
        $code6 = $LASTEXITCODE

        if ($code4 -notin 0, 1, 3010 -or $code6 -notin 0, 1, 3010) {
            throw "ipv4 reset exited $code4, ipv6 reset exited $code6"
        }
    }) { $anyFailed = $true }

    if (Invoke-Step 'Resetting Windows Firewall' { netsh advfirewall reset }) { $anyFailed = $true }
    if (Invoke-Step 'Clearing DNS cache' { if (-not [Win32.Dns]::DnsFlushResolverCache()) { throw } }) { $anyFailed = $true }
    if (Invoke-Step 'Releasing IP configuration' { ipconfig /release }) { $anyFailed = $true }
    if (Invoke-Step 'Renewing IP configuration' { ipconfig /renew }) { $anyFailed = $true }

    Write-Host ''

    if ($anyFailed) { Write-ErrorLine 'Some steps failed to complete.' }
    else { Write-OkLine 'Network reset completed successfully.' }

    Write-Host "    $($script:SYM_INFO) Restart your computer to apply all changes."
    Write-Host ''

    Show-BackPrompt
}

function Show-BackPrompt {
    Write-MenuRow 'Enter' 'Back to main menu'
    Write-MenuRow '0' 'Quit'
    Write-Host ''

    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''

        if ($choice -eq '') {
            Show-MainMenu
            return
        }

        if ($choice -eq '0') { exit 0 }

        Write-ErrorLine 'Invalid option. Please try again.'
        Write-Host ''
    }
}

function Confirm-DisableInterface {
    if (-not $script:NetData) { Show-MainMenu; return }

    Clear-Host
    Write-SectionHeader 'DISABLE NETWORK ADAPTER'
    Write-Host ''

    Write-Host "    $($script:SYM_WARN)  This will disable $($script:NetData.IfName) and disconnect the network." -ForegroundColor Yellow
    Write-Host ''

    if (-not (Confirm-YesNo 'Continue? Y/n')) { Show-MainMenu; return }

    Clear-Host
    Write-SectionHeader 'DISABLE NETWORK ADAPTER'
    Write-Host ''

    $ok = Invoke-Action -ProgressText "Disabling $($script:NetData.IfName)..." `
        -SuccessText "$($script:NetData.IfName) disabled." `
        -FailText "Failed to disable $($script:NetData.IfName)." `
        -Action { Disable-NetAdapter -Name $script:NetData.IfName -Confirm:$false -ErrorAction Stop }

    Write-Host ''

    if ($ok) {
        Start-Sleep -Seconds 2
        Show-NoInterfaceMenu
    } else {
        Show-BackPrompt
    }
}

function Confirm-ToggleProtocol {
    param(
        [ValidateSet('IPv4', 'IPv6')][string]$Protocol,
        [string]$ComponentId,
        [string]$BreakWarning
    )

    if (-not $script:NetData) { Show-MainMenu; return }

    $currentlyEnabled = $script:NetData["${Protocol}Enabled"]
    $action = if ($currentlyEnabled) { 'DISABLE' } else { 'ENABLE' }

    Clear-Host
    Write-SectionHeader "$action $Protocol"
    Write-Host ''

    if ($currentlyEnabled) {
        Write-Host "    $($script:SYM_WARN)  This will disable $Protocol on $($script:NetData.IfName)." -ForegroundColor Yellow
        Write-Host ''
        Write-Host "    $($script:SYM_INFO) $BreakWarning"
    } else {
        Write-Host "    $($script:SYM_INFO) This will enable $Protocol on $($script:NetData.IfName)."
    }
    Write-Host ''

    if (-not (Confirm-YesNo 'Continue? Y/n')) { Show-MainMenu; return }

    Clear-Host
    Write-SectionHeader "$action $Protocol"
    Write-Host ''

    if ($currentlyEnabled) {
        $ok = Invoke-Action -ProgressText "Disabling $Protocol on $($script:NetData.IfName)..." `
            -SuccessText "$Protocol disabled on $($script:NetData.IfName)." `
            -FailText "Failed to disable $Protocol on $($script:NetData.IfName)." `
            -Action { Disable-NetAdapterBinding -Name $script:NetData.IfName -ComponentID $ComponentId -ErrorAction Stop }
    } else {
        $ok = Invoke-Action -ProgressText "Enabling $Protocol on $($script:NetData.IfName)..." `
            -SuccessText "$Protocol enabled on $($script:NetData.IfName)." `
            -FailText "Failed to enable $Protocol on $($script:NetData.IfName)." `
            -Action { Enable-NetAdapterBinding -Name $script:NetData.IfName -ComponentID $ComponentId -ErrorAction Stop }
    }

    Write-Host ''
    Show-BackPrompt
}

function Resolve-ConnectivityState {
    param([bool]$Enabled, [bool]$HasAddress)

    if (-not $Enabled) { return @{ Text = 'Disabled'; Color = 'Red'; Icon = $script:SYM_ERR } }
    if (-not $HasAddress) { return @{ Text = 'No connectivity'; Color = 'Yellow'; Icon = $script:SYM_WARN } }
    return @{ Text = 'Connected'; Color = 'Green'; Icon = $script:SYM_DOT }
}

function Write-ConnectivityStatus {
    param([string]$Icon, [string]$Text, [string]$Color)

    $spacer = if ($Icon -eq $script:SYM_WARN) { '  ' } else { ' ' }
    Write-Host -NoNewline ("    " + (Format-Leader 'Status' 13))
    Write-Host "$Icon$spacer$Text" -ForegroundColor $Color
}

function Show-NoInterfaceMenu {
    Clear-Host
    Write-AppHeader
    Write-SectionHeader 'NO ACTIVE NETWORK ADAPTER'
    Write-Host ''

    Write-Host "    $($script:SYM_INFO) No active network connection detected."
    Write-Host ''

    $adapters = @()
    try {
        $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -ne 'Up' } | Sort-Object Name)
    } catch {}

    if ($adapters.Count -eq 0) {
        Write-Host '    No disabled or disconnected adapters were found.'
        Write-Host ''
        Write-MenuRow '0' 'Quit'
        Write-Host ''

        while ($true) {
            $choice = Read-Trimmed (Get-Prompt 'Select an option')
            Write-Host ''

            if ($choice -eq '0') { exit 0 }

            Write-ErrorLine 'Invalid option. Please try again.'
            Write-Host ''
        }
    }

    Write-Host '    Select one to enable:'
    Write-Host ''

    Write-SectionHeader 'OPTIONS'
    Write-Host ''

    $index = 1
    $map = @{}

    foreach ($adapter in $adapters) {
        $map[[string]$index] = $adapter.Name
        Write-MenuRow ([string]$index) "$($adapter.Name) ($($adapter.Status))"
        $index++
    }

    Write-MenuRow '0' 'Quit'
    Write-Host ''

    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''

        if ($choice -eq '0') { exit 0 }

        if ($choice -match '^\d+$') {
            $key = [string][int]$choice
            if ($map.ContainsKey($key)) {
                $adapterName = $map[$key]

                Clear-Host
                Write-SectionHeader 'ENABLE NETWORK ADAPTER'
                Write-Host ''

                $ok = Invoke-Action -ProgressText "Enabling $adapterName..." `
                    -SuccessText "$adapterName enabled." `
                    -FailText "Failed to enable $adapterName." `
                    -Action { Enable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop }

                Write-Host ''

                if ($ok) {
                    Write-Host "    Waiting 5 seconds for network to initialize..."
                    Start-Sleep -Seconds 5
                    Show-MainMenu
                    return
                } else {
                    Show-BackPrompt
                    return
                }
            }
        }

        Write-ErrorLine 'Invalid option. Please try again.'
        Write-Host ''
    }
}

function Show-MainMenu {
    Clear-Host
    Write-AppHeader

    $nics = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()

    $activeNic = $nics | Where-Object {
        $_.OperationalStatus -eq 'Up' -and
        $_.NetworkInterfaceType -ne 'Loopback' -and
        $_.GetIPProperties().GatewayAddresses.Count -gt 0 -and
        $_.Description -notmatch 'Virtual|Hyper-V|VMware|VirtualBox|Tailscale|WireGuard|Bluetooth|Hotspot|TAP'
    } | Select-Object -First 1

    if (-not $activeNic) {
        $activeNic = $nics | Where-Object {
            $_.OperationalStatus -eq 'Up' -and
            $_.NetworkInterfaceType -ne 'Loopback' -and
            $_.Description -notmatch 'Virtual|Hyper-V|VMware|VirtualBox|Tailscale|WireGuard|Bluetooth|Hotspot|TAP'
        } | Select-Object -First 1
    }

    if (-not $activeNic) {
        try {
            $na = Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -ne 'Disabled' -and $_.Status -ne 'Not Present' } | Select-Object -First 1
            if ($na) {
                $activeNic = $nics | Where-Object {
                    $_.Name -eq $na.Name -and
                    $_.NetworkInterfaceType -ne 'Loopback'
                } | Select-Object -First 1
            }
        } catch {}
    }

    if (-not $activeNic) {
        Show-NoInterfaceMenu
        return
    }

    Write-SectionHeader 'STATUS'
    Write-Host ''

    $ifName = $activeNic.Name

    $macRaw = $activeNic.GetPhysicalAddress().ToString()
    $mac = if ($macRaw) { ($macRaw -replace '(.{2})(?!$)', '$1-') } else { 'Not available' }

    $adapterLabel = "Adapter: $ifName"
    Write-Host ("  {0,-33}MAC: {1}" -f $adapterLabel, $mac)
    Write-Host ''

    $ipv4Lookup = Start-PublicIpLookup -Family IPv4
    $ipv6Lookup = Start-PublicIpLookup -Family IPv6

    $props = $null
    try { $props = $activeNic.GetIPProperties() } catch {}

    Write-Host "  IPv4 STATUS"

    $localIPv4 = 'Not available'
    $gatewayIPv4 = 'Not available'

    if ($props) {
        $ipv4 = $props.UnicastAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        if ($ipv4) { $localIPv4 = $ipv4.Address.ToString() }

        $gw4 = $props.GatewayAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        if ($gw4) { $gatewayIPv4 = $gw4.Address.ToString() }
    }

    $ipv4Enabled = $true
    try {
        $b4 = Get-NetAdapterBinding -Name $ifName -ComponentID ms_tcpip -ErrorAction Stop
        $ipv4Enabled = $b4.Enabled
    } catch {}

    $ipv4HasAddress = -not ($localIPv4 -eq 'Not available' -or $localIPv4 -match '^169\.254\.')
    $state4 = Resolve-ConnectivityState -Enabled $ipv4Enabled -HasAddress $ipv4HasAddress
    Write-ConnectivityStatus -Icon $state4.Icon -Text $state4.Text -Color $state4.Color

    Write-LeaderValue 'Gateway' $gatewayIPv4 -Width 13
    Write-LeaderValue 'Local' $localIPv4 -Width 13

    $publicIPv4 = Complete-PublicIpLookup $ipv4Lookup
    Write-LeaderValue 'Public' $publicIPv4 -Width 13

    $ifIndex = $null
    try { $ifIndex = (Get-NetAdapter -Name $ifName -ErrorAction Stop).ifIndex } catch {}

    if ($null -eq $ifIndex -and $props) {
        try { $ifIndex = $props.GetIPv4Properties().Index } catch {}
    }

    if ($null -eq $ifIndex) {
        Stop-PublicIpLookup $ipv4Lookup
        Stop-PublicIpLookup $ipv6Lookup
        Show-NoInterfaceMenu
        return
    }

    $nicGuid = $activeNic.Id.Trim('{}')
    $dns = Get-InterfaceDns -IfIndex $ifIndex -NicGuid $nicGuid

    $dns4 = if ($ipv4Enabled -and $dns.IPv4) { @($dns.IPv4) } else { @() }
    $dns4Str = if ($dns4.Count -eq 0) { 'Not available' } else { ($dns4 -join ', ') }
    Write-LeaderValue 'DNS' $dns4Str -Width 13

    Write-Host ''

    Write-Host "  IPv6 STATUS"

    $localIPv6 = 'Not available'
    $gatewayIPv6 = 'Not available'

    if ($props) {
        $allv6 = @($props.UnicastAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetworkV6' } | ForEach-Object { $_.Address })
        if ($allv6.Count -gt 0) {
            $globalv6 = $allv6 | Where-Object { -not $_.IsIPv6LinkLocal } | Select-Object -First 1
            if ($globalv6) { $localIPv6 = $globalv6.ToString() }
            else { $localIPv6 = $allv6[0].ToString() }
        }

        $gw6 = $props.GatewayAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetworkV6' } | Select-Object -First 1
        if ($gw6) { $gatewayIPv6 = $gw6.Address.ToString() }
    }

    $ipv6Enabled = $true
    try {
        $b6 = Get-NetAdapterBinding -Name $ifName -ComponentID ms_tcpip6 -ErrorAction Stop
        $ipv6Enabled = $b6.Enabled
    } catch {}

    $ipv6HasAddress = -not ($localIPv6 -eq 'Not available' -or $localIPv6 -match '^fe80')
    $state6 = Resolve-ConnectivityState -Enabled $ipv6Enabled -HasAddress $ipv6HasAddress
    Write-ConnectivityStatus -Icon $state6.Icon -Text $state6.Text -Color $state6.Color

    Write-LeaderValue 'Gateway' $gatewayIPv6 -Width 13
    Write-LeaderValue 'Local' $localIPv6 -Width 13

    $publicIPv6 = Complete-PublicIpLookup $ipv6Lookup
    Write-LeaderValue 'Public' $publicIPv6 -Width 13

    $dns6 = if ($ipv6Enabled -and $dns.IPv6) { @($dns.IPv6) } else { @() }
    $dns6Str = if ($dns6.Count -eq 0) { 'Not available' } else { ($dns6 -join ', ') }
    Write-LeaderValue 'DNS' $dns6Str -Width 13

    $script:NetData = @{
        IfName      = $ifName
        IfIndex     = $ifIndex
        Mac         = $mac
        DnsIPv4     = $dns.IPv4
        DnsIPv6     = $dns.IPv6
        IPv4Enabled = $ipv4Enabled
        IPv6Enabled = $ipv6Enabled
    }

    Write-Host ''

    Write-SectionHeader 'OPTIONS'
    Write-Host ''

    $opt7Text = if ($ipv4Enabled) { 'Disable IPv4' } else { 'Enable IPv4' }
    $opt8Text = if ($ipv6Enabled) { 'Disable IPv6' } else { 'Enable IPv6' }

    $leftColumn = @(
        '1. Configure DNS',
        '2. Flush DNS cache',
        '3. Set IPv4 DNS to DHCP',
        '4. Set IPv6 DNS to DHCP',
        '0. Quit'
    )

    $rightColumn = @(
        '5. Reset network settings',
        '6. Disable active adapter',
        "7. $opt7Text",
        "8. $opt8Text",
        ''
    )

    for ($i = 0; $i -lt $leftColumn.Count; $i++) {
        $left = $leftColumn[$i].PadRight(31)
        Write-Host ("    {0}{1}" -f $left, $rightColumn[$i])
    }

    Write-Host ''

    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''

        switch ($choice) {
            '0' { exit 0 }
            '1' { Show-ConfigureDnsMenu; return }
            '2' {
                Clear-Host
                Write-SectionHeader 'CLEAR DNS CACHE'
                Write-Host ''
                Clear-DnsCache
                Write-Host ''
                Show-BackPrompt
                return
            }
            '3' { Set-DhcpDns -Protocol 'IPv4'; return }
            '4' { Set-DhcpDns -Protocol 'IPv6'; return }
            '5' { Reset-NetworkSettings; return }
            '6' { Confirm-DisableInterface; return }
            '7' { Confirm-ToggleProtocol -Protocol 'IPv4' -ComponentId 'ms_tcpip' -BreakWarning 'This may break most network connectivity.'; return }
            '8' { Confirm-ToggleProtocol -Protocol 'IPv6' -ComponentId 'ms_tcpip6' -BreakWarning 'This may affect IPv6 connectivity.'; return }
            default {
                Write-ErrorLine 'Invalid option. Please try again.'
                Write-Host ''
            }
        }
    }
}

function Invoke-ProviderChoice {
    param([string]$Choice)

    if ($Choice -notmatch '^\d+$') { return $false }

    $key = [string][int]$Choice
    if (-not $script:DnsProviders.Contains($key)) { return $false }

    Show-ProviderSelection -ProviderKey $key
    return $true
}

function Show-ConfigureDnsMenu {
    if (-not $script:NetData) { Show-MainMenu; return }

    Clear-Host
    Write-SectionHeader 'CONFIGURE DNS'
    Write-Host ''

    Write-Host ("    {0,-4} {1,-22} {2,-38} {3}" -f '#', 'Name', 'Primary', 'Secondary')

    foreach ($key in $script:DnsProviders.Keys) {
        Write-ProviderRow $key $script:DnsProviders[$key]
    }

    Write-Host ''

    Write-SectionHeader 'OPTIONS'
    Write-Host ''

    Write-MenuRow '21' 'Set Custom DNS' -Width 5
    Write-MenuRow '22' 'Test Provider Latency' -Width 5
    Write-MenuRow 'Enter' 'Back to main menu'
    Write-MenuRow '0' 'Quit'

    Write-Host ''

    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''

        if ($choice -eq '') { Show-MainMenu; return }
        if ($choice -eq '0') { exit 0 }
        if ($choice -eq '21') { Show-ManualDnsMenu; return }
        if ($choice -eq '22') { Show-PingMenu; return }

        if (Invoke-ProviderChoice $choice) { return }

        Write-ErrorLine 'Invalid option. Please try again.'
        Write-Host ''
    }
}

function Show-ProviderSelection {
    param([string]$ProviderKey)

    $p = $script:DnsProviders[$ProviderKey]

    $hasIPv4 = [bool]$p.IPv4Primary
    $hasIPv6 = [bool]$p.IPv6Primary

    if (-not $hasIPv4 -and -not $hasIPv6) {
        Show-ConfigureDnsMenu
        return
    }

    if ($hasIPv4 -and $hasIPv6) {
        Clear-Host
        Write-SectionHeader "CONFIGURE $($p.Name.ToUpper()) DNS"
        Write-Host ''

        $v4list = @()
        if ($p.IPv4Primary) { $v4list += $p.IPv4Primary }
        if ($p.IPv4Secondary) { $v4list += $p.IPv4Secondary }

        $v6list = @()
        if ($p.IPv6Primary) { $v6list += $p.IPv6Primary }
        if ($p.IPv6Secondary) { $v6list += $p.IPv6Secondary }

        Write-Host "    $($script:SYM_INFO) $($p.Name) IPv4 addresses: $($v4list -join ', ')"
        Write-Host "    $($script:SYM_INFO) $($p.Name) IPv6 addresses: $($v6list -join ', ')"

        Write-Host ''

        Write-SectionHeader 'OPTIONS'
        Write-Host ''

        Write-MenuRow '1' 'IPv4 only' -Width 5
        Write-MenuRow '2' 'IPv6 only' -Width 5
        Write-MenuRow '3' 'Both' -Width 5
        Write-MenuRow 'Enter' 'Back to main menu'
        Write-MenuRow '0' 'Quit'

        Write-Host ''

        $choice = Read-ProtocolChoice
        if (-not $choice) { Show-MainMenu; return }

        Invoke-ProviderDns -Provider $p -Choice $choice
        return
    }
    elseif ($hasIPv4) {
        Invoke-ProviderDns -Provider $p -Choice 'IPv4'
        return
    }
    else {
        Invoke-ProviderDns -Provider $p -Choice 'IPv6'
        return
    }
}

function Invoke-ProviderDns {
    param(
        $Provider,
        [ValidateSet('IPv4', 'IPv6', 'Both')][string]$Choice
    )

    Clear-Host
    Write-SectionHeader "APPLYING $($Provider.Name.ToUpper()) DNS"
    Write-Host ''

    $ok = $true

    if ($Choice -in 'IPv4', 'Both') {
        $result = Set-DnsServersForProtocol -Protocol 'IPv4' -Primary $Provider.IPv4Primary -Secondary $Provider.IPv4Secondary -IfIndex $script:NetData.IfIndex -InterfaceName $script:NetData.IfName
        $ok = $ok -and $result
    }

    if ($Choice -in 'IPv6', 'Both') {
        if ($Choice -eq 'Both') { Write-Host '' }

        $result = Set-DnsServersForProtocol -Protocol 'IPv6' -Primary $Provider.IPv6Primary -Secondary $Provider.IPv6Secondary -IfIndex $script:NetData.IfIndex -InterfaceName $script:NetData.IfName
        $ok = $ok -and $result
    }

    Write-Host ''
    Clear-DnsCache
    Write-Host ''

    Show-BackPrompt
}

function Show-ManualDnsMenu {
    if (-not $script:NetData) { Show-MainMenu; return }

    Clear-Host
    Write-SectionHeader 'SET CUSTOM DNS'
    Write-Host ''

    Write-Host '    Which protocol do you want to configure?'
    Write-Host ''

    Write-SectionHeader 'OPTIONS'
    Write-Host ''

    Write-MenuRow '1' 'IPv4 only' -Width 5
    Write-MenuRow '2' 'IPv6 only' -Width 5
    Write-MenuRow '3' 'Both' -Width 5
    Write-MenuRow 'Enter' 'Back to main menu'
    Write-MenuRow '0' 'Quit'

    Write-Host ''

    $choice = Read-ProtocolChoice
    if (-not $choice) { Show-MainMenu; return }

    Set-ManualDns -Mode $choice
}

function Set-ManualDns {
    param([ValidateSet('IPv4', 'IPv6', 'Both')][string]$Mode)

    Clear-Host
    Write-SectionHeader 'SET CUSTOM DNS'
    Write-Host ''

    $ipv4Primary = $null
    $ipv4Secondary = $null
    $ipv6Primary = $null
    $ipv6Secondary = $null

    if ($Mode -in 'IPv4', 'Both') {
        if ($Mode -eq 'Both') {
            Write-Host "    $($script:SYM_INFO) IPv4 DNS"
            Write-Host ''
        }

        $r = Read-DnsInput -PromptText 'Primary IPv4 DNS' -Validator { param($v) Test-ValidIPv4 $v } -InvalidMessage 'Invalid IPv4 address.'
        if ($r.Back) { Show-ManualDnsMenu; return }
        $ipv4Primary = $r.Value

        $r = Read-DnsInput -PromptText "Secondary IPv4 DNS (optional, 'S' to skip)" -Validator { param($v) Test-ValidIPv4 $v } -InvalidMessage 'Invalid IPv4 address.' -AllowSkip
        if ($r.Back) { Show-ManualDnsMenu; return }
        $ipv4Secondary = $r.Value
    }

    if ($Mode -in 'IPv6', 'Both') {
        if ($Mode -eq 'Both') {
            Write-Host "    $($script:SYM_INFO) IPv6 DNS"
            Write-Host ''
        }

        $r = Read-DnsInput -PromptText 'Primary IPv6 DNS' -Validator { param($v) Test-ValidIPv6 $v } -InvalidMessage 'Invalid IPv6 address.'
        if ($r.Back) { Show-ManualDnsMenu; return }
        $ipv6Primary = $r.Value

        $r = Read-DnsInput -PromptText "Secondary IPv6 DNS (optional, 'S' to skip)" -Validator { param($v) Test-ValidIPv6 $v } -InvalidMessage 'Invalid IPv6 address.' -AllowSkip
        if ($r.Back) { Show-ManualDnsMenu; return }
        $ipv6Secondary = $r.Value
    }

    Clear-Host
    Write-SectionHeader 'SUMMARY'
    Write-Host ''

    if ($ipv4Primary) {
        Write-LeaderValue 'Primary IPv4 DNS' $ipv4Primary
        if ($ipv4Secondary) { Write-LeaderValue 'Secondary IPv4 DNS' $ipv4Secondary }
        else { Write-LeaderValue 'Secondary IPv4 DNS' 'Not set' }
    }

    if ($Mode -eq 'Both' -and $ipv4Primary) {
        Write-Host ''
    }

    if ($ipv6Primary) {
        Write-LeaderValue 'Primary IPv6 DNS' $ipv6Primary
        if ($ipv6Secondary) { Write-LeaderValue 'Secondary IPv6 DNS' $ipv6Secondary }
        else { Write-LeaderValue 'Secondary IPv6 DNS' 'Not set' }
    }

    Write-Host ''

    $prompt = switch ($Mode) {
        'IPv4' { 'Apply IPv4 DNS configuration? Y/n' }
        'IPv6' { 'Apply IPv6 DNS configuration? Y/n' }
        default { 'Apply IPv4 and IPv6 DNS configuration? Y/n' }
    }

    if (-not (Confirm-YesNo $prompt)) { Show-ManualDnsMenu; return }

    Clear-Host
    Write-SectionHeader 'MANUAL DNS CONFIGURATION'
    Write-Host ''

    $ok = $true

    if ($ipv4Primary) {
        $result = Set-DnsServersForProtocol -Protocol 'IPv4' -Primary $ipv4Primary -Secondary $ipv4Secondary -IfIndex $script:NetData.IfIndex -InterfaceName $script:NetData.IfName
        $ok = $ok -and $result
    }

    if ($ipv6Primary) {
        if ($ipv4Primary) { Write-Host '' }

        $result = Set-DnsServersForProtocol -Protocol 'IPv6' -Primary $ipv6Primary -Secondary $ipv6Secondary -IfIndex $script:NetData.IfIndex -InterfaceName $script:NetData.IfName
        $ok = $ok -and $result
    }

    Write-Host ''
    Clear-DnsCache
    Write-Host ''

    Show-BackPrompt
}

function Show-PingMenu {
    Clear-Host
    Write-SectionHeader 'DNS LATENCY TEST'
    Write-Host ''

    Write-Host ("    {0,-2}   {1,-22} {2,-38} {3,8}    {4}" -f '#', 'Name', 'Address', 'Latency', 'Status')

    foreach ($key in $script:DnsProviders.Keys) {
        $p = $script:DnsProviders[$key]

        $addresses = @()
        if ($p.IPv4Primary) { $addresses += $p.IPv4Primary }
        if ($p.IPv4Secondary) { $addresses += $p.IPv4Secondary }
        if ($p.IPv6Primary) { $addresses += $p.IPv6Primary }
        if ($p.IPv6Secondary) { $addresses += $p.IPv6Secondary }

        $first = $true

        foreach ($addr in $addresses) {
            $lat = Test-ServerLatency $addr
            $ok = $lat -ne 'N/A'

            $numOut = if ($first) { $key } else { '' }
            $nameOut = if ($first) { $p.Name } else { '' }

            Write-Host -NoNewline ("    {0,-2}   {1,-22} {2,-38} {3,8}    " -f $numOut, $nameOut, $addr, $lat)

            if ($ok) { Write-Host "$($script:SYM_DOT) OK" -ForegroundColor Green }
            else { Write-Host "$($script:SYM_ERR) Timeout" -ForegroundColor Red }

            $first = $false
        }
    }

    Write-Host ''

    Write-SectionHeader 'OPTIONS'
    Write-Host ''

    Write-MenuRow '21' 'Repeat test' -Width 5
    Write-MenuRow 'Enter' 'Back to main menu'
    Write-MenuRow '0' 'Quit'

    Write-Host ''

    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''

        if ($choice -eq '') { Show-MainMenu; return }
        if ($choice -eq '0') { exit 0 }
        if ($choice -eq '21') { Show-PingMenu; return }

        if (Invoke-ProviderChoice $choice) { return }

        Write-ErrorLine 'Invalid option. Please try again.'
        Write-Host ''
    }
}

Show-MainMenu
