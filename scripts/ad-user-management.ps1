<#
.SYNOPSIS
    Active Directory User Management Automation Script
.DESCRIPTION
    Automates common AD tasks: password resets, account unlocks, 
    user creation, group management, and account auditing.
.AUTHOR
    José Carol Lemus Reyes - IT Support & Cybersecurity
.VERSION
    2.1.0
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("ResetPassword","UnlockAccount","CreateUser","DisableUser","AddToGroup","RemoveFromGroup","AuditUser","BulkCreate")]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$GroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$CsvPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Import Active Directory module
Import-Module ActiveDirectory -ErrorAction SilentlyContinue
if (-not (Get-Module ActiveDirectory)) {
    Write-Host "[ERROR] Active Directory module not found. Install RSAT tools." -ForegroundColor Red
    exit 1
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $(switch($Level) { "ERROR" {"Red"} "WARN" {"Yellow"} "SUCCESS" {"Green"} default {"White"} })
    $logEntry | Out-File -FilePath ".\logs\ad-management.log" -Append -Force
}

# Create logs directory
if (-not (Test-Path ".\logs")) { New-Item -ItemType Directory -Path ".\logs" | Out-Null }

# Generate secure temporary password
function New-TemporaryPassword {
    $length = 16
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = -join ((1..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Validate user exists
function Test-ADUserExists {
    param([string]$SamAccountName)
    try {
        $user = Get-ADUser -Identity $SamAccountName -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

switch ($Action) {
    "ResetPassword" {
        if (-not $Username) { Write-Log "Username required for password reset" "ERROR"; exit 1 }
        if (-not (Test-ADUserExists $Username)) { Write-Log "User $Username not found in AD" "ERROR"; exit 1 }
        
        $tempPassword = New-TemporaryPassword
        try {
            Set-ADAccountPassword -Identity $Username -Reset -NewPassword (ConvertTo-SecureString $tempPassword -AsPlainText -Force)
            Set-ADUser -Identity $Username -ChangePasswordAtLogon $true
            Unlock-ADAccount -Identity $Username
            
            Write-Log "Password reset for $Username. Temporary password: $tempPassword" "SUCCESS"
            Write-Log "User must change password at next logon" "INFO"
            
            # Get user details for ticket
            $user = Get-ADUser -Identity $Username -Properties DisplayName, EmailAddress, Department
            Write-Host "`n--- TICKET INFO ---" -ForegroundColor Cyan
            Write-Host "User: $($user.DisplayName)"
            Write-Host "Email: $($user.EmailAddress)"
            Write-Host "Department: $($user.Department)"
            Write-Host "Action: Password Reset + Account Unlocked"
            Write-Host "Temp Password: $tempPassword"
            Write-Host "Must Change: Yes"
            Write-Host "-------------------`n" -ForegroundColor Cyan
        } catch {
            Write-Log "Failed to reset password for $Username : $_" "ERROR"
        }
    }
    
    "UnlockAccount" {
        if (-not $Username) { Write-Log "Username required" "ERROR"; exit 1 }
        if (-not (Test-ADUserExists $Username)) { Write-Log "User $Username not found" "ERROR"; exit 1 }
        
        try {
            $lockoutInfo = Get-ADUser -Identity $Username -Properties LockedOut, LastBadPasswordAttempt, BadLogonCount, LockoutTime
            
            if ($lockoutInfo.LockedOut) {
                Unlock-ADAccount -Identity $Username
                Write-Log "Account unlocked: $Username" "SUCCESS"
                Write-Host "`n--- LOCKOUT DETAILS ---" -ForegroundColor Cyan
                Write-Host "Bad Password Attempts: $($lockoutInfo.BadLogonCount)"
                Write-Host "Last Bad Attempt: $($lockoutInfo.LastBadPasswordAttempt)"
                Write-Host "Lockout Time: $($lockoutInfo.LockoutTime)"
                Write-Host "Status: UNLOCKED"
                Write-Host "------------------------`n" -ForegroundColor Cyan
            } else {
                Write-Log "Account $Username is not locked out" "WARN"
            }
        } catch {
            Write-Log "Failed to unlock $Username : $_" "ERROR"
        }
    }
    
    "CreateUser" {
        if (-not $Username) { Write-Log "Username required" "ERROR"; exit 1 }
        if (Test-ADUserExists $Username) { Write-Log "User $Username already exists" "ERROR"; exit 1 }
        
        $firstName = Read-Host "First Name"
        $lastName = Read-Host "Last Name"
        $department = Read-Host "Department"
        $title = Read-Host "Job Title"
        $manager = Read-Host "Manager (SamAccountName)"
        $email = "$Username@company.com"
        $tempPassword = New-TemporaryPassword
        
        try {
            New-ADUser -SamAccountName $Username `
                -UserPrincipalName "$Username@company.com" `
                -Name "$firstName $lastName" `
                -GivenName $firstName `
                -Surname $lastName `
                -DisplayName "$firstName $lastName" `
                -EmailAddress $email `
                -Department $department `
                -Title $title `
                -Manager $manager `
                -AccountPassword (ConvertTo-SecureString $tempPassword -AsPlainText -Force) `
                -ChangePasswordAtLogon $true `
                -Enabled $true `
                -Path "OU=Users,OU=$department,DC=company,DC=local"
            
            # Add to default groups
            Add-ADGroupMember -Identity "Domain Users" -Members $Username
            Add-ADGroupMember -Identity "$department-Users" -Members $Username -ErrorAction SilentlyContinue
            
            Write-Log "User created: $firstName $lastName ($Username)" "SUCCESS"
            Write-Host "`n--- NEW USER DETAILS ---" -ForegroundColor Green
            Write-Host "Username: $Username"
            Write-Host "Email: $email"
            Write-Host "Temp Password: $tempPassword"
            Write-Host "Department: $department"
            Write-Host "Title: $title"
            Write-Host "Manager: $manager"
            Write-Host "--------------------------`n" -ForegroundColor Green
        } catch {
            Write-Log "Failed to create user $Username : $_" "ERROR"
        }
    }
    
    "DisableUser" {
        if (-not $Username) { Write-Log "Username required" "ERROR"; exit 1 }
        if (-not (Test-ADUserExists $Username)) { Write-Log "User $Username not found" "ERROR"; exit 1 }
        
        $user = Get-ADUser -Identity $Username -Properties DisplayName, MemberOf
        
        if (-not $Force) {
            $confirm = Read-Host "Disable account for $($user.DisplayName)? (Y/N)"
            if ($confirm -ne "Y") { Write-Log "Operation cancelled" "WARN"; exit 0 }
        }
        
        try {
            # Disable account
            Disable-ADAccount -Identity $Username
            
            # Move to Disabled OU
            $disabledOU = "OU=Disabled Users,DC=company,DC=local"
            Move-ADObject -Identity $user.DistinguishedName -TargetPath $disabledOU -ErrorAction SilentlyContinue
            
            # Remove from all groups except Domain Users
            $groups = Get-ADPrincipalGroupMembership -Identity $Username | Where-Object { $_.Name -ne "Domain Users" }
            foreach ($group in $groups) {
                Remove-ADGroupMember -Identity $group -Members $Username -Confirm:$false
                Write-Log "Removed from group: $($group.Name)" "INFO"
            }
            
            # Add description with disable date
            Set-ADUser -Identity $Username -Description "DISABLED $(Get-Date -Format 'yyyy-MM-dd') - Offboarding"
            
            Write-Log "Account disabled and cleaned: $Username" "SUCCESS"
        } catch {
            Write-Log "Failed to disable $Username : $_" "ERROR"
        }
    }
    
    "AuditUser" {
        if (-not $Username) { Write-Log "Username required" "ERROR"; exit 1 }
        if (-not (Test-ADUserExists $Username)) { Write-Log "User $Username not found" "ERROR"; exit 1 }
        
        $user = Get-ADUser -Identity $Username -Properties *
        
        Write-Host "`n========== USER AUDIT REPORT ==========" -ForegroundColor Cyan
        Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "IDENTITY" -ForegroundColor Yellow
        Write-Host "  Display Name:    $($user.DisplayName)"
        Write-Host "  SAM Account:     $($user.SamAccountName)"
        Write-Host "  UPN:             $($user.UserPrincipalName)"
        Write-Host "  Email:           $($user.EmailAddress)"
        Write-Host "  SID:             $($user.SID)"
        Write-Host ""
        Write-Host "ORGANIZATION" -ForegroundColor Yellow
        Write-Host "  Department:      $($user.Department)"
        Write-Host "  Title:           $($user.Title)"
        Write-Host "  Manager:         $($user.Manager)"
        Write-Host "  Office:          $($user.Office)"
        Write-Host ""
        Write-Host "ACCOUNT STATUS" -ForegroundColor Yellow
        Write-Host "  Enabled:         $($user.Enabled)"
        Write-Host "  Locked Out:      $($user.LockedOut)"
        Write-Host "  Created:         $($user.Created)"
        Write-Host "  Last Logon:      $($user.LastLogonDate)"
        Write-Host "  Password Set:    $($user.PasswordLastSet)"
        Write-Host "  Password Expired:$($user.PasswordExpired)"
        Write-Host "  Bad Pwd Count:   $($user.BadLogonCount)"
        Write-Host "  Logon Count:     $($user.logonCount)"
        Write-Host ""
        Write-Host "GROUP MEMBERSHIPS" -ForegroundColor Yellow
        $groups = Get-ADPrincipalGroupMembership -Identity $Username
        foreach ($group in $groups) {
            Write-Host "  - $($group.Name)"
        }
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        
        # Export to file
        $reportPath = ".\logs\audit-$Username-$(Get-Date -Format 'yyyyMMdd').txt"
        Write-Log "Audit report saved to $reportPath" "SUCCESS"
    }
    
    "BulkCreate" {
        if (-not $CsvPath) { Write-Log "CSV path required for bulk creation" "ERROR"; exit 1 }
        if (-not (Test-Path $CsvPath)) { Write-Log "CSV file not found: $CsvPath" "ERROR"; exit 1 }
        
        $users = Import-Csv $CsvPath
        $created = 0; $failed = 0
        
        foreach ($u in $users) {
            try {
                $tempPassword = New-TemporaryPassword
                New-ADUser -SamAccountName $u.Username `
                    -Name "$($u.FirstName) $($u.LastName)" `
                    -GivenName $u.FirstName `
                    -Surname $u.LastName `
                    -Department $u.Department `
                    -Title $u.Title `
                    -EmailAddress "$($u.Username)@company.com" `
                    -AccountPassword (ConvertTo-SecureString $tempPassword -AsPlainText -Force) `
                    -ChangePasswordAtLogon $true `
                    -Enabled $true
                
                Write-Log "Created: $($u.Username) - Password: $tempPassword" "SUCCESS"
                $created++
            } catch {
                Write-Log "Failed: $($u.Username) - $_" "ERROR"
                $failed++
            }
        }
        
        Write-Host "`n--- BULK CREATION SUMMARY ---" -ForegroundColor Cyan
        Write-Host "Total: $($users.Count) | Created: $created | Failed: $failed"
    }
}
