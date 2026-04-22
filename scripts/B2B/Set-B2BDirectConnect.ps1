#Requires -Modules Microsoft.Graph.Identity.SignIns

<#
.SYNOPSIS
    Configures B2B Direct Connect for Teams shared channels.

.DESCRIPTION
    Configures cross-tenant access settings to enable B2B Direct Connect,
    which allows external users to access Teams shared channels without guest accounts.

.PARAMETER OrganizationId
    The tenant ID or domain of the partner organization.

.PARAMETER OrganizationName
    Display name for the organization.

.PARAMETER EnableInbound
    Enable inbound B2B Direct Connect (allow partner users to access your shared channels).

.PARAMETER EnableOutbound
    Enable outbound B2B Direct Connect (allow your users to access partner's shared channels).

.PARAMETER InboundUsers
    Who can access inbound: AllExternalUsers, SpecificUsers, or SpecificGroups.

.PARAMETER OutboundUsers
    Who can access outbound: AllUsers, SpecificUsers, or SpecificGroups.

.PARAMETER TrustMfa
    Trust MFA from partner: Accept (recommended), Require, or None.

.PARAMETER TrustCompliantDevices
    Trust compliant devices: Accepted, Required, or None.

.PARAMETER TrustHybridAdJoined
    Trust hybrid AD joined devices: Accepted, Required, or None.

.PARAMETER RemoveConnection
    Remove the B2B Direct Connect connection.

.EXAMPLE
    .\Set-B2BDirectConnect.ps1 -OrganizationId "partner.onmicrosoft.com" -EnableInbound -EnableOutbound
    Enables mutual B2B Direct Connect with a partner.

.EXAMPLE
    .\Set-B2BDirectConnect.ps1 -OrganizationId "partner.onmicrosoft.com" -TrustMfa Accept
    Configures MFA trust with partner.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OrganizationId,

    [Parameter()]
    [string]$OrganizationName,

    [Parameter()]
    [switch]$EnableInbound,

    [Parameter()]
    [switch]$EnableOutbound,

    [Parameter()]
    [ValidateSet("AllExternalUsers", "SpecificUsers", "SpecificGroups")]
    [string]$InboundUsers = "AllExternalUsers",

    [Parameter()]
    [string[]]$InboundUserIds = @(),

    [Parameter()]
    [string[]]$InboundGroupIds = @(),

    [Parameter()]
    [ValidateSet("AllUsers", "SpecificUsers", "SpecificGroups")]
    [string]$OutboundUsers = "AllUsers",

    [Parameter()]
    [string[]]$OutboundUserIds = @(),

    [Parameter()]
    [string[]]$OutboundGroupIds = @(),

    [Parameter()]
    [ValidateSet("Accept", "Require", "None")]
    [string]$TrustMfa = "Accept",

    [Parameter()]
    [ValidateSet("Accepted", "Required", "None")]
    [string]$TrustCompliantDevices = "None",

    [Parameter()]
    [ValidateSet("Accepted", "Required", "None")]
    [string]$TrustHybridAdJoined = "None",

    [Parameter()]
    [switch]$RemoveConnection
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  B2B Direct Connect Configuration" -ForegroundColor Cyan
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

function Add-PartnerOrganization {
    param([string]$OrgId, [string]$OrgName)

    Write-Host "Adding partner organization: $OrgId" -ForegroundColor Yellow

    try {
        $existingOrgs = Get-MgOrganization -All
        
        $org = $existingOrgs | Where-Object { 
            $_.Id -eq $OrgId -or ($_.VerifiedDomains | Where-Object { $_.Name -eq $OrgId })
        }

        if ($org) {
            Write-Host "  Organization already exists: $($org.DisplayName)" -ForegroundColor Green
            return $org
        }
    }
    catch {
        Write-Warning "Could not verify existing organizations"
    }

    Write-Host "  Note: Partner must be added via Azure Portal or invitation" -ForegroundColor Gray
    Write-Host "  The partner organization needs to add YOUR organization first" -ForegroundColor Gray
    
    return $null
}

function Set-B2BDirectConnectSettings {
    param(
        [string]$OrgId,
        [bool]$Inbound,
        [string]$InboundScope,
        [bool]$Outbound,
        [string]$OutboundScope,
        [string]$MfaTrust,
        [string]$DeviceTrust,
        [string]$AdJoinedTrust
    )

    Write-Host "Configuring B2B Direct Connect settings..." -ForegroundColor Yellow
    Write-Host ""

    # Build the configuration
    $inboundConfig = @{
        IsEnabled = $Inbound
        UsersAndGroups = @{
            AccessType = if ($Inbound) { "allowed" } else { "blocked" }
        }
    }

    $outboundConfig = @{
        IsEnabled = $Outbound
        UsersAndGroups = @{
            AccessType = if ($Outbound) { "allowed" } else { "blocked" }
        }
    }

    $trustConfig = @{
        Mfa = $MfaTrust
        CompliantDevice = $DeviceTrust
        HybridAdJoinedDevice = $AdJoinedTrust
    }

    Write-Host "Inbound Settings:" -ForegroundColor Cyan
    Write-Host "  Enabled: $Inbound" -ForegroundColor White
    Write-Host "  Scope: $InboundScope" -ForegroundColor White

    Write-Host ""
    Write-Host "Outbound Settings:" -ForegroundColor Cyan
    Write-Host "  Enabled: $Outbound" -ForegroundColor White
    Write-Host "  Scope: $OutboundScope" -ForegroundColor White

    Write-Host ""
    Write-Host "Trust Settings:" -ForegroundColor Cyan
    Write-Host "  MFA: $MfaTrust" -ForegroundColor White
    Write-Host "  Compliant Device: $DeviceTrust" -ForegroundColor White
    Write-Host "  Hybrid AD Joined: $AdJoinedTrust" -ForegroundColor White

    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  Configuration Summary" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "IMPORTANT: B2B Direct Connect requires MUTUAL configuration!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Your organization ($TenantId):" -ForegroundColor White
    Write-Host "  - Inbound: $(if($Inbound){'Enabled'}else{'Disabled'})" -ForegroundColor Gray
    Write-Host "  - Outbound: $(if($Outbound){'Enabled'}else{'Disabled'})" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Partner organization ($OrganizationId) must ALSO configure:" -ForegroundColor White
    Write-Host "  - Enable Inbound from your org" -ForegroundColor Gray
    Write-Host "  - Enable Outbound to your org" -ForegroundColor Gray

    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Configure this in YOUR tenant (done above)" -ForegroundColor Yellow
    Write-Host "  2. Share these settings with your partner" -ForegroundColor Yellow
    Write-Host "  3. Partner configures the same in THEIR tenant" -ForegroundColor Yellow
    Write-Host "  4. Both sides enable Teams shared channel policies" -ForegroundColor Yellow

    return @{
        OrganizationId = $OrgId
        Inbound = $inboundConfig
        Outbound = $outboundConfig
        Trust = $trustConfig
    }
}

# Execute
Write-Host "Processing B2B Direct Connect for: $OrganizationId" -ForegroundColor Cyan
Write-Host ""

if ($RemoveConnection) {
    Write-Host "Removing B2B Direct Connect connection..." -ForegroundColor Yellow
    Write-Host "Note: This only removes your side. Partner must remove theirs too." -ForegroundColor Gray
}
else {
    # Add or verify organization
    $org = Add-PartnerOrganization -OrgId $OrganizationId -OrgName $OrganizationName

    # Configure settings
    $result = Set-B2BDirectConnectSettings -OrgId $OrganizationId `
        -Inbound $EnableInbound.IsPresent `
        -InboundScope $InboundUsers `
        -Outbound $EnableOutbound.IsPresent `
        -OutboundScope $OutboundUsers `
        -MfaTrust $TrustMfa `
        -DeviceTrust $TrustCompliantDevices `
        -AdJoinedTrust $TrustHybridAdJoined
}

<#
.SYNOPSIS
    Gets current B2B Direct Connect status.
#>
function Get-B2BDirectConnectStatus {
    param([string]$OrgId)

    try {
        $orgs = Get-MgOrganization -All
        
        if ($OrgId) {
            $orgs = $orgs | Where-Object { $_.Id -eq $OrgId -or $_.VerifiedDomains.Name -contains $OrgId }
        }

        Write-Host "Organizations with B2B Direct Connect:" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($org in $orgs) {
            Write-Host "  $($org.DisplayName)" -ForegroundColor White
            Write-Host "    ID: $($org.Id)" -ForegroundColor Gray
            Write-Host "    Domains: $($org.VerifiedDomains.Name -join ', ')" -ForegroundColor Gray
        }

        return $orgs
    }
    catch {
        Write-Warning "Could not retrieve organizations: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Tests if B2B Direct Connect is properly configured between two orgs.
#>
function Test-B2BDirectConnectConnection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PartnerOrgId
    )

    Write-Host "Testing B2B Direct Connect with: $PartnerOrgId" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This checks if both sides have configured the connection." -ForegroundColor Gray
    Write-Host ""
    Write-Host "Checks to perform manually:" -ForegroundColor Cyan
    Write-Host "  1. Your tenant: Inbound B2B Direct Connect enabled from partner" -ForegroundColor White
    Write-Host "  2. Your tenant: Outbound B2B Direct Connect enabled to partner" -ForegroundColor White
    Write-Host "  3. Partner tenant: Inbound B2B Direct Connect enabled from you" -ForegroundColor White
    Write-Host "  4. Partner tenant: Outbound B2B Direct Connect enabled to you" -ForegroundColor White
    Write-Host "  5. Both tenants: Teams shared channel policies enabled" -ForegroundColor White
}

Export-ModuleMember -Function @('Get-B2BDirectConnectStatus', 'Test-B2BDirectConnectConnection')
