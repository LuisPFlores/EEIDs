#Requires -Modules Microsoft.Graph.ConditionalAccess

<#
.SYNOPSIS
    Configures Conditional Access policies for B2B guest users.

.DESCRIPTION
    Creates and manages Conditional Access policies targeting guest users
    to enforce MFA, device compliance, session controls, and location restrictions.

.PARAMETER PolicyName
    Name of the Conditional Access policy.

.PARAMETER Description
    Description of the policy.

.PARAMETER RequireMfa
    Require multi-factor authentication for guests.

.PARAMETER RequireCompliantDevice
    Require compliant device (Intune enrolled).

.PARAMETER RequireHybridJoinedDevice
    Require hybrid Azure AD joined device.

.PARAMETER BlockUnmanagedDevices
    Block access from unmanaged devices.

.PARAMETER SessionControl
    Session control type: ApplicationGranted, ConditionalAccess, or Disabled.

.PARAMETER SignInFrequency
    Sign-in frequency in days or hours.

.PARAMETER PersistenceDuration
    Persistent session duration.

.PARAMETER TargetApps
    Array of app IDs to target. Use "*" for all cloud apps.

.PARAMETER ExcludeApps
    Array of app IDs to exclude.

.PARAMETER TargetLocations
    Array of location IDs to target. Use "AllTrusted" for trusted locations.

.PARAMETER ExcludeLocations
    Array of location locations to exclude.

.PARAMETER EnablePolicy
    Enable the policy after creation.

.PARAMETER UseStandardTemplate
    Use a standard template (MFARequired, DeviceCompliant, BlockUnmanaged).

.PARAMETER ListPolicies
    List existing Conditional Access policies.

.PARAMETER DisablePolicy
    Disable an existing policy by name.

.PARAMETER RemovePolicy
    Remove an existing policy by name.

.EXAMPLE
    .\Set-B2BConditionalAccess.ps1 -PolicyName "MFA Required for Guests" -RequireMfa
    Creates policy requiring MFA for all guest users.

.EXAMPLE
    .\Set-B2BConditionalAccess.ps1 -UseStandardTemplate MFARequired -EnablePolicy
    Creates standard MFA policy from template.
#>

[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "Create", Mandatory = $true)]
    [string]$PolicyName,

    [Parameter(ParameterSetName = "Create")]
    [string]$Description,

    [Parameter(ParameterSetName = "Create")]
    [switch]$RequireMfa,

    [Parameter(ParameterSetName = "Create")]
    [switch]$RequireCompliantDevice,

    [Parameter(ParameterSetName = "Create")]
    [switch]$RequireHybridJoinedDevice,

    [Parameter(ParameterSetName = "Create")]
    [switch]$BlockUnmanagedDevices,

    [Parameter(ParameterSetName = "Create")]
    [ValidateSet("ApplicationGranted", "ConditionalAccess", "Disabled")]
    [string]$SessionControl = "Disabled",

    [Parameter(ParameterSetName = "Create")]
    [int]$SignInFrequency,

    [Parameter(ParameterSetName = "Create")]
    [string]$PersistenceDuration,

    [Parameter(ParameterSetName = "Create")]
    [string[]]$TargetApps = @("*"),

    [Parameter(ParameterSetName = "Create")]
    [string[]]$ExcludeApps = @(),

    [Parameter(ParameterSetName = "Create")]
    [string[]]$TargetLocations = @(),

    [Parameter(ParameterSetName = "Create")]
    [string[]]$ExcludeLocations = @(),

    [Parameter(ParameterSetName = "Create")]
    [switch]$EnablePolicy,

    [Parameter(ParameterSetName = "Template")]
    [ValidateSet("MFARequired", "DeviceCompliant", "BlockUnmanaged", "TrustMFA")]
    [string]$UseStandardTemplate,

    [Parameter(ParameterSetName = "List")]
    [switch]$ListPolicies,

    [Parameter(ParameterSetName = "Disable")]
    [string]$DisablePolicy,

    [Parameter(ParameterSetName = "Remove")]
    [string]$RemovePolicy
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  B2B Conditional Access" -ForegroundColor Cyan
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
Write-Host ""

function Get-ConditionalAccessPolicyTemplate {
    param([string]$TemplateName)

    $templates = @{
        "MFARequired" = @{
            Name = "MFA Required for Guest Users"
            Description = "Require MFA for all guest users accessing resources"
            RequireMfa = $true
            TargetApps = @("*")
        }
        "DeviceCompliant" = @{
            Name = "Compliant Device Required for Guests"
            Description = "Require Intune compliant device for guest access"
            RequireCompliantDevice = $true
            TargetApps = @("*")
        }
        "BlockUnmanaged" = @{
            Name = "Block Unmanaged Devices for Guests"
            Description = "Block access from unmanaged devices for guest users"
            BlockUnmanagedDevices = $true
            TargetApps = @("*")
        }
        "TrustMFA" = @{
            Name = "Trust MFA from Home Tenant"
            Description = "Trust MFA performed at user's home organization"
            RequireMfa = $false
            TargetApps = @("*")
        }
    }

    return $templates[$TemplateName]
}

function New-B2BConditionalAccessPolicy {
    param(
        [string]$Name,
        [string]$Desc,
        [bool]$Mfa,
        [bool]$Compliant,
        [bool]$Hybrid,
        [bool]$BlockUnmanaged,
        [string]$Session,
        [string[]]$Apps,
        [string[]]$ExcludeApps,
        [string[]]$Locations,
        [string[]]$ExcludeLocs,
        [bool]$Enabled
    )

    Write-Host "Creating Conditional Access policy: $Name" -ForegroundColor Yellow

    # Build conditions
    $conditions = @{
        User = @{
            IncludeUsers = @("GuestOrExternalUserTypes")
            ExcludeUsers = @()
            IncludeGroups = @()
            ExcludeGroups = @()
            IncludeRoles = @()
            ExcludeRoles = @()
        }
        Applications = @{
            IncludeApplications = $Apps
            ExcludeApplications = $ExcludeApps
        }
    }

    if ($Locations -and $Locations.Count -gt 0) {
        $conditions.Applications.IncludeLocations = $Locations
    }

    if ($ExcludeLocs -and $ExcludeLocs.Count -gt 0) {
        $conditions.Applications.ExcludeLocations = $ExcludeLocs
    }

    # Build grant controls
    $grantControls = @{
        Operator = "OR"
        BuiltInControls = @()
    }

    if ($Mfa) {
        $grantControls.BuiltInControls += "mfa"
    }

    if ($Compliant) {
        $grantControls.BuiltInControls += "compliantDevice"
    }

    if ($Hybrid) {
        $grantControls.BuiltInControls += "hybridAdJoinedDevice"
    }

    if ($BlockUnmanaged) {
        $grantControls.BuiltInControls = @("compliantDevice", "hybridAdJoinedDevice")
        $grantControls.Operator = "AND"
    }

    # Build session controls
    $sessionControls = @{}

    if ($Session -eq "ApplicationGranted") {
        $sessionControls.ApplicationEnforcedRestrictions = $true
    }
    elseif ($Session -eq "ConditionalAccess") {
        $sessionControls.ConditionalAccessSession = $true
    }

    # Build request body
    $params = @{
        DisplayName = $Name
        Description = $Desc
        State = if ($Enabled) { "enabled" } else { "disabled" }
        Conditions = $conditions
        GrantControls = $grantControls
        SessionControls = $sessionControls
    }

    try {
        # Check if policy exists
        $existing = Get-MgConditionalAccessPolicy -All | Where-Object { $_.DisplayName -eq $Name }

        if ($existing) {
            Write-Host "  Policy exists, updating..." -ForegroundColor Yellow
            $result = Update-MgConditionalAccessPolicy -ConditionalAccessPolicyId $existing.Id -BodyParameter $params -ErrorAction Stop
        }
        else {
            Write-Host "  Creating new policy..." -ForegroundColor Gray
            $result = New-MgConditionalAccessPolicy -BodyParameter $params -ErrorAction Stop
        }

        Write-Host "  Policy configured successfully!" -ForegroundColor Green
        Write-Host "  State: $($params.State)" -ForegroundColor Gray

        return $result
    }
    catch {
        Write-Error "  Failed to configure policy: $_"
        return $null
    }
}

function Get-B2BConditionalAccessPolicies {
    try {
        $policies = Get-MgConditionalAccessPolicy -All

        if ($policies) {
            Write-Host "Found $($policies.Count) Conditional Access policies:" -ForegroundColor Green
            Write-Host ""
            
            foreach ($policy in $policies) {
                $state = if ($policy.State -eq "enabled") { "[ON]" } else { "[OFF]" }
                $color = if ($policy.State -eq "enabled") { "Green" } else { "Yellow" }
                
                Write-Host "  $state $($policy.DisplayName)" -ForegroundColor $color
                Write-Host "      $($policy.Description)" -ForegroundColor Gray
                
                if ($policy.GrantControls.BuiltInControls) {
                    Write-Host "      Grants: $($policy.GrantControls.BuiltInControls -join ', ')" -ForegroundColor Gray
                }
            }

            return $policies
        }
        else {
            Write-Host "No Conditional Access policies found." -ForegroundColor Yellow
            return @()
        }
    }
    catch {
        Write-Error "Failed to list policies: $_"
        return $null
    }
}

# Execute based on parameter set
switch ($PSCmdlet.ParameterSetName) {
    "List" {
        Get-B2BConditionalAccessPolicies
    }
    "Template" {
        $template = Get-ConditionalAccessPolicyTemplate -TemplateName $UseStandardTemplate
        
        if ($template) {
            New-B2BConditionalAccessPolicy -Name $template.Name `
                -Desc $template.Description `
                -Mfa $template.RequireMfa `
                -Compliant $template.RequireCompliantDevice `
                -BlockUnmanaged $template.BlockUnmanagedDevices `
                -Apps $template.TargetApps `
                -Enabled $EnablePolicy.IsPresent
        }
    }
    "Create" {
        New-B2BConditionalAccessPolicy -Name $PolicyName `
            -Desc $Description `
            -Mfa $RequireMfa.IsPresent `
            -Compliant $RequireCompliantDevice.IsPresent `
            -Hybrid $RequireHybridJoinedDevice.IsPresent `
            -BlockUnmanaged $BlockUnmanagedDevices.IsPresent `
            -Session $SessionControl `
            -Apps $TargetApps `
            -ExcludeApps $ExcludeApps `
            -Locations $TargetLocations `
            -ExcludeLocs $ExcludeLocations `
            -Enabled $EnablePolicy.IsPresent
    }
    "Disable" {
        if ($DisablePolicy) {
            try {
                $policy = Get-MgConditionalAccessPolicy -All | Where-Object { $_.DisplayName -eq $DisablePolicy }
                if ($policy) {
                    Update-MgConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -State "disabled" -ErrorAction Stop
                    Write-Host "Policy '$DisablePolicy' disabled" -ForegroundColor Green
                }
                else {
                    Write-Warning "Policy not found: $DisablePolicy"
                }
            }
            catch {
                Write-Error "Failed to disable policy: $_"
            }
        }
    }
    "Remove" {
        if ($RemovePolicy) {
            try {
                $policy = Get-MgConditionalAccessPolicy -All | Where-Object { $_.DisplayName -eq $RemovePolicy }
                if ($policy) {
                    Remove-MgConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -ErrorAction Stop
                    Write-Host "Policy '$RemovePolicy' removed" -ForegroundColor Green
                }
                else {
                    Write-Warning "Policy not found: $RemovePolicy"
                }
            }
            catch {
                Write-Error "Failed to remove policy: $_"
            }
        }
    }
}

<#
.SYNOPSIS
    Gets named locations for Conditional Access.
#>
function Get-B2BNamedLocations {
    try {
        $locations = Get-MgConditionalAccessNamedLocation -All
        
        if ($locations) {
            Write-Host "Named locations:" -ForegroundColor Cyan
            $locations | Format-Table DisplayName, Id, OdataType -AutoSize
            return $locations
        }
        else {
            Write-Host "No named locations configured." -ForegroundColor Yellow
            return @()
        }
    }
    catch {
        Write-Error "Failed to get locations: $_"
        return $null
    }
}

Export-ModuleMember -Function @('Get-B2BNamedLocations')
