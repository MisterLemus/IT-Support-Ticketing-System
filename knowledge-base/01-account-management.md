# KB-001: Account Management & Password Issues
## Password Reset
1. Verify identity (employee ID + manager name)
2. Reset via AD: `Set-ADAccountPassword -Identity username -Reset`
3. Set "must change at next logon"
4. Provide temp password via secure channel

## Account Lockout
**Cause:** 5+ failed attempts within 30 min
1. Check: `Get-ADUser username -Properties LockedOut,BadLogonCount`
2. Common causes: cached credentials, mobile email, mapped drives
3. Unlock: `Unlock-ADAccount -Identity username`
4. Recurring: Check Event ID 4740 on DC

## Escalation
Escalate to L2 if: compromised, privileged account, repeated lockouts
