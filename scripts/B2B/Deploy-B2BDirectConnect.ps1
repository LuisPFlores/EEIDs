#Requires -Modules Microsoft.Graph.Identity.SignIns, MicrosoftTeams

<#
.SYNOPSIS
    Deploys complete B2B Direct Connect environment.

.DESCRIPTION
    Orchestrates the full B2B Direct Connect deployment including:
    - Cross-tenant access configuration
    - Trust settings (MFA, device compliance)
    - Teams shared channel policies

    NOTE: Both organizations must run this script (each in their own tenant).

.PARAMETER PartnerDomain
    Partner's domain (e.g., partner.onmicrosoft.com).

.PARAMETER PartnerTenantId
    Partner's tenant ID (optional).

.PARAMETER MutualConnection
    Configure both inbound and outbound (mutual).

.PARAMETER TrustMfa
    Trust partner's MFA claims: Accept (recommended), Require, None.

.PARAMETER TrustCompliantDevices
    Trust partner's compliant devices: Accepted, Required, None.

.PARAMETER ConfigureTeams
    Also configure Teams shared channel policies.

.PARAMETER TeamsPolicyName
    Name for Teams channels policy.

.PARAMETER DryRun
    Show what would be done without making changes.

.EXAMPLE
    .\Deploy-B2BDirectConnect.ps1 -PartnerDomain "partner.onmicrosoft.com" -MutualConnection
    Deploys mutual B2B Direct Connect.

.EXAMPLE
    .\Deploy-B2BDirectConnect.ps1 -PartnerDomain "partner.onmicrosoft.com" -TrustMfa Accept -ConfigureTeams
    Full deployment with MFA trust and Teams.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PartnerDomain,

    [Parameter()]
    [string]$PartnerTenantId,

    [Parameter()]
    [switch]$MutualConnection,

    [Parameter()]
    [ValidateSet("Accept", "Require", "None")]
    [string]$TrustMfa = "Accept",

    [Parameter()]
    [ValidateSet("Accepted", "Required", "None")]
    [string]$TrustCompliantDevices = "None",

    [Parameter()]
    [switch]$ConfigureTeams,

    [Parameter()]
    [string]$TeamsPolicyName = "B2B-DirectConnect-Policy",

    [Parameter()]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  B2B Direct Connect Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$deploymentConfig = @{
    PartnerDomain = $PartnerDomain
    PartnerTenantId = $PartnerTenantId
    MutualConnection = $MutualConnection.IsPresent
    TrustMfa = $TrustMfa
    TrustCompliantDevices = $TrustCompliantDevices
    ConfigureTeams = $ConfigureTeams.IsPresent
    TeamsPolicyName = $TeamsPolicyName
}

# Display configuration
Write-Host "Deployment Configuration:" -ForegroundColor Cyan
Write-Host "  Partner Domain: $($deploymentConfig.PartnerDomain)" -ForegroundColor White
Write-Host "  Partner Tenant ID: $($deploymentConfig.PartnerTenantId)" -ForegroundColor White
Write-Host "  Mutual Connection: $($deploymentConfig.MutualConnection)" -ForegroundColor White
Write-Host "  Trust MFA: $($deploymentConfig.TrustMfa)" -ForegroundColor White
Write-Host "  Trust Compliant Devices: $($deploymentConfig.TrustCompliantDevices)" -ForegroundColor White
Write-Host "  Configure Teams: $($deploymentConfig.ConfigureTeams)" -ForegroundColor White
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

# Step 1: Verify Entra connection
Write-Host "[1/3] Verifying Entra connection..." -ForegroundColor Yellow

$context = Get-MgContext -ErrorAction SilentlyContinue
if (-not $context) {
    Write-Host "Please connect to Entra first:" -ForegroundColor Red
    Write-Host "  .\Connect-EntraB2B.ps1" -ForegroundColor Gray
    return
}

$TenantId = $context.TenantId
$tenant = Get-MgOrganization -OrganizationId $TenantId
Write-Host "  Connected to: $($tenant.DisplayName)" -ForegroundColor Green
Write-Host ""

# Step 2: Configure Cross-Tenant Access (B2B Direct Connect)
Write-Host "[2/3] Configuring B2B Direct Connect..." -ForegroundColor Yellow

$partnerId = if ($deploymentConfig.PartnerTenantId) { $deploymentConfig.PartnerTenantId } else { $deploymentConfig.PartnerDomain }

Write-Host "  Partner: $partnerId" -ForegroundColor White
Write-Host "  Inbound: Enabled" -ForegroundColor White
Write-Host "  Outbound: $($deploymentConfig.MutualConnection)" -ForegroundColor White
Write-Host "  MFA Trust: $($deploymentConfig.TrustMfa)" -ForegroundColor White

if (-not $DryRun) {
    . "$PSScriptRoot\Set-B2BDirectConnect.ps1"

    Set-B2BDirectConnectSettings -OrgId $partnerId `
        -Inbound $true `
        -InboundScope "AllExternalUsers" `
        -Outbound $deploymentConfig.MutualConnection `
        -OutboundScope "AllUsers" `
        -MfaTrust $deploymentConfig.TrustMfa `
        -DeviceTrust $deploymentConfig.TrustCompliantDevices
}
Write-Host ""

# Step 3: Configure Teams (optional)
if ($deploymentConfig.ConfigureTeams) {
    Write-Host "[3/3] Configuring Teams Shared Channel Policies..." -ForegroundColor Yellow

    if (-not $DryRun) {
        . "$PSScriptRoot\Set-TeamsSharedChannelPolicy.ps1"

        Set-TeamsSharedChannelPolicy -Name $deploymentConfig.TeamsPolicyName `
            -AllowCreate $true `
            -AllowExternalCreate $true `
            -AllowExternalJoin $true

        # Also configure external access
        Set-ExternalAccessPolicy -EnableFederated $true `
            -EnableGuest $true
    }
}
else {
    Write-Host "[3/3] Skipping Teams configuration..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Summary
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Your Tenant: $($tenant.DisplayName)" -ForegroundColor White
Write-Host "  Partner: $($deploymentConfig.PartnerDomain)" -ForegroundColor White
Write-Host ""

Write-Host "YOUR SIDE IS CONFIGURED!" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  REQUIRED: Partner Must Also Configure!" -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Tell your partner to run this script with:" -ForegroundColor Yellow
Write-Host "  PartnerDomain: YOUR_DOMAIN ($($tenant.VerifiedDomains[0].Name))" -ForegroundColor White
Write-Host "  MutualConnection: `$$true" -ForegroundColor White
Write-Host "  TrustMfa: Accept" -ForegroundColor White
Write-Host ""

Write-Host "Example command for partner:" -ForegroundColor Yellow
$yourDomain = $tenant.VerifiedDomains[0].Name
Write-Host "  .\Deploy-B2BDirectConnect.ps1 -PartnerDomain `"$yourDomain`" -MutualConnection -TrustMfa Accept" -ForegroundColor White
Write-Host ""

Write-Host "After BOTH sides configure, users can:" -ForegroundColor Cyan
Write-Host "  1. Create shared channels in Teams" -ForegroundColor White
Write-Host "  2. Add external users from partner org" -ForegroundColor White
Write-Host "  3. Collaborate without guest accounts" -ForegroundColor White

Write-Host ""
Write-Host "Verification:" -ForegroundColor Cyan
Write-Host "  1. Both tenants configure cross-tenant access" -ForegroundColor Gray
Write-Host "  2. Both tenants configure Teams policies" -ForegroundColor Gray
Write-Host "  3. Wait up to 24 hours for policy propagation" -ForegroundColor Gray
Write-Host "  4. Create shared channel and add external user" -ForegroundColor Gray
Write-Host "  5. Verify external user sees channel in their Teams" -ForegroundColor Gray

<#
.SYNOPSIS
    Generates configuration instructions for partner.
#>
function Get-PartnerInstructions {
    param(
        [string]$YourDomain,
        [string]$YourTenantId
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Partner Configuration Instructions" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Please share these instructions with your partner organization:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Connect to Microsoft Graph:" -ForegroundColor White
    Write-Host "   .\Connect-EntraB2B.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Run deployment script:" -ForegroundColor White
    Write-Host "   .\Deploy-B2BDirectConnect.ps1 \" -ForegroundColor Gray
    Write-Host "       -PartnerDomain `"$YourDomain`" \" -ForegroundColor Gray
    Write-Host "       -MutualConnection \" -ForegroundColor Gray
    Write-Host "       -TrustMfa Accept" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Configure Teams policies:" -ForegroundColor White
    Write-Host "   .\Set-TeamsSharedChannelPolicy.ps1 -ConfigureTeams" -ForegroundColor Gray
    Write-Host ""
}

Export-ModuleMember -Function @('Get-PartnerInstructions')
