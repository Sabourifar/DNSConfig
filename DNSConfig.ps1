$ErrorActionPreference = 'Stop'
$script:Version = '26.08'
[Console]::Title = "DNSConfig $($script:Version)"

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

Add-Type -Namespace Win32 -Name Dns -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dnsapi.dll", EntryPoint="DnsFlushResolverCache")]
public static extern bool DnsFlushResolverCache();
'@

$script:DnsProviders = [ordered]@{
    "1" = @{ Name = "Cloudflare"; Primary = "1.1.1.1";        Secondary = "1.0.0.1" }
    "2" = @{ Name = "Google";     Primary = "8.8.8.8";        Secondary = "8.8.4.4" }
    "3" = @{ Name = "Quad9";      Primary = "9.9.9.9";        Secondary = "149.112.112.112" }
    "4" = @{ Name = "Shecan";     Primary = "178.22.122.100"; Secondary = "185.51.200.2" }
    "5" = @{ Name = "Electro";    Primary = "78.157.42.100";  Secondary = "78.157.42.101" }
    "6" = @{ Name = "TCI";        Primary = "5.200.200.200";  Secondary = $null }
    "7" = @{ Name = "Localhost";  Primary = "127.0.0.1";      Secondary = $null }
}

$scriptPath = $PSCommandPath
if (-not $scriptPath) {
    Write-Host ''
    Write-Host "  $($script:SYM_ERR) This script must be downloaded and run as a file, not piped via" -ForegroundColor Red
    Write-Host '          "irm ... | iex" or similar. Save DNSConfig.ps1 locally and run it.' -ForegroundColor Red
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

function Write-Pad {
    param([string]$Text, [int]$Width)
    if (-not $Text) { $Text = '' }
    if ($Text.Length -gt $Width) {
        if ($Width -gt 3) { return $Text.Substring(0, $Width - 3) + "..." }
        else { return $Text.Substring(0, $Width) }
    }
    return $Text.PadRight($Width)
}

function Write-SectionHeader {
    param([string]$Label)
    $prefix = "  $Label "
    $dashCount = $script:RuleWidth - $prefix.Length
    if ($dashCount -lt 1) { $dashCount = 1 }
    Write-Host "$prefix$($script:CH_H * $dashCount)"
}

function Write-AppHeader {
    Write-Host "  DNSConfig v$($script:Version) $($script:SYM_BULLET) by Sabourifar"
    Write-Host ''
}

function Write-StatusLine {
    param([string]$Label1, [string]$Value1, [string]$Label2, [string]$Value2)
    $p1 = Format-Leader $Label1 20
    $v1 = Write-Pad $Value1 39
    $p2 = Format-Leader $Label2 20
    Write-Host "  $p1$v1$p2$Value2"
}

function Write-LeaderValue {
    param([string]$Label, [string]$Value, [int]$Width = 31)
    Write-Host ("  " + (Format-Leader $Label $Width) + $Value)
}

function Write-NumberedRow {
    param([string]$Num, [string]$Text)
    Write-Host ("  " + $Num.PadLeft(2) + "   " + $Text)
}

$script:PROV_NUM_W       = 4
$script:PROV_NAME_W      = 10
$script:PROV_BEFORE_PRI  = 15
$script:PROV_PRI_W       = 14
$script:PROV_AFTER_PRI   = 16

function Write-ProviderRow {
    param([string]$Num, [string]$Name, [string]$Primary, [string]$Secondary)
    $sec = if ($Secondary) { $Secondary } else { $script:SYM_EMDASH }

    $c1 = Write-Pad $Num $script:PROV_NUM_W
    $c2 = Write-Pad $Name $script:PROV_NAME_W
    $c3 = Write-Pad $Primary $script:PROV_PRI_W

    Write-Host "  $c1$c2$(' ' * $script:PROV_BEFORE_PRI)$c3$(' ' * $script:PROV_AFTER_PRI)$sec"
}

$script:PING_PROV_W      = 10
$script:PING_BEFORE_SRV  = 16
$script:PING_SRV_W       = 15
$script:PING_AFTER_SRV   = 16
$script:PING_LAT_W       = 7

function Write-KeyRow {
    param([string]$Key, [string]$Text)
    Write-Host ("   " + $Key.PadRight(12) + $Text)
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
    Write-Host "  $($script:SYM_ERR) $Text" -ForegroundColor Red
}

function Write-OkLine {
    param([string]$Text)
    Write-Host "  $($script:SYM_OK) $Text" -ForegroundColor Green
}

function Test-ValidIPv4 {
    param([string]$Ip)
    if ($Ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { return $false }
    $parsed = $null
    return [System.Net.IPAddress]::TryParse($Ip, [ref]$parsed)
}

function Test-ServerLatency {
    param([string]$Ip, [int]$TimeoutMs = 200, [int]$Count = 3)
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

            if ($i -lt ($Count - 1)) { Start-Sleep -Milliseconds 100 }
        }
    } finally { 
        $ping.Dispose() 
    }

    if ($successCount -eq 0) { return 'N/A' }

    $avg = $sum / $successCount
    if ($avg -lt 1) { return '<1ms' }
    
    return "$([math]::Round($avg))ms"
}

function Invoke-Action {
    param([string]$ProgressText, [string]$SuccessText, [string]$FailText, [scriptblock]$Action)
    Write-Host "  $ProgressText"
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
    } catch { $failed = $true }
    Write-Host -NoNewline ("  " + (Format-Leader $Label 57))
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

function Set-DnsServers {
    param([string]$Primary, [string]$Secondary, [int]$IfIndex, [string]$ProviderName)
    Clear-Host
    if ($ProviderName) { Write-SectionHeader "APPLYING $($ProviderName.ToUpper()) DNS" }
    else { Write-SectionHeader 'MANUAL DNS CONFIGURATION' }
    Write-Host ''
    $servers = @($Primary); if ($Secondary) { $servers += $Secondary }
    Invoke-Action -ProgressText 'Applying DNS settings...' `
        -SuccessText 'DNS servers updated successfully.' `
        -FailText 'Failed to update DNS servers.' `
        -Action { Set-DnsClientServerAddress -InterfaceIndex $IfIndex -ServerAddresses $servers -ErrorAction Stop } | Out-Null
    Write-Host ''
    Clear-DnsCache
}

function Set-DhcpDns {
    param([int]$IfIndex)
    Clear-Host
    Write-SectionHeader 'AUTOMATIC DNS · DHCP'
    Write-Host ''
    Invoke-Action -ProgressText 'Applying DNS settings...' `
        -SuccessText 'DNS servers updated successfully.' `
        -FailText 'Failed to reset DNS servers.' `
        -Action { Set-DnsClientServerAddress -InterfaceIndex $IfIndex -ResetServerAddresses -ErrorAction Stop } | Out-Null
    Write-Host ''
    Clear-DnsCache
    Write-Host ''
    Show-BackQuitPrompt
}

function Reset-NetworkSettings {
    Clear-Host
    Write-SectionHeader 'RESET NETWORK SETTINGS'
    Write-Host ''
    Write-Host "  $($script:SYM_WARN)  Warning: this will temporarily interrupt network connectivity." -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  The following actions will be performed:'
    Write-Host ''
    foreach ($item in 'Reset Winsock catalog', 'Reset TCP/IP stack', 'Reset Windows Firewall', 'Clear DNS cache', 'Release and renew IP configuration') {
        Write-Host "    $($script:SYM_BULLET) $item"
    }
    Write-Host ''
    while ($true) {
        $yn = Read-Trimmed (Get-Prompt 'Continue? Y/n')
        Write-Host ''
        if ($yn -in 'y', 'yes', '') { break }
        if ($yn -in 'n', 'no', 'b') { Show-MainMenu; return }
        if ($yn -eq 'q') { exit 0 }
        Write-ErrorLine 'Please answer Y or N.'
        Write-Host ''
    }
    Clear-Host
    Write-SectionHeader 'RESET NETWORK SETTINGS'
    Write-Host ''
    Write-Host '  Resetting network settings...'
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
    Write-Host "  $($script:SYM_INFO) Restart your computer to apply all changes."
    Write-Host ''
    Show-BackQuitPrompt
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

    if (-not $activeNic) { Show-NoInterfaceMenu; return }

    $ifName = $activeNic.Name
    $macRaw = $activeNic.GetPhysicalAddress().ToString()
    $mac = if ($macRaw) { ($macRaw -replace '(.{2})(?!$)', '$1-') } else { 'Not available' }
    $props = $activeNic.GetIPProperties()

    $localIP = 'Not available'
    $ipv4 = $props.UnicastAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
    if ($ipv4) { $localIP = $ipv4.Address.ToString() }

    $gateway = 'Not available'
    $gw = $props.GatewayAddresses | Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
    if ($gw) { $gateway = $gw.Address.ToString() }

    $ifIndex = $null
    try { $ifIndex = $props.GetIPv4Properties().Index } catch {}
    if ($null -eq $ifIndex) {
        $ifIndex = (Get-NetAdapter -Name $ifName -ErrorAction SilentlyContinue).ifIndex
    }
    if ($null -eq $ifIndex) { Show-NoInterfaceMenu; return }

    $primaryDns = $null
    $secondaryDns = $null
    try {
        $nicGuid = $activeNic.Id.Trim('{', '}')
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{$nicGuid}"
        if (-not (Test-Path $regPath)) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$nicGuid"
        }
        if (Test-Path $regPath) {
            $regProps = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            if ($regProps) {
                $ns = $null
                if ($regProps.PSObject.Properties.Name -contains 'NameServer') {
                    $nsVal = $regProps.NameServer
                    if ($nsVal -and $nsVal -ne '') { $ns = $nsVal }
                }
                if (-not $ns -and $regProps.PSObject.Properties.Name -contains 'DhcpNameServer') {
                    $nsVal = $regProps.DhcpNameServer
                    if ($nsVal -and $nsVal -ne '') { $ns = $nsVal }
                }
                if ($ns) {
                    $nsArray = @($ns)
                    $servers = @($nsArray | ForEach-Object { $_ -split '[,\s]' } | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' })
                    if ($servers.Count -gt 0) { $primaryDns = $servers[0] }
                    if ($servers.Count -gt 1) { $secondaryDns = $servers[1] }
                }
            }
        }
    } catch {}

    $dnsParts = @()
    if ($primaryDns) { $dnsParts += $primaryDns }
    if ($secondaryDns) { $dnsParts += $secondaryDns }
    $dnsStr = if ($dnsParts.Count -eq 0) { 'Not configured' } else { ($dnsParts -join ', ') }

    Write-SectionHeader 'STATUS'
    Write-Host ''
    
    Write-StatusLine 'Interface' $ifName 'Active DNS' $dnsStr
    Write-StatusLine 'Gateway' $gateway 'Local IP' $localIP
    
    Write-Host -NoNewline ("  " + (Format-Leader 'MAC' 20) + (Write-Pad $mac 39) + (Format-Leader 'Public IP' 20))
    
    try {
        $pub = (& curl.exe -s --connect-timeout 1 --max-time 2 http://icanhazip.com 2>$null).Trim()
        if (-not $pub) { $pub = 'Not available' }
    } catch { $pub = 'Not available' }
    Write-Host $pub
    
    Write-Host ''

    Write-SectionHeader 'PROVIDERS'
    Write-Host ''
    Write-ProviderRow '#' 'Name' 'Primary' 'Secondary'
    foreach ($key in $script:DnsProviders.Keys) {
        $p = $script:DnsProviders[$key]
        Write-ProviderRow $key $p.Name $p.Primary $p.Secondary
    }
    Write-Host ''

    Write-SectionHeader 'TOOLS'
    Write-Host ''
    Write-NumberedRow '8'  'Test DNS latency'
    Write-NumberedRow '9'  'Configure DNS manually'
    Write-NumberedRow '10' 'Use automatic DNS (DHCP)'
    Write-NumberedRow '11' 'Flush DNS cache'
    Write-NumberedRow '12' 'Reset network settings'
    Write-NumberedRow '0'  'Quit'
    Write-Host ''

    $netData = @{ IfIndex = $ifIndex; Mac = $mac; DnsPrimary = $primaryDns; DnsSecondary = $secondaryDns }

    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''
        switch ($choice) {
            '0'  { exit 0 }
            '8'  { Show-PingMenu; return }
            '9'  { Show-ManualDnsMenu -NetData $netData; return }
            '10' { Set-DhcpDns -IfIndex $ifIndex; return }
            '11' {
                Clear-Host; Write-SectionHeader 'CLEAR DNS CACHE'; Write-Host ''
                Clear-DnsCache; Write-Host ''; Show-BackQuitPrompt; return
            }
            '12' { Reset-NetworkSettings; return }
            default {
                if ($script:DnsProviders.Contains($choice)) {
                    $p = $script:DnsProviders[$choice]
                    Set-DnsServers -Primary $p.Primary -Secondary $p.Secondary -IfIndex $ifIndex -ProviderName $p.Name
                    Write-Host ''; Show-BackQuitPrompt; return
                }
                Write-ErrorLine 'Invalid option. Please try again.'
                Write-Host ''
            }
        }
    }
}

function Show-NoInterfaceMenu {
    Clear-Host
    Write-AppHeader
    Write-SectionHeader 'NO ACTIVE NETWORK INTERFACE'
    Write-Host ''
    Write-NumberedRow '1' 'Clear DNS cache'
    Write-NumberedRow '0' 'Quit'
    Write-Host ''
    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''
        if ($choice -eq '1') {
            Clear-Host; Write-SectionHeader 'CLEAR DNS CACHE'; Write-Host ''
            Clear-DnsCache; Write-Host ''; Show-BackQuitPrompt; return
        }
        if ($choice -eq '0') { exit 0 }
        Write-ErrorLine 'Invalid option. Please try again.'
        Write-Host ''
    }
}

function Show-PingMenu {
    Clear-Host
    Write-SectionHeader 'DNS LATENCY TEST'
    Write-Host ''

    $prefix = "   "

    $h1 = Write-Pad 'Provider' $script:PING_PROV_W
    $h2 = Write-Pad 'Server' $script:PING_SRV_W
    $h3 = 'Latency'.PadLeft($script:PING_LAT_W)
    Write-Host "$prefix$h1$(' ' * $script:PING_BEFORE_SRV)$h2$(' ' * $script:PING_AFTER_SRV)$h3    Status"

    foreach ($key in $script:DnsProviders.Keys) {
        $p = $script:DnsProviders[$key]
        foreach ($server in @($p.Primary, $p.Secondary)) {
            if (-not $server) { continue }
            $lat = Test-ServerLatency $server
            $isOk = $lat -ne 'N/A'

            $c1 = Write-Pad $p.Name $script:PING_PROV_W
            $c2 = Write-Pad $server $script:PING_SRV_W
            $c3 = $lat.PadLeft($script:PING_LAT_W)

            Write-Host -NoNewline "$prefix$c1$(' ' * $script:PING_BEFORE_SRV)$c2$(' ' * $script:PING_AFTER_SRV)$c3    "
            if ($isOk) { Write-Host "$($script:SYM_DOT) OK" -ForegroundColor Green }
            else { Write-Host "$($script:SYM_ERR) Timeout" -ForegroundColor Red }
        }
    }

    Write-Host ''
    Write-KeyRow 'R' 'Repeat test'
    Write-KeyRow 'Enter' 'Back'
    Write-KeyRow '0' 'Quit'
    Write-Host ''
    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''
        if ($choice -match '^[Rr]$') { Show-PingMenu; return }
        if ($choice -eq '') { Show-MainMenu; return }
        if ($choice -eq '0') { exit 0 }
        Write-ErrorLine 'Invalid option. Please try again.'
        Write-Host ''
    }
}

function Show-ManualDnsMenu {
    param($NetData)
    Clear-Host
    Write-SectionHeader 'MANUAL DNS CONFIGURATION'
    Write-Host ''
    
    Write-Host '  Current DNS configuration:'
    if ($NetData.DnsPrimary) {
        Write-LeaderValue 'Primary DNS' $NetData.DnsPrimary
    } else {
        Write-LeaderValue 'Primary DNS' 'Not set'
    }

    if ($NetData.DnsSecondary) {
        Write-LeaderValue 'Secondary DNS' $NetData.DnsSecondary
    }
    
    Write-Host ''
    Write-KeyRow 'Enter' 'Back'
    Write-KeyRow '0' 'Quit'
    Write-Host ''
    $dns1 = $null
    while ($true) {
        $dns1 = Read-Trimmed (Get-Prompt 'Primary DNS')
        Write-Host ''
        if ($dns1 -eq '') { Show-MainMenu; return }
        if ($dns1 -eq '0') { exit 0 }
        if (Test-ValidIPv4 $dns1) { break }
        Write-ErrorLine 'Invalid IP address.'
        Write-Host ''
    }
    Write-KeyRow 'S' 'Skip'
    Write-KeyRow 'Enter' 'Back'
    Write-KeyRow '0' 'Quit'
    Write-Host ''
    $dns2 = $null
    while ($true) {
        $in2 = Read-Trimmed (Get-Prompt 'Secondary DNS (optional)')
        Write-Host ''
        if ($in2 -match '^[Ss]$') { break }
        if ($in2 -eq '') { Show-MainMenu; return }
        if ($in2 -eq '0') { exit 0 }
        if (Test-ValidIPv4 $in2) { $dns2 = $in2; break }
        Write-ErrorLine 'Invalid IP address.'
        Write-Host ''
    }
    Write-SectionHeader 'SUMMARY'
    Write-Host ''
    Write-LeaderValue 'Primary DNS' $dns1
    if ($dns2) { Write-LeaderValue 'Secondary DNS' $dns2 }
    Write-Host ''
    while ($true) {
        $yn = Read-Trimmed (Get-Prompt 'Apply this configuration? Y/n')
        Write-Host ''
        if ($yn -in 'n', 'no', 'b') { Show-MainMenu; return }
        if ($yn -eq 'q') { exit 0 }
        if ($yn -in 'y', 'yes', '') {
            Set-DnsServers -Primary $dns1 -Secondary $dns2 -IfIndex $NetData.IfIndex
            Write-Host ''
            Show-BackQuitPrompt
            return
        }
        Write-ErrorLine 'Please answer Y or N.'
        Write-Host ''
    }
}

function Show-BackQuitPrompt {
    Write-KeyRow 'Enter' 'Back'
    Write-KeyRow '0' 'Quit'
    Write-Host ''
    while ($true) {
        $choice = Read-Trimmed (Get-Prompt 'Select an option')
        Write-Host ''
        if ($choice -eq '') { Show-MainMenu; return }
        if ($choice -eq '0') { exit 0 }
        Write-ErrorLine 'Invalid option. Please try again.'
        Write-Host ''
    }
}

Show-MainMenu
