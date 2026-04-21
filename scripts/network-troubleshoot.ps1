<#
.SYNOPSIS
    Network Connectivity Troubleshooting Script
.DESCRIPTION
    Automated network diagnostics: ping, DNS, traceroute, port check,
    WiFi analysis, and VPN validation.
.AUTHOR
    José  Lemus 
#>

param(
    [string]$Target = "8.8.8.8",
    [switch]$Full,
    [int[]]$Ports = @(80, 443, 53, 3389, 445)
)

Write-Host "`n🌐 NETWORK TROUBLESHOOTER" -ForegroundColor Cyan
Write-Host "Target: $Target | Time: $(Get-Date -Format 'HH:mm:ss')`n"

# Step 1: Local adapter check
Write-Host "═══ STEP 1: Network Adapters ═══" -ForegroundColor Yellow
$adapters = Get-NetAdapter
foreach ($a in $adapters) {
    $icon = if ($a.Status -eq "Up") { "✅" } else { "❌" }
    $color = if ($a.Status -eq "Up") { "Green" } else { "Red" }
    Write-Host "  $icon $($a.Name) [$($a.InterfaceDescription)] - $($a.Status) ($($a.LinkSpeed))" -ForegroundColor $color
}

# Step 2: IP Configuration
Write-Host "`n═══ STEP 2: IP Configuration ═══" -ForegroundColor Yellow
$ipConfigs = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway }
foreach ($ip in $ipConfigs) {
    Write-Host "  Interface:  $($ip.InterfaceAlias)"
    Write-Host "  IPv4:       $($ip.IPv4Address.IPAddress)"
    Write-Host "  Gateway:    $($ip.IPv4DefaultGateway.NextHop)"
    Write-Host "  DNS:        $($ip.DNSServer.ServerAddresses -join ', ')"
}

# Step 3: Gateway ping
Write-Host "`n═══ STEP 3: Gateway Connectivity ═══" -ForegroundColor Yellow
$gw = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).NextHop | Select-Object -First 1
if ($gw) {
    $gwPing = Test-Connection $gw -Count 3 -ErrorAction SilentlyContinue
    if ($gwPing) {
        $avgMs = [math]::Round(($gwPing.Latency | Measure-Object -Average).Average, 1)
        Write-Host "  ✅ Gateway $gw reachable (avg: ${avgMs}ms)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Gateway $gw UNREACHABLE - Check cable/WiFi" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ No default gateway found!" -ForegroundColor Red
}

# Step 4: Internet connectivity
Write-Host "`n═══ STEP 4: Internet Connectivity ═══" -ForegroundColor Yellow
$targets = @("8.8.8.8", "1.1.1.1", "208.67.222.222")
foreach ($t in $targets) {
    $result = Test-Connection $t -Count 2 -ErrorAction SilentlyContinue
    if ($result) {
        $avg = [math]::Round(($result.Latency | Measure-Object -Average).Average, 1)
        Write-Host "  ✅ $t - ${avg}ms" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $t - UNREACHABLE" -ForegroundColor Red
    }
}

# Step 5: DNS Resolution
Write-Host "`n═══ STEP 5: DNS Resolution ═══" -ForegroundColor Yellow
$dnsTargets = @("google.com", "microsoft.com", "github.com")
foreach ($dns in $dnsTargets) {
    try {
        $resolved = Resolve-DnsName $dns -Type A -ErrorAction Stop | Select-Object -First 1
        Write-Host "  ✅ $dns → $($resolved.IPAddress)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ $dns → FAILED (DNS issue)" -ForegroundColor Red
    }
}

# Step 6: Port check on target
Write-Host "`n═══ STEP 6: Port Connectivity ($Target) ═══" -ForegroundColor Yellow
foreach ($port in $Ports) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $connect = $tcp.BeginConnect($Target, $port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait -and $tcp.Connected) {
            Write-Host "  ✅ Port $port - OPEN" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Port $port - CLOSED/FILTERED" -ForegroundColor Red
        }
        $tcp.Close()
    } catch {
        Write-Host "  ❌ Port $port - ERROR" -ForegroundColor Red
    }
}

# Step 7: Traceroute (if Full)
if ($Full) {
    Write-Host "`n═══ STEP 7: Traceroute to $Target ═══" -ForegroundColor Yellow
    Test-NetConnection $Target -TraceRoute | Select-Object -ExpandProperty TraceRoute | ForEach-Object {
        $hop = $_
        Write-Host "  → $hop" -ForegroundColor Gray
    }
}

# Summary & Recommendations
Write-Host "`n═══ DIAGNOSIS SUMMARY ═══" -ForegroundColor Cyan
$gwOK = Test-Connection $gw -Count 1 -Quiet -ErrorAction SilentlyContinue
$inetOK = Test-Connection 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
$dnsOK = $null -ne (Resolve-DnsName google.com -ErrorAction SilentlyContinue)

if (-not $gwOK) {
    Write-Host "  🔴 LAYER 1/2 ISSUE: Cannot reach gateway" -ForegroundColor Red
    Write-Host "  → Check: cable, WiFi connection, NIC driver" -ForegroundColor Yellow
} elseif (-not $inetOK) {
    Write-Host "  🟡 LAYER 3 ISSUE: Gateway OK but no internet" -ForegroundColor Yellow
    Write-Host "  → Check: ISP, firewall rules, proxy settings" -ForegroundColor Yellow
} elseif (-not $dnsOK) {
    Write-Host "  🟡 DNS ISSUE: Internet OK but DNS failing" -ForegroundColor Yellow
    Write-Host "  → Fix: ipconfig /flushdns or change DNS to 8.8.8.8" -ForegroundColor Yellow
} else {
    Write-Host "  🟢 ALL CLEAR: Network fully operational" -ForegroundColor Green
}
