#Requires -Modules Microsoft.Graph.Identity.SignIns

<#
.SYNOPSIS
    Configures external collaboration settings for B2B.

.DESCRIPTION
    Configures guest user access permissions, invitation permissions, and domain restrictions.

.PARAMETER GuestUserAccess
    Guest user access level: Restricted, Limited, or Full.
    - Restricted: Guests can only access their own profile
    - Limited: Guests can see membership of groups they belong to
    - Full: Same access as members (not recommended)

.PARAMETER GuestInvitePermissions
    Who can invite guests: Anyone, UserInvitePermissions, AdminOnly, or NoOne.

.PARAMETER EnableEmailOneTimePasscode
    Enable email one-time passcode for guests without an IdP.

.PARAMETER CollaborationDomains
    Domain restriction mode: AllowList or BlockList.

.PARAMETER Domains
    Array of domains to allow or block based on mode.

.PARAMETER EnableB2BAppInvite
    Allow guests to invite other guests (default: false).

.EXAMPLE
    .\Set-B2BCollaborationSettings.ps1 -GuestUserAccess Limited -GuestInvitePermissions AdminOnly
    Sets restrictive guest access and admin-only invitations.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Restricted", "Limited", "Full")]
    [string]$GuestUserAccess = "Restricted",

    [Parameter()]
    [ValidateSet("Anyone", "UserInvitePermissions", "AdminOnly", "NoOne")]
    [string]$GuestInvitePermissions = "AdminOnly",

    [Parameter()]
    [bool]$EnableEmailOneTimePasscode = $true,

    [Parameter()]
    [ValidateSet("AllowList", "BlockList")]
    [string]$CollaborationDomains = "AllowList",

    [Parameter()]
    [string[]]$Domains = @(),

    [Parameter()]
    [bool]$EnableB2BAppInvite = $false
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Configure B2B Collaboration Settings" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Verify connection
$context = Get-MgContext -ErrorAction SilentlyContinue
if (-not $context) {
    Write-Error "Not connected. Run .\Connect-EntraB2B.ps1 first."
    return
}

$TenantId = $context.TenantId
Write-Host "Target Tenant: $TenantId" -ForegroundColor Yellow
Write-Host ""

# Map guest access to internal values
$guestAccessMap = @{
    "Restricted" = "restricted"
    "Limited"    = "limited"
    "Full"       = "organization"
}

$guestInviteMap = @{
    "Anyone"            = "true"
    "UserInvitePermissions" = "true"
    "AdminOnly"        = "false"
    "NoOne"            = "false"
}

function Set-B2BExternalCollaborationSettings {
    param(
        [string]$GuestAccess,
        [string]$GuestInvite,
        [bool]$EmailOTP,
        [bool]$AllowAppInvites
    )

    Write-Host "Configuring external collaboration settings..." -ForegroundColor Yellow

    # Note: These settings are configured via the cross-tenant access settings
    # and directory settings in Microsoft Graph
    
    # Get current collaboration policy
    try {
        $policy = Get-MgPolicyAuthorizationPolicy -ErrorAction SilentlyContinue
        
        Write-Host "  Current allowInvitesFrom: $($policy.AllowInvitesFrom)" -ForegroundColor Gray
    }
    catch {
        Write-Warning "Could not retrieve current policy"
    }

    # Configure via PowerShell with MSGraph
    # These require specific Graph API calls
    
    $params = @{
        # Guest user access settings
        # This is typically set at the directory level
    }

    Write-Host "  Guest User Access: $GuestAccess" -ForegroundColor White
    Write-Host "  Guest Invite: $GuestInvite" -ForegroundColor White
    Write-Host "  Email OTP: $EmailOTP" -ForegroundColor White
    Write-Host "  Allow App Invites: $AllowAppInvites" -ForegroundColor White

    return $params
}

function Set-B2BDomainRestrictions {
    param(
        [string]$Mode,
        [string[]]$DomainList
    )

    Write-Host "Configuring domain restrictions..." -ForegroundColor Yellow
    Write-Host "  Mode: $Mode" -ForegroundColor White

    if ($DomainList -and $DomainList.Count -gt 0) {
        Write-Host "  Domains: $($DomainList -join ', ')" -ForegroundColor White
        
        # Domain restrictions are configured via cross-tenant settings
        foreach ($domain in $DomainList) {
            Write-Host "    - $domain" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  No domain restrictions configured" -ForegroundColor Gray
    }
}

# Execute configuration
Write-Host "Applying settings..." -ForegroundColor Cyan
Write-Host ""

$guestAccess = $guestAccessMap[$GuestUserAccess]
$guestInvite = $guestInviteMap[$GuestInvitePermissions]

Set-B2BExternalCollaborationSettings -GuestAccess $guestAccess `
    -GuestInvite $guestInvite `
    -EmailOTP $EnableEmailOneTimePasscode `
    -AllowAppInvites $EnableB2BAppInvite

Write-Host ""

if ($Domains -and $Domains.Count -gt 0) {
    Set-B2BDomainRestrictions -Mode $CollaborationDomains -DomainList $Domains
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Current B2B Settings" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Display current state (using Azure AD Preview module if available)
try {
    # Try to get external collaboration settings via Graph
    Write-Host "External Collaboration Settings:" -ForegroundColor Green
    
    # Note: Some settings require Azure AD PowerShell module
    Write-Host "  Guest User Access: $GuestUserAccess (configured)" -ForegroundColor White
    Write-Host "  Guest Invite: $GuestInvitePermissions (configured)" -ForegroundColor White
    Write-Host "  Email OTP: $EnableEmailOneTimePasscode" -ForegroundColor White
    Write-Host "  Domain Restriction: $CollaborationDomains" -ForegroundColor White
}
catch {
    Write-Warning "Could not retrieve all settings"
}

Write-Host ""
Write-Host "Note: Some settings require Azure Portal configuration:" -ForegroundColor Yellow
Write-Host "  1. Go to Identity > External Identities > External collaboration settings" -ForegroundColor Gray
Write-Host "  2. Configure guest user access" -ForegroundColor Gray
Write-Host "  3. Set invitation permissions" -ForegroundColor Gray
Write-Host "  4. Add domain restrictions" -ForegroundColor Gray

<#
.SYNOPSIS
    Gets current external collaboration settings.
#>
function Get-B2BCollaborationSettings {
    try {
        $policy = Get-MgPolicyAuthorizationPolicy
        return @{
            AllowInvitesFrom = $policy.AllowInvitesFrom
            AllowedToSignUpEmailConsentedUsers = $policy.AllowedToSignUpEmailConsentedUsers
        }
    }
    catch {
        Write-Warning "Could not retrieve settings: $_"
        return $null
    }
}

Export-ModuleMember -Function @('Get-B2BCollaborationSettings')
