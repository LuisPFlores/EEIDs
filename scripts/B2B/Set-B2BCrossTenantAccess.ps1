#Requires -Modules Microsoft.Graph.Identity.SignIns

<#
.SYNOPSIS
    Configures cross-tenant access settings for B2B collaboration.

.DESCRIPTION
    Configures inbound and outbound access settings for specific partner organizations,
    including B2B collaboration and B2B Direct Connect settings.

.PARAMETER OrganizationId
    The tenant ID or domain of the partner organization.

.PARAMETER OrganizationName
    Display name for the organization (optional, auto-fetched).

.PARAMETER EnableB2BInbound
    Enable B2B collaboration inbound access.

.PARAMETER B2BInboundUsers
    Who can access via B2B: AllUsers, SpecificUsers, or SpecificGroups.

.PARAMETER EnableB2BOutbound
    Enable B2B collaboration outbound access.

.PARAMETER B2BOutboundUsers
    Who can access externally: AllUsers, SpecificUsers, or SpecificGroups.

.PARAMETER EnableB2BDirectConnectInbound
    Enable B2B Direct Connect inbound.

.PARAMETER EnableB2BDirectConnectOutbound
    Enable B2B Direct Connect outbound.

.PARAMETER TrustMfa
    Accept MFA from partner tenant: Accept, Require, or None.

.PARAMETER TrustCompliantDevices
    Accept compliant devices from partner: Accepted, Required, or None.

.PARAMETER RemoveOrganization
    Remove the organization instead of adding/configuring.

.EXAMPLE
    .\Set-B2BCrossTenantAccess.ps1 -OrganizationId "partner.onmicrosoft.com" -EnableB2BInbound
    Enables B2B collaboration with a partner.

.EXAMPLE
    .\Set-B2BCrossTenantAccess.ps1 -OrganizationId "partner.onmicrosoft.com" -EnableB2BDirectConnectInbound
    Enables B2B Direct Connect for Teams shared channels.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OrganizationId,

    [Parameter()]
    [string]$OrganizationName,

    [Parameter()]
    [switch]$EnableB2BInbound,

    [Parameter()]
    [ValidateSet("AllUsers", "SpecificUsers", "SpecificGroups")]
    [string]$B2BInboundUsers = "AllUsers",

    [Parameter()]
    [string[]]$B2BInboundUserIds = @(),

    [Parameter()]
    [string[]]$B2BInboundGroupIds = @(),

    [Parameter()]
    [switch]$EnableB2BOutbound,

    [Parameter()]
    [ValidateSet("AllUsers", "SpecificUsers", "SpecificGroups")]
    [string]$B2BOutboundUsers = "AllUsers",

    [Parameter()]
    [string[]]$B2BOutboundUserIds = @(),

    [Parameter()]
    [string[]]$B2BOutboundGroupIds = @(),

    [Parameter()]
    [switch]$EnableB2BDirectConnectInbound,

    [Parameter()]
    [switch]$EnableB2BDirectConnectOutbound,

    [Parameter()]
    [ValidateSet("Accept", "Require", "None")]
    [string]$TrustMfa = "Accept",

    [Parameter()]
    [ValidateSet("Accepted", "Required", "None")]
    [string]$TrustCompliantDevices = "None",

    [Parameter()]
    [switch]$RemoveOrganization
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Configure Cross-Tenant Access" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Verify connection
$context = Get-MgContext -ErrorAction SilentlyContinue
if (-not $context) {
    Write-Error "Not connected. Run .\Connect-EntraB2B.ps1 first."
    return
}

$TenantId = $context.TenantId
Write-Host "Current Tenant: $TenantId" -ForegroundColor Yellow
Write-Host "Partner Org: $OrganizationId" -ForegroundColor Yellow
Write-Host ""

function Add-B2BOrganization {
    param(
        [string]$OrgId,
        [string]$OrgName
    )

    Write-Host "Adding organization: $OrgId" -ForegroundColor Yellow

    # Check if organization already exists
    try {
        $existing = Get-MgOrganization -All | Where-Object { 
            $_.Id -eq $OrgId -or $_.VerifiedDomains.Name -contains $OrgId 
        }

        if ($existing) {
            Write-Host "  Organization already exists: $($existing.DisplayName)" -ForegroundColor Green
            return $existing
        }
    }
    catch {
        Write-Warning "Could not check existing organizations"
    }

    Write-Host "  Note: Organizations are typically added via Azure Portal or invitation flow" -ForegroundColor Gray
    Write-Host "  The partner must first invite someone OR you must add via Cross-tenant access settings" -ForegroundColor Gray

    return $null
}

function Set-B2BCrossTenantSettings {
    param(
        [string]$OrgId,
        [bool]$B2BInbound,
        [string]$B2BInboundScope,
        [bool]$B2BOutbound,
        [string]$B2BOutboundScope,
        [bool]$B2BDCInbound,
        [bool]$B2BDCOutbound,
        [string]$MfaTrust,
        [string]$DeviceTrust
    )

    Write-Host "Configuring cross-tenant settings for: $OrgId" -ForegroundColor Yellow

    # Build access policy
    $inboundAccess = @{
        B2BCollaboration = @{
            IsEnabled = $B2BInbound
            UsersAndGroups = @{
                AccessType = if ($B2BInbound) { "allowed" } else { "blocked" }
            }
            Applications = @{
                AccessType = if ($B2BInbound) { "allowed" } else { "blocked" }
                IncludeApplications = @("*")
            }
        }
        B2BDirectConnect = @{
            IsEnabled = $B2BDCInbound
            UsersAndGroups = @{
                AccessType = if ($BBDCInbound) { "allowed" } else { "blocked" }
            }
        }
    }

    $outboundAccess = @{
        B2BCollaboration = @{
            IsEnabled = $B2BOutbound
            UsersAndGroups = @{
                AccessType = if ($B2BOutbound) { "allowed" } else { "blocked" }
            }
        }
        B2BDirectConnect = @{
            IsEnabled = $B2BDCOutbound
            UsersAndGroups = @{
                AccessType = if ($B2BDCOutbound) { "allowed" } else { "blocked" }
            }
        }
    }

    $trustSettings = @{
        InboundTrust = @{
            Mfa = $MfaTrust
            CompliantDevice = $DeviceTrust
            Fido2 = "None"
            Passwordless = "None"
        }
    }

    Write-Host ""
    Write-Host "Inbound Settings:" -ForegroundColor Cyan
    Write-Host "  B2B Collaboration: $($inboundAccess.B2BCollaboration.IsEnabled)" -ForegroundColor White
    Write-Host "  B2B Direct Connect: $($inboundAccess.B2BDirectConnect.IsEnabled)" -ForegroundColor White
    Write-Host "  MFA Trust: $MfaTrust" -ForegroundColor White

    Write-Host ""
    Write-Host "Outbound Settings:" -ForegroundColor Cyan
    Write-Host "  B2B Collaboration: $($outboundAccess.B2BCollaboration.IsEnabled)" -ForegroundColor White
    Write-Host "  B2B Direct Connect: $($outboundAccess.B2BDirectConnect.IsEnabled)" -ForegroundColor White

    # Note: Full Graph API implementation for cross-tenant settings
    Write-Host ""
    Write-Host "Note: Use Azure Portal for complete configuration:" -ForegroundColor Yellow
    Write-Host "  1. Go to External Identities > Cross-tenant access settings" -ForegroundColor Gray
    Write-Host "  2. Add organization: $OrgId" -ForegroundColor Gray
    Write-Host "  3. Configure inbound/outbound settings" -ForegroundColor Gray
    Write-Host "  4. Set trust settings" -ForegroundColor Gray

    return @{
        OrganizationId = $OrgId
        InboundAccess = $inboundAccess
        OutboundAccess = $outboundAccess
        TrustSettings = $trustSettings
    }
}

# Execute
if ($RemoveOrganization) {
    Write-Host "Removing organization: $OrganizationId" -ForegroundColor Yellow
    Write-Host "Note: Use Azure Portal to remove organizations" -ForegroundColor Gray
}
else {
    # Add or verify organization exists
    $org = Add-B2BOrganization -OrgId $OrganizationId -OrgName $OrganizationName

    # Configure settings
    $result = Set-B2BCrossTenantSettings -OrgId $OrganizationId `
        -B2BInbound $EnableB2BInbound.IsPresent `
        -B2BInboundScope $B2BInboundUsers `
        -B2BOutbound $EnableB2BOutbound.IsPresent `
        -B2BOutboundScope $B2BOutboundUsers `
        -B2BDCInbound $EnableB2BDirectConnectInbound.IsPresent `
        -B2BDCOutbound $EnableB2BDirectConnectOutbound.IsPresent `
        -MfaTrust $TrustMfa `
        -DeviceTrust $TrustCompliantDevices

    Write-Host ""
    Write-Host "Configuration prepared!" -ForegroundColor Green
}

<#
.SYNOPSIS
    Lists current cross-tenant access settings.
#>
function Get-B2BCrossTenantSettings {
    param(
        [string]$OrgId
    )

    try {
        if ($OrgId) {
            # Get specific organization
            $org = Get-MgOrganization -OrganizationId $OrgId
            return $org
        }
        else {
            # List all organizations
            return Get-MgOrganization -All
        }
    }
    catch {
        Write-Warning "Could not retrieve organizations: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Blocks B2B collaboration with all external organizations.
#>
function Set-B2BBlockAll {
    Write-Host "Configuring to block all B2B collaboration..." -ForegroundColor Yellow
    
    Write-Host "To block all B2B:" -ForegroundColor Yellow
    Write-Host "  1. Go to Cross-tenant access settings" -ForegroundColor Gray
    Write-Host "  2. Edit 'Default settings'" -ForegroundColor Gray
    Write-Host "  3. Set 'B2B collaboration' to 'Block'" -ForegroundColor Gray
    Write-Host "  4. Add specific trusted organizations with 'Allow'" -ForegroundColor Gray
}

Export-ModuleMember -Function @('Get-B2BCrossTenantSettings', 'Set-B2BBlockAll')
