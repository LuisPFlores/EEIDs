#Requires -Module MicrosoftTeams

<#
.SYNOPSIS
    Configures Teams policies for B2B Direct Connect shared channels.

.DESCRIPTION
    Configures Teams policies to enable shared channels, external access,
    and cross-organization collaboration for B2B Direct Connect.

.PARAMETER EnableSharedChannels
    Enable shared channels in Teams.

.PARAMETER EnableExternalAccess
    Enable external access to Teams.

.PARAMETER AllowFederatedUsers
    Allow users to communicate with external users.

.PARAMETER EnableGuestAccess
    Enable guest access (as fallback for non-B2B DC users).

.PARAMETER AllowExternalSharedChannelCreate
    Allow users to create shared channels with external orgs.

.PARAMETER AllowExternalSharedChannelJoin
    Allow users to join shared channels from external orgs.

.PARAMETER PolicyName
    Name of the Teams channels policy to create/update.

.PARAMETER OrgAllowedDomains
    List of allowed external domains (for specific org access).

.PARAMETER ListPolicies
    List current Teams policies.

.EXAMPLE
    .\Set-TeamsSharedChannelPolicy.ps1 -EnableSharedChannels
    Configures Teams for shared channel access.

.EXAMPLE
    .\Set-TeamsSharedChannelPolicy.ps1 -AllowExternalSharedChannelCreate -AllowExternalSharedChannelJoin
    Allows external shared channel collaboration.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$EnableSharedChannels,

    [Parameter()]
    [switch]$EnableExternalAccess,

    [Parameter()]
    [switch]$AllowFederatedUsers,

    [Parameter()]
    [switch]$EnableGuestAccess,

    [Parameter()]
    [switch]$AllowExternalSharedChannelCreate,

    [Parameter()]
    [switch]$AllowExternalSharedChannelJoin,

    [Parameter()]
    [switch]$AllowUserToParticipateInExternalSharedChannel,

    [Parameter()]
    [string]$PolicyName = "B2B-DirectConnect-Policy",

    [Parameter()]
    [string[]]$OrgAllowedDomains = @(),

    [Parameter()]
    [switch]$ListPolicies
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Teams Shared Channel Configuration" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check for Teams module
$teamsModule = Get-Module -Name MicrosoftTeams -ListAvailable
if (-not $teamsModule) {
    Write-Host "MicrosoftTeams module not found." -ForegroundColor Yellow
    Write-Host "Installing MicrosoftTeams module..." -ForegroundColor Yellow
    Install-Module -Name MicrosoftTeams -Force -AllowClobber -Scope CurrentUser
}

try {
    # Check if already connected to Teams
    $teamsSession = Get-CsOnlineSession -ErrorAction SilentlyContinue
    
    if (-not $teamsSession) {
        Write-Host "Connecting to Microsoft Teams..." -ForegroundColor Yellow
        Connect-MicrosoftTeams
    }
}
catch {
    Write-Error "Failed to connect to Teams: $_"
    Write-Host "Please run: Connect-MicrosoftTeams" -ForegroundColor Yellow
    return
}

Write-Host "Connected to Teams" -ForegroundColor Green
Write-Host ""

function Get-TeamsPolicies {
    Write-Host "Current Teams Channel Policies:" -ForegroundColor Cyan
    Write-Host ""

    try {
        $policies = Get-CsTeamsChannelsPolicy -ErrorAction SilentlyContinue
        
        if ($policies) {
            $policies | Format-Table Identity, AllowSharedChannelCreate, AllowUserToParticipateInExternalSharedChannel -AutoSize
        }
        else {
            Write-Host "No custom policies found. Using Global policy." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "Could not retrieve policies: $_"
    }

    Write-Host ""
    Write-Host "External Access Policies:" -ForegroundColor Cyan
    
    try {
        $extPolicies = Get-CsExternalAccessPolicy -ErrorAction SilentlyContinue
        if ($extPolicies) {
            $extPolicies | Format-Table Identity, AllowFederatedExternalAccess, AllowGuestAccess -AutoSize
        }
    }
    catch {
        Write-Warning "Could not retrieve external access policies: $_"
    }
}

function Set-TeamsSharedChannelPolicy {
    param(
        [string]$Name,
        [bool]$AllowCreate,
        [bool]$AllowExternalCreate,
        [bool]$AllowExternalJoin
    )

    Write-Host "Configuring Teams Channels Policy: $Name" -ForegroundColor Yellow

    try {
        # Check if policy exists
        $existing = Get-CsTeamsChannelsPolicy -Identity $Name -ErrorAction SilentlyContinue

        if ($existing) {
            Write-Host "  Updating existing policy..." -ForegroundColor Gray
            $params = @{
                Identity = $Name
            }
            
            if ($AllowCreate) { $params.AllowSharedChannelCreate = $true }
            if ($AllowExternalCreate) { $params.AllowUserToParticipateInExternalSharedChannel = $true }
            if ($AllowExternalJoin) { $params.AllowUserToParticipateInExternalSharedChannel = $true }

            Set-CsTeamsChannelsPolicy @params -ErrorAction Stop
            Write-Host "  Policy updated successfully!" -ForegroundColor Green
        }
        else {
            Write-Host "  Creating new policy..." -ForegroundColor Gray
            $params = @{
                Identity = $Name
                AllowSharedChannelCreate = $AllowCreate
                AllowUserToParticipateInExternalSharedChannel = $AllowExternalCreate
            }

            New-CsTeamsChannelsPolicy @params -ErrorAction Stop
            Write-Host "  Policy created successfully!" -ForegroundColor Green
        }

        return $true
    }
    catch {
        Write-Error "  Failed to configure policy: $_"
        return $false
    }
}

function Set-ExternalAccessPolicy {
    param(
        [bool]$EnableFederated,
        [bool]$EnableGuest,
        [string[]]$AllowedDomains
    )

    Write-Host "Configuring External Access Policy..." -ForegroundColor Yellow

    try {
        $params = @{
            Identity = "Global"
            AllowFederatedExternalAccess = $EnableFederated
            AllowGuestAccess = $EnableGuest
        }

        if ($AllowedDomains -and $AllowedDomains.Count -gt 0) {
            $params.AllowedExternalDomains = $AllowedDomains
        }

        Set-CsExternalAccessPolicy @params -ErrorAction Stop
        Write-Host "  External access policy updated!" -ForegroundColor Green
    }
    catch {
        Write-Error "  Failed to configure external access: $_"
    }
}

# Execute based on parameters
if ($ListPolicies) {
    Get-TeamsPolicies
}
else {
    # Configure Teams Channels Policy
    if ($EnableSharedChannels -or $AllowExternalSharedChannelCreate -or $AllowExternalSharedChannelJoin) {
        Write-Host "Step 1: Configuring Teams Channels Policy..." -ForegroundColor Cyan
        
        $allowCreate = $true
        $allowExternalCreate = $AllowExternalSharedChannelCreate.IsPresent -or $AllowExternalSharedChannelJoin.IsPresent
        $allowExternalJoin = $AllowUserToParticipateInExternalSharedChannel.IsPresent -or $AllowExternalSharedChannelJoin.IsPresent

        Set-TeamsSharedChannelPolicy -Name $PolicyName `
            -AllowCreate $allowCreate `
            -AllowExternalCreate $allowExternalCreate `
            -AllowExternalJoin $allowExternalJoin

        Write-Host ""
    }

    # Configure External Access Policy
    if ($EnableExternalAccess -or $AllowFederatedUsers -or $EnableGuestAccess) {
        Write-Host "Step 2: Configuring External Access Policy..." -ForegroundColor Cyan
        
        Set-ExternalAccessPolicy -EnableFederated $AllowFederatedUsers.IsPresent `
            -EnableGuest $EnableGuestAccess.IsPresent `
            -AllowedDomains $OrgAllowedDomains

        Write-Host ""
    }

    # Summary
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  Configuration Complete" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Teams Channels Policy: $PolicyName" -ForegroundColor White
    Write-Host "  - Allow Shared Channel Create: $($EnableSharedChannels.IsPresent)" -ForegroundColor Gray
    Write-Host "  - Allow External Shared Channel: $($AllowExternalSharedChannelCreate.IsPresent)" -ForegroundColor Gray

    Write-Host ""
    Write-Host "External Access Policy (Global):" -ForegroundColor White
    Write-Host "  - Allow Federated Access: $($AllowFederatedUsers.IsPresent)" -ForegroundColor Gray
    Write-Host "  - Allow Guest Access: $($EnableGuestAccess.IsPresent)" -ForegroundColor Gray

    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Assign policy to users: Grant-CsTeamsChannelsPolicy -Identity 'user@contoso.com' -PolicyName '$PolicyName'" -ForegroundColor Yellow
    Write-Host "  2. Or apply to all: Grant-CsTeamsChannelsPolicy -PolicyName '$PolicyName'" -ForegroundColor Yellow
    Write-Host "  3. Test shared channel creation in Teams" -ForegroundColor Yellow
}

<#
.SYNOPSIS
    Tests Teams shared channel functionality.
#>
function Test-TeamsSharedChannel {
    Write-Host "Testing Teams Shared Channel Configuration..." -ForegroundColor Yellow
    Write-Host ""

    Write-Host "Verification Checklist:" -ForegroundColor Cyan
    Write-Host "  [ ] Teams Channels Policy allows shared channel creation" -ForegroundColor White
    Write-Host "  [ ] External Access Policy allows external users" -ForegroundColor White
    Write-Host "  [ ] B2B Direct Connect configured in Entra (both tenants)" -ForegroundColor White
    Write-Host "  [ ] External user can see shared channel in their Teams" -ForegroundColor White
    Write-Host "  [ ] File sharing works in shared channel" -ForegroundColor White
    Write-Host "  [ ] Meetings work in shared channel" -ForegroundColor White
}

Export-ModuleMember -Function @('Test-TeamsSharedChannel')
