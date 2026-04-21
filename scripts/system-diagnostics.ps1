<#
.SYNOPSIS
    Automated System Diagnostics for IT Support
.DESCRIPTION
    Collects system health data: hardware, disk, network, services,
    event logs, and generates a diagnostic report for troubleshooting.
.AUTHOR
    José  Lemus 
#>

param(
    [string]$ComputerName = $env:COMPUTERNAME,
    [switch]$ExportReport,
    [string]$OutputPath = ".\logs"
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$report = @()

function Add-Section {
    param([string]$Title, [string]$Content)
    $script:report += "`n{'='*50}"
    $script:report += " $Title"
    $script:report += "{'='*50}"
    $script:report += $Content
}

Write-Host "`n🔍 SYSTEM DIAGNOSTICS - $ComputerName" -ForegroundColor Cyan
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray

# 1. SYSTEM INFO
Write-Host "[1/8] System Information..." -ForegroundColor Yellow
try {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_BIOS
    
    $sysInfo = @"
Computer Name:  $($cs.Name)
Domain:         $($cs.Domain)
Manufacturer:   $($cs.Manufacturer)
Model:          $($cs.Model)
OS:             $($os.Caption) $($os.Version)
Build:          $($os.BuildNumber)
Architecture:   $($os.OSArchitecture)
Install Date:   $($os.InstallDate)
Last Boot:      $($os.LastBootUpTime)
Uptime:         $((Get-Date) - $os.LastBootUpTime | Select-Object -ExpandProperty TotalHours | ForEach-Object { [math]::Round($_, 1) }) hours
BIOS:           $($bios.SMBIOSBIOSVersion)
Serial:         $($bios.SerialNumber)
"@
    Write-Host $sysInfo
    Add-Section "SYSTEM INFORMATION" $sysInfo
} catch { Write-Host "  [ERROR] $_" -ForegroundColor Red }

# 2. CPU & MEMORY
Write-Host "[2/8] CPU & Memory..." -ForegroundColor Yellow
try {
    $cpu = Get-CimInstance Win32_Processor
    $totalRAM = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $freeRAM = [math]::Round(($os.FreePhysicalMemory / 1MB), 2)
    $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
    $ramPercent = [math]::Round(($usedRAM / $totalRAM) * 100, 1)
    $cpuLoad = (Get-CimInstance Win32_Processor).LoadPercentage
    
    $perfInfo = @"
CPU:            $($cpu.Name)
CPU Cores:      $($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads
CPU Usage:      $cpuLoad%
RAM Total:      $totalRAM GB
RAM Used:       $usedRAM GB ($ramPercent%)
RAM Free:       $freeRAM GB
"@
    
    # Health check
    if ($ramPercent -gt 90) { Write-Host "  ⚠️  HIGH MEMORY USAGE: $ramPercent%" -ForegroundColor Red }
    elseif ($ramPercent -gt 75) { Write-Host "  ⚠️  Elevated memory: $ramPercent%" -ForegroundColor Yellow }
    else { Write-Host "  ✅ Memory OK: $ramPercent%" -ForegroundColor Green }
    
    if ($cpuLoad -gt 90) { Write-Host "  ⚠️  HIGH CPU: $cpuLoad%" -ForegroundColor Red }
    else { Write-Host "  ✅ CPU OK: $cpuLoad%" -ForegroundColor Green }
    
    Add-Section "CPU & MEMORY" $perfInfo
} catch { Write-Host "  [ERROR] $_" -ForegroundColor Red }

# 3. DISK SPACE
Write-Host "[3/8] Disk Space..." -ForegroundColor Yellow
try {
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($disk in $disks) {
        $totalGB = [math]::Round($disk.Size / 1GB, 2)
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $usedPercent = [math]::Round((($totalGB - $freeGB) / $totalGB) * 100, 1)
        
        $status = if ($freeGB -lt 10) { "⚠️  CRITICAL" } elseif ($freeGB -lt 30) { "⚠️  LOW" } else { "✅ OK" }
        $color = if ($freeGB -lt 10) { "Red" } elseif ($freeGB -lt 30) { "Yellow" } else { "Green" }
        
        Write-Host "  $($disk.DeviceID) $status - $freeGB GB free / $totalGB GB total ($usedPercent% used)" -ForegroundColor $color
    }
} catch { Write-Host "  [ERROR] $_" -ForegroundColor Red }

# 4. NETWORK
Write-Host "[4/8] Network Configuration..." -ForegroundColor Yellow
try {
    $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    foreach ($adapter in $adapters) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $dns = Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $gateway = Get-NetRoute -InterfaceIndex $adapter.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
        
        Write-Host "  ✅ $($adapter.Name): $($ipConfig.IPAddress) / Gateway: $($gateway.NextHop)" -ForegroundColor Green
        Write-Host "     DNS: $($dns.ServerAddresses -join ', ')" -ForegroundColor Gray
        Write-Host "     MAC: $($adapter.MacAddress) | Speed: $($adapter.LinkSpeed)" -ForegroundColor Gray
    }
    
    # DNS resolution test
    $dnsTest = Resolve-DnsName google.com -ErrorAction SilentlyContinue
    if ($dnsTest) { Write-Host "  ✅ DNS Resolution: OK" -ForegroundColor Green }
    else { Write-Host "  ⚠️  DNS Resolution: FAILED" -ForegroundColor Red }
    
    # Internet connectivity
    $pingTest = Test-Connection 8.8.8.8 -Count 2 -Quiet
    if ($pingTest) { Write-Host "  ✅ Internet: Connected" -ForegroundColor Green }
    else { Write-Host "  ⚠️  Internet: DISCONNECTED" -ForegroundColor Red }
    
} catch { Write-Host "  [ERROR] $_" -ForegroundColor Red }

# 5. WINDOWS UPDATES
Write-Host "[5/8] Windows Updates..." -ForegroundColor Yellow
try {
    $hotfixes = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5
    Write-Host "  Last 5 updates:" -ForegroundColor Gray
    foreach ($hf in $hotfixes) {
        Write-Host "    $($hf.HotFixID) - $($hf.Description) - $($hf.InstalledOn)" -ForegroundColor Gray
    }
} catch { Write-Host "  [WARN] Cannot retrieve update history" -ForegroundColor Yellow }

# 6. CRITICAL SERVICES
Write-Host "[6/8] Critical Services..." -ForegroundColor Yellow
$criticalServices = @("wuauserv","Spooler","BITS","WinRM","Dnscache","Dhcp","EventLog","W32Time")
foreach ($svcName in $criticalServices) {
    try {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            $color = if ($svc.Status -eq "Running") { "Green" } else { "Red" }
            $icon = if ($svc.Status -eq "Running") { "✅" } else { "❌" }
            Write-Host "  $icon $($svc.DisplayName): $($svc.Status)" -ForegroundColor $color
        }
    } catch {}
}

# 7. EVENT LOG ERRORS (last 24h)
Write-Host "[7/8] Recent Errors (24h)..." -ForegroundColor Yellow
try {
    $yesterday = (Get-Date).AddHours(-24)
    $errors = Get-EventLog -LogName System -EntryType Error -After $yesterday -ErrorAction SilentlyContinue | 
              Group-Object Source | Sort-Object Count -Descending | Select-Object -First 5
    
    if ($errors) {
        foreach ($err in $errors) {
            Write-Host "  ⚠️  $($err.Name): $($err.Count) errors" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✅ No critical errors in last 24h" -ForegroundColor Green
    }
} catch { Write-Host "  [WARN] Cannot read event logs" -ForegroundColor Yellow }

# 8. SECURITY CHECK
Write-Host "[8/8] Security Status..." -ForegroundColor Yellow
try {
    # Firewall
    $fw = Get-NetFirewallProfile | Select-Object Name, Enabled
    foreach ($profile in $fw) {
        $icon = if ($profile.Enabled) { "✅" } else { "❌" }
        Write-Host "  $icon Firewall ($($profile.Name)): $(if($profile.Enabled){'Enabled'}else{'DISABLED'})" -ForegroundColor $(if($profile.Enabled){"Green"}else{"Red"})
    }
    
    # Antivirus
    $av = Get-CimInstance -Namespace "root\SecurityCenter2" -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
    if ($av) {
        Write-Host "  ✅ Antivirus: $($av.displayName)" -ForegroundColor Green
    }
} catch { Write-Host "  [WARN] Cannot check security status" -ForegroundColor Yellow }

Write-Host "`n✅ Diagnostics Complete - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green

# Export report
if ($ExportReport) {
    if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }
    $reportFile = Join-Path $OutputPath "diagnostic-$ComputerName-$timestamp.txt"
    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "📄 Report exported: $reportFile" -ForegroundColor Cyan
}
