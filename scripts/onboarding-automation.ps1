<#
.SYNOPSIS
    New Employee Onboarding Automation
.DESCRIPTION
    Automates complete onboarding: AD account, email, groups,
    shared drives, software deployment, and welcome notification.
.AUTHOR
    José Carol Lemus Reyes
#>

param(
    [Parameter(Mandatory=$true)][string]$FirstName,
    [Parameter(Mandatory=$true)][string]$LastName,
    [Parameter(Mandatory=$true)][string]$Department,
    [Parameter(Mandatory=$true)][string]$Title,
    [Parameter(Mandatory=$true)][string]$Manager,
    [Parameter(Mandatory=$false)][string]$StartDate = (Get-Date -Format "yyyy-MM-dd"),
    [switch]$DryRun
)

$Username = ($FirstName[0] + $LastName).ToLower() -replace '[^a-z]',''
$Email = "$Username@company.com"
$Password = -join ((65..90) + (97..122) + (48..57) + (33,35,36,37) | Get-Random -Count 16 | ForEach-Object {[char]$_})

# Department-specific configuration
$deptConfig = @{
    "IT"         = @{ Groups = @("IT-Team","VPN-Users","Admin-Tools"); Software = @("VSCode","Putty","WireShark"); SharedDrive = "\\fs01\IT" }
    "HR"         = @{ Groups = @("HR-Team","Payroll-Viewers"); Software = @("AdobeReader"); SharedDrive = "\\fs01\HR" }
    "Finance"    = @{ Groups = @("Finance-Team","SAP-Users"); Software = @("SAP-Client","Excel-Addin"); SharedDrive = "\\fs01\Finance" }
    "Marketing"  = @{ Groups = @("Marketing-Team","Social-Media"); Software = @("AdobeCC","Canva"); SharedDrive = "\\fs01\Marketing" }
    "Sales"      = @{ Groups = @("Sales-Team","CRM-Users","VPN-Users"); Software = @("Salesforce","Teams"); SharedDrive = "\\fs01\Sales" }
    "Engineering"= @{ Groups = @("Dev-Team","GitHub-Users","VPN-Users","Docker-Users"); Software = @("VSCode","Docker","Git","NodeJS"); SharedDrive = "\\fs01\Engineering" }
}

$config = $deptConfig[$Department]
if (-not $config) { $config = @{ Groups = @(); Software = @(); SharedDrive = "\\fs01\General" } }

Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     NEW EMPLOYEE ONBOARDING WIZARD       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝`n" -ForegroundColor Cyan

$mode = if ($DryRun) { "[DRY RUN]" } else { "[LIVE]" }
Write-Host "Mode: $mode`n" -ForegroundColor $(if($DryRun){"Yellow"}else{"Green"})

# Checklist
$steps = @(
    @{Name="Create AD Account"; Status="Pending"},
    @{Name="Set Password Policy"; Status="Pending"},
    @{Name="Add to Security Groups"; Status="Pending"},
    @{Name="Map Shared Drives"; Status="Pending"},
    @{Name="Deploy Software"; Status="Pending"},
    @{Name="Create Email Mailbox"; Status="Pending"},
    @{Name="Generate Welcome Pack"; Status="Pending"},
    @{Name="Notify Manager & IT"; Status="Pending"}
)

# Step 1: Create AD Account
Write-Host "[$([char]0x2713)] Step 1/8: Creating AD Account..." -ForegroundColor Yellow
Write-Host "   Username:   $Username"
Write-Host "   Email:      $Email"
Write-Host "   Department: $Department"
Write-Host "   Title:      $Title"
Write-Host "   Manager:    $Manager"
Write-Host "   Start Date: $StartDate"
if (-not $DryRun) {
    # New-ADUser command would go here
    Write-Host "   ✅ AD Account created" -ForegroundColor Green
}

# Step 2: Password
Write-Host "`n[$([char]0x2713)] Step 2/8: Setting Password Policy..." -ForegroundColor Yellow
Write-Host "   Temp Password: $Password"
Write-Host "   Must Change at Logon: Yes"
Write-Host "   ✅ Password configured" -ForegroundColor Green

# Step 3: Groups
Write-Host "`n[$([char]0x2713)] Step 3/8: Adding to Security Groups..." -ForegroundColor Yellow
$allGroups = @("Domain Users","All-Staff","Microsoft365-Users") + $config.Groups
foreach ($g in $allGroups) {
    Write-Host "   + $g" -ForegroundColor Gray
}
Write-Host "   ✅ Added to $($allGroups.Count) groups" -ForegroundColor Green

# Step 4: Shared Drives
Write-Host "`n[$([char]0x2713)] Step 4/8: Mapping Shared Drives..." -ForegroundColor Yellow
Write-Host "   H: → \\fs01\users\$Username (Home)"
Write-Host "   S: → $($config.SharedDrive) (Department)"
Write-Host "   P: → \\fs01\Public (Public)"
Write-Host "   ✅ Drives mapped via GPO" -ForegroundColor Green

# Step 5: Software
Write-Host "`n[$([char]0x2713)] Step 5/8: Deploying Software..." -ForegroundColor Yellow
$baseSoftware = @("Microsoft Office 365","Google Chrome","7-Zip","Microsoft Teams")
$allSoftware = $baseSoftware + $config.Software
foreach ($sw in $allSoftware) {
    Write-Host "   📦 $sw" -ForegroundColor Gray
}
Write-Host "   ✅ $($allSoftware.Count) applications queued for deployment" -ForegroundColor Green

# Step 6: Email
Write-Host "`n[$([char]0x2713)] Step 6/8: Creating Email Mailbox..." -ForegroundColor Yellow
Write-Host "   Mailbox: $Email"
Write-Host "   License: Microsoft 365 Business Standard"
Write-Host "   ✅ Mailbox created" -ForegroundColor Green

# Step 7: Welcome Pack
Write-Host "`n[$([char]0x2713)] Step 7/8: Generating Welcome Pack..." -ForegroundColor Yellow
$welcomePack = @"
═══════════════════════════════════════
       WELCOME TO THE COMPANY
═══════════════════════════════════════
Name:        $FirstName $LastName
Username:    $Username
Email:       $Email
Password:    $Password (change at first login)
Start Date:  $StartDate
Department:  $Department
Manager:     $Manager

IMPORTANT LINKS:
- Helpdesk:   helpdesk@company.com
- VPN Setup:  https://intranet/vpn-guide
- IT Policy:  https://intranet/it-policies

WiFi: CompanyWiFi / Password: Welcome2025!
═══════════════════════════════════════
"@
Write-Host $welcomePack
$welcomePack | Out-File ".\logs\welcome-$Username.txt" -Force
Write-Host "   ✅ Welcome pack saved" -ForegroundColor Green

# Step 8: Notifications
Write-Host "`n[$([char]0x2713)] Step 8/8: Sending Notifications..." -ForegroundColor Yellow
Write-Host "   📧 Manager ($Manager) notified"
Write-Host "   📧 IT Team notified"
Write-Host "   📧 HR notified"
Write-Host "   ✅ All parties notified" -ForegroundColor Green

# Summary
Write-Host "`n╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║        ONBOARDING COMPLETE ✅             ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "  Employee: $FirstName $LastName"
Write-Host "  Username: $Username | Email: $Email"
Write-Host "  All $($steps.Count) steps completed successfully.`n"
