#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.ConditionalAccess

<#
.SYNOPSIS
    Deploys a complete B2B Collaboration PoC environment.

.DESCRIPTION
    Orchestrates the complete B2B Collaboration PoC deployment including:
    - External collaboration settings
    - Cross-tenant access settings
    - Guest invitation
    - Conditional Access policies

.PARAMETER PartnerDomain
    Partner's domain (e.g., partner.onmicrosoft.com).

.PARAMETER PartnerTenantId
    Partner's tenant ID (optional, if different from domain).

.PARAMETER GuestEmail
    Email address of guest user to invite.

.PARAMETER GuestDisplayName
    Display name for guest user.

.PARAMETER GuestGroups
    Groups to add guest to (comma-separated names or IDs).

.PARAMETER EnableB2BInbound
    Enable B2B collaboration from partner.

.PARAMETER EnableB2BDirectConnect
    Enable B2B Direct Connect (Teams shared channels).

.PARAMETER RequireMfaForGuests
    Require MFA for guest users.

.PARAMETER RequireCompliantDevice
    Require compliant device (Intune).

.PARAMETER RestrictGuestAccess
    Restrict guest access to "Restricted" (most secure).

.PARAMETER RestrictInvitations
    Restrict invitations to admins only.

.PARAMETER ConfigFile
    Path to JSON configuration file.

.PARAMETER DryRun
    Show what would be done without making changes.

.EXAMPLE
    .\Deploy-B2BFull.ps1 -PartnerDomain "partner.onmicrosoft.com" -GuestEmail "user@partner.com"
    Deploys B2B with guest invitation.

.EXAMPLE
    .\Deploy-B2BFull.ps1 -ConfigFile "b2b-config.json" -DryRun
    Shows deployment plan from config file.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$PartnerDomain,

    [Parameter()]
    [string]$PartnerTenantId,

    [Parameter()]
    [string]$GuestEmail,

    [Parameter()]
    [string]$GuestDisplayName,

    [Parameter()]
    [string]$GuestGroups,

    [Parameter()]
    [switch]$EnableB2BInbound,

    [Parameter()]
    [switch]$EnableB2BDirectConnect,

    [Parameter()]
    [switch]$RequireMfaForGuests,

    [Parameter()]
    [switch]$RequireCompliantDevice,

    [Parameter()]
    [switch]$RestrictGuestAccess,

    [Parameter()]
    [switch]$RestrictInvitations,

    [Parameter()]
    [string]$ConfigFile,

    [Parameter()]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  B2B Collaboration PoC Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$deploymentConfig = @{
    PartnerDomain = $PartnerDomain
    PartnerTenantId = $PartnerTenantId
    GuestEmail = $GuestEmail
    GuestDisplayName = $GuestDisplayName
    GuestGroups = if ($GuestGroups) { $GuestGroups -split "," } else { @() }
    EnableB2BInbound = $EnableB2BInbound.IsPresent
    EnableB2BDirectConnect = $EnableB2BDirectConnect.IsPresent
    RequireMfaForGuests = $RequireMfaForGuests.IsPresent
    RequireCompliantDevice = $RequireCompliantDevice.IsPresent
    RestrictGuestAccess = $RestrictGuestAccess.IsPresent
    RestrictInvitations = $RestrictInvitations.IsPresent
}

# Load config from file if provided
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    Write-Host "Loading configuration from: $ConfigFile" -ForegroundColor Yellow
    $fileConfig = Get-Content $ConfigFile | ConvertFrom-Json
    foreach ($prop in $fileConfig.PSObject.Properties) {
        $deploymentConfig[$prop.Name] = $prop.Value
    }
}

# Display configuration
Write-Host "Deployment Configuration:" -ForegroundColor Cyan
Write-Host "  Partner Domain: $($deploymentConfig.PartnerDomain)" -ForegroundColor White
Write-Host "  Guest Email: $($deploymentConfig.GuestEmail)" -ForegroundColor White
Write-Host "  Enable B2B Inbound: $($deploymentConfig.EnableB2BInbound)" -ForegroundColor White
Write-Host "  Enable B2B Direct Connect: $($deploymentConfig.EnableB2BDirectConnect)" -ForegroundColor White
Write-Host "  Require MFA: $($deploymentConfig.RequireMfaForGuests)" -ForegroundColor White
Write-Host "  Require Compliant Device: $($deploymentConfig.RequireCompliantDevice)" -ForegroundColor White
Write-Host "  Restrict Guest Access: $($deploymentConfig.RestrictGuestAccess)" -ForegroundColor White
Write-Host "  Restrict Invitations: $($deploymentConfig.RestrictInvitations)" -ForegroundColor White
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

# Confirm before proceeding
if (-not $DryRun) {
    $confirmation = Read-Host "Proceed with deployment? (y/n)"
    if ($confirmation -ne 'y') {
        Write-Host "Deployment cancelled." -ForegroundColor Red
        return
    }
}

Write-Host "Starting deployment..." -ForegroundColor Green
Write-Host ""

# Step 1: Verify connection
Write-Host "[1/5] Verifying connection..." -ForegroundColor Yellow
$context = Get-MgContext -ErrorAction SilentlyContinue
if (-not $context) {
    Write-Host "Please connect first:" -ForegroundColor Red
    Write-Host "  .\Connect-EntraB2B.ps1" -ForegroundColor Gray
    return
}

$TenantId = $context.TenantId
$tenant = Get-MgOrganization -OrganizationId $TenantId
Write-Host "  Connected to: $($tenant.DisplayName)" -ForegroundColor Green
Write-Host ""

# Step 2: Configure Collaboration Settings
Write-Host "[2/5] Configuring External Collaboration Settings..." -ForegroundColor Yellow

$guestAccess = if ($deploymentConfig.RestrictGuestAccess) { "Restricted" } else { "Limited" }
$invitePerms = if ($deploymentConfig.RestrictInvitations) { "AdminOnly" } else { "UserInvitePermissions" }

Write-Host "  Guest User Access: $guestAccess" -ForegroundColor White
Write-Host "  Invitation Permission: $invitePerms" -ForegroundColor White

if (-not $DryRun) {
    . "$PSScriptRoot\Set-B2BCollaborationSettings.ps1"
    
    Set-B2BExternalCollaborationSettings -GuestAccess $guestAccess -GuestInvite $invitePerms
}
Write-Host ""

# Step 3: Configure Cross-Tenant Access
if ($deploymentConfig.PartnerDomain -or $deploymentConfig.PartnerTenantId) {
    Write-Host "[3/5] Configuring Cross-Tenant Access..." -ForegroundColor Yellow
    
    $partnerId = if ($deploymentConfig.PartnerTenantId) { $deploymentConfig.PartnerTenantId } else { $deploymentConfig.PartnerDomain }
    
    Write-Host "  Partner: $partnerId" -ForegroundColor White
    Write-Host "  B2B Inbound: $($deploymentConfig.EnableB2BInbound)" -ForegroundColor White
    Write-Host "  B2B Direct Connect: $($deploymentConfig.EnableB2BDirectConnect)" -ForegroundColor White
    
    if (-not $DryRun) {
        . "$PSScriptRoot\Set-B2BCrossTenantAccess.ps1"
        
        Set-B2BCrossTenantSettings -OrgId $partnerId `
            -B2BInbound $deploymentConfig.EnableB2BInbound `
            -B2BOutbound $false `
            -B2BDCInbound $deploymentConfig.EnableB2BDirectConnect `
            -B2BDCOutbound $deploymentConfig.EnableB2BDirectConnect `
            -MfaTrust "Accept"
    }
}
else {
    Write-Host "[3/5] Skipping Cross-Tenant Access (no partner specified)..." -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Invite Guest User
if ($deploymentConfig.GuestEmail) {
    Write-Host "[4/5] Inviting Guest User..." -ForegroundColor Yellow
    
    Write-Host "  Email: $($deploymentConfig.GuestEmail)" -ForegroundColor White
    Write-Host "  Display Name: $($deploymentConfig.GuestDisplayName)" -ForegroundColor White
    
    if ($deploymentConfig.GuestGroups -and $deploymentConfig.GuestGroups.Count -gt 0) {
        Write-Host "  Groups: $($deploymentConfig.GuestGroups -join ', ')" -ForegroundColor White
    }
    
    if (-not $DryRun) {
        . "$PSScriptRoot\Invite-B2BGuest.ps1"
        
        $groupIds = @()
        foreach ($groupName in $deploymentConfig.GuestGroups) {
            try {
                $group = Get-MgGroup -All | Where-Object { $_.DisplayName -eq $groupName.Trim() } | Select-Object -First 1
                if ($group) {
                    $groupIds += $group.Id
                }
            }
            catch { }
        }
        
        Invite-B2BGuestUser -GuestEmail $deploymentConfig.GuestEmail `
            -GuestDisplayName $deploymentConfig.GuestDisplayName `
            -GroupIds $groupIds
    }
}
else {
    Write-Host "[4/5] Skipping Guest Invitation (no email specified)..." -ForegroundColor Yellow
}
Write-Host ""

# Step 5: Configure Conditional Access
if ($deploymentConfig.RequireMfaForGuests -or $deploymentConfig.RequireCompliantDevice) {
    Write-Host "[5/5] Configuring Conditional Access..." -ForegroundColor Yellow
    
    $policyName = "B2B Guest Access Policy"
    
    Write-Host "  Policy Name: $policyName" -ForegroundColor White
    Write-Host "  Require MFA: $($deploymentConfig.RequireMfaForGuests)" -ForegroundColor White
    Write-Host "  Require Compliant Device: $($deploymentConfig.RequireCompliantDevice)" -ForegroundColor White
    
    if (-not $DryRun) {
        . "$PSScriptRoot\Set-B2BConditionalAccess.ps1"
        
        New-B2BConditionalAccessPolicy -Name $policyName `
            -Desc "Conditional Access policy for B2B guest users" `
            -Mfa $deploymentConfig.RequireMfaForGuests `
            -Compliant $deploymentConfig.RequireCompliantDevice `
            -Apps @("*") `
            -Enabled $true
    }
}
else {
    Write-Host "[5/5] Skipping Conditional Access (not configured)..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Summary
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Tenant: $($tenant.DisplayName)" -ForegroundColor White
Write-Host "  Partner: $($deploymentConfig.PartnerDomain)" -ForegroundColor White
Write-Host "  Guest Invited: $($deploymentConfig.GuestEmail)" -ForegroundColor White
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Guest will receive invitation email" -ForegroundColor Yellow
Write-Host "  2. Guest accepts invitation and authenticates at their IdP" -ForegroundColor Yellow
Write-Host "  3. If MFA required, guest completes MFA" -ForegroundColor Yellow
Write-Host "  4. Guest accesses assigned resources" -ForegroundColor Yellow
Write-Host "  5. Review sign-in logs for guest activity" -ForegroundColor Yellow
Write-Host ""

# Export configuration
$deploymentConfig | ConvertTo-Json -Depth 5

<#
.SYNOPSIS
    Generates a sample B2B configuration file.
#>
function New-B2BConfigTemplate {
    param(
        [string]$OutputPath = "b2b-config.json"
    )

    $template = @{
        PartnerDomain = "partner.onmicrosoft.com"
        PartnerTenantId = ""
        GuestEmail = "user@partner.com"
        GuestDisplayName = "Partner User"
        GuestGroups = @("Guest Users", "Project Team")
        EnableB2BInbound = $true
        EnableB2BDirectConnect = $false
        RequireMfaForGuests = $true
        RequireCompliantDevice = $false
        RestrictGuestAccess = $true
        RestrictInvitations = $true
    }

    $template | ConvertTo-Json -Depth 5 | Out-File $OutputPath -Encoding utf8
    Write-Host "Configuration template created: $OutputPath" -ForegroundColor Green
}

Export-ModuleMember -Function @('New-B2BConfigTemplate')
