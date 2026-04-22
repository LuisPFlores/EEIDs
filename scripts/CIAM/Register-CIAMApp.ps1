#Requires -Modules Microsoft.Graph.Applications

<#
.SYNOPSIS
    Registers and configures applications for CIAM.

.DESCRIPTION
    Registers an application in the CIAM tenant and configures:
    - Redirect URIs
    - Implicit grant settings
    - Token claims
    - API permissions
    - App roles

.PARAMETER DisplayName
    The display name for the application.

.PARAMETER RedirectUris
    Array of redirect URIs.

.PARAMETER ApplicationType
    Type of application: Web, SPA, Mobile, Desktop.

.PARAMETER SignInAudience
    Who can sign in: AzureADMultipleOrgs, AzureADMyOrg, AzureADandPersonalMicrosoftAccount, PersonalMicrosoftAccount.

.PARAMETER EnableIDToken
    Enable ID tokens (default: true).

.PARAMETER EnableAccessToken
    Enable access tokens (default: true).

.PARAMETER RequiredResourceAccess
    Graph API permissions to request (e.g., @('User.Read', 'User.ReadBasic.All')).

.EXAMPLE
    .\Register-CIAMApp.ps1 -DisplayName "Customer Portal" -RedirectUris @("http://localhost:3000")
    Registers a SPA application.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter()]
    [string[]]$RedirectUris = @(),

    [Parameter()]
    [ValidateSet("Web", "SPA", "Mobile", "Desktop", "Daemon")]
    [string]$ApplicationType = "Web",

    [Parameter()]
    [ValidateSet(
        "AzureADMultipleOrgs",
        "AzureADMyOrg",
        "AzureADandPersonalMicrosoftAccount",
        "PersonalMicrosoftAccount"
    )]
    [string]$SignInAudience = "AzureADMultipleOrgs",

    [Parameter()]
    [bool]$EnableIDToken = $true,

    [Parameter()]
    [bool]$EnableAccessToken = $true,

    [Parameter()]
    [string[]]$RequiredResourceAccess = @(),

    [Parameter()]
    [hashtable]$AppRoles = @{}
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Register CIAM Application" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Verify connection
$context = Get-MgContext -ErrorAction SilentlyContinue
if (-not $context) {
    Write-Error "Not connected. Run .\Connect-EntraCIAM.ps1 first."
    return
}

$TenantId = $context.TenantId
Write-Host "Target Tenant: $TenantId" -ForegroundColor Yellow
Write-Host ""

function Register-CIAMApplication {
    param(
        [string]$AppName,
        [string[]]$RedirectUris,
        [string]$AppType,
        [string]$Audience,
        [bool]$IdToken,
        [bool]$AccessToken
    )

    Write-Host "Registering application: $AppName" -ForegroundColor Yellow
    Write-Host "  Type: $AppType" -ForegroundColor Gray
    Write-Host "  Audience: $Audience" -ForegroundColor Gray
    Write-Host "  Redirect URIs: $($RedirectUris.Count)" -ForegroundColor Gray
    Write-Host ""

    # Check if app already exists
    $existingApp = Get-MgApplication -All | Where-Object { $_.DisplayName -eq $AppName }

    if ($existingApp) {
        Write-Host "Application already exists. Updating..." -ForegroundColor Yellow
        $app = $existingApp
    }
    else {
        # Build application parameters based on type
        $params = @{
            DisplayName = $AppName
            SignInAudience = $Audience
        }

        # Configure redirect URIs and implicit grant based on type
        switch ($AppType) {
            "Web" {
                $params.Web = @{
                    RedirectUris = $RedirectUris
                    ImplicitGrantSettings = @{
                        EnableIdTokenIssuance = $IdToken
                        EnableAccessTokenIssuance = $AccessToken
                    }
                }
            }
            "SPA" {
                $params.Spa = @{
                    RedirectUris = $RedirectUris
                }
            }
            "Mobile" {
                $params.Mobile = @{
                    RedirectUris = $RedirectUris
                }
            }
            "Desktop" {
                $params.PublicClient = @{
                    RedirectUris = $RedirectUris
                }
            }
            "Daemon" {
                $params.ServicePrincipalType = "Daemon"
            }
        }

        try {
            $app = New-MgApplication -BodyParameter $params -ErrorAction Stop
            Write-Host "Application registered successfully!" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to register application: $_"
            return $null
        }
    }

    return $app
}

function Add-ApiPermissions {
    param(
        [string]$AppId,
        [string[]]$Permissions
    )

    if (-not $Permissions -or $Permissions.Count -eq 0) {
        Write-Host "  No API permissions to add" -ForegroundColor Gray
        return
    }

    Write-Host "  Adding API permissions..." -ForegroundColor Yellow

    # Get Microsoft Graph service principal
    $graphSp = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -ErrorAction SilentlyContinue

    if (-not $graphSp) {
        Write-Warning "  Could not find Microsoft Graph service principal"
        return
    }

    # Build required resource access
    $resourceAccess = @()

    foreach ($perm in $Permissions) {
        if ($perm -match "^\w+\.\w+$") {
            $scope = $perm -replace "\.", "_"
            $resourceAccess += @{
                ResourceAppId = $graphSp.AppId
                ResourceAccess = @(
                    @{
                        Id = $graphSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq $perm } | Select-Object -First 1 -ExpandProperty Id
                        Type = "Scope"
                    }
                )
            }
        }
    }

    try {
        $app = Get-MgApplication -ApplicationId $AppId

        # Update required resource access
        Update-MgApplication -ApplicationId $AppId -RequiredResourceAccess $resourceAccess -ErrorAction SilentlyContinue

        Write-Host "  API permissions added" -ForegroundColor Green
    }
    catch {
        Write-Warning "  Could not add permissions: $_"
    }
}

function Add-AppRoles {
    param(
        [string]$AppId,
        [hashtable]$Roles
    )

    if (-not $Roles -or $Roles.Count -eq 0) {
        Write-Host "  No app roles to add" -ForegroundColor Gray
        return
    }

    Write-Host "  Adding app roles..." -ForegroundColor Yellow

    $appRoles = @()

    foreach ($key in $Roles.Keys) {
        $appRoles += @{
            Id = [Guid]::NewGuid().ToString()
            DisplayName = $key
            Description = $Roles[$key]
            IsEnabled = $true
            Value = $key
        }
    }

    try {
        $app = Get-MgApplication -ApplicationId $AppId
        $app.AppRoles = $appRoles

        Update-MgApplication -ApplicationId $AppId -AppRoles $appRoles -ErrorAction SilentlyContinue

        Write-Host "  App roles added" -ForegroundColor Green
    }
    catch {
        Write-Warning "  Could not add app roles: $_"
    }
}

# Register the application
$app = Register-CIAMApplication -AppName $DisplayName `
    -RedirectUris $RedirectUris `
    -AppType $ApplicationType `
    -Audience $SignInAudience `
    -IdToken $EnableIDToken `
    -AccessToken $EnableAccessToken

if ($app) {
    Write-Host ""
    Write-Host "Application Details:" -ForegroundColor Cyan
    Write-Host "  App ID: $($app.AppId)" -ForegroundColor White
    Write-Host "  Object ID: $($app.Id)" -ForegroundColor White
    Write-Host "  Display Name: $($app.DisplayName)" -ForegroundColor White

    # Add API permissions
    if ($RequiredResourceAccess) {
        Add-ApiPermissions -AppId $app.AppId -Permissions $RequiredResourceAccess
    }

    # Add app roles
    if ($AppRoles) {
        Add-AppRoles -AppId $app.AppId -Roles $AppRoles
    }

    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  OAuth Configuration" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""

    $tenantInfo = Get-MgOrganization -OrganizationId $TenantId
    $tenantDomain = $tenantInfo.VerifiedDomains[0].Name

    Write-Host "Authorization Endpoint:" -ForegroundColor Yellow
    Write-Host "  https://login.microsoftonline.com/$tenantDomain/oauth2/v2.0/authorize" -ForegroundColor White
    Write-Host ""
    Write-Host "Token Endpoint:" -ForegroundColor Yellow
    Write-Host "  https://login.microsoftonline.com/$tenantDomain/oauth2/v2.0/token" -ForegroundColor White
    Write-Host ""
    Write-Host "Logout Endpoint:" -ForegroundColor Yellow
    Write-Host "  https://login.microsoftonline.com/$tenantDomain/oauth2/v2.0/logout" -ForegroundColor White
    Write-Host ""

    # Generate sample URLs
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  User Flow Integration" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To use with user flows, add this redirect URI to your app registration:" -ForegroundColor Yellow
    foreach ($uri in $RedirectUris) {
        Write-Host "  $uri" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Complete the setup:" -ForegroundColor Green
    Write-Host "  1. Go to External Identities > User flows" -ForegroundColor Gray
    Write-Host "  2. Create or edit a user flow" -ForegroundColor Gray
    Write-Host "  3. Under 'Applications', add this app" -ForegroundColor Gray
    Write-Host "  4. Note the UserFlow ID for the authorization URL" -ForegroundColor Gray

    # Return app info as object
    $appInfo = @{
        AppId = $app.AppId
        ObjectId = $app.Id
        DisplayName = $app.DisplayName
        TenantId = $TenantId
        TenantDomain = $tenantDomain
        RedirectUris = $RedirectUris
    }

    return $appInfo
}

<#
.SYNOPSIS
    Lists all registered applications.

.EXAMPLE
    Get-CIAMApplications
#>
function Get-CIAMApplications {
    return Get-MgApplication -All | Select-Object AppId, DisplayName, SignInAudience
}

Export-ModuleMember -Function @('Register-CIAMApplication', 'Get-CIAMApplications')
