#Requires -Modules Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Identity.SignIns

<#
.SYNOPSIS
    Configures identity providers for CIAM tenant.

.DESCRIPTION
    Configures various identity providers including:
    - Email one-time passcode (built-in)
    - Google federation
    - Facebook federation
    - SAML federation
    - OIDC federation

.PARAMETER GoogleClientId
    Google OAuth client ID.

.PARAMETER GoogleClientSecret
    Google OAuth client secret.

.PARAMETER FacebookAppId
    Facebook App ID.

.PARAMETER FacebookAppSecret
    Facebook App secret.

.PARAMETER EnableEmailOTP
    Enable email one-time passcode (default: true).

.EXAMPLE
    .\Set-CIAMIdentityProviders.ps1 -EnableEmailOTP $true
    Enables email OTP only.

.EXAMPLE
    .\Set-CIAMIdentityProviders.ps1 -GoogleClientId "xxx" -GoogleClientSecret "yyy"
    Enables Google federation.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$GoogleClientId,

    [Parameter()]
    [string]$GoogleClientSecret,

    [Parameter()]
    [string]$FacebookAppId,

    [Parameter()]
    [string]$FacebookAppSecret,

    [Parameter()]
    [bool]$EnableEmailOTP = $true
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Configure CIAM Identity Providers" -ForegroundColor Cyan
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

function Enable-EmailOTP {
    Write-Host "Configuring Email One-Time Passcode..." -ForegroundColor Yellow

    # Check if email identity provider exists
    $providers = Get-MgIdentityProvider -All

    # Email OTP is represented as "EmailPasswordless" or built-in
    $emailProvider = $providers | Where-Object { $_.Type -eq "EmailPasswordless" }

    if ($emailProvider) {
        Write-Host "  Email OTP already configured" -ForegroundColor Green
        return $emailProvider
    }

    # Note: Email OTP is typically enabled by default in external tenants
    # Additional configuration may be needed via user flows

    Write-Host "  Email OTP enabled by default in external tenants" -ForegroundColor Green
    Write-Host "  Configure via User Flows to make it available to users" -ForegroundColor Gray

    return $null
}

function Set-GoogleIdentityProvider {
    param(
        [string]$ClientId,
        [string]$ClientSecret
    )

    Write-Host "Configuring Google Identity Provider..." -ForegroundColor Yellow

    if (-not $ClientId -or -not $ClientSecret) {
        Write-Warning "Google ClientId and ClientSecret required"
        Write-Host "  To obtain credentials:" -ForegroundColor Gray
        Write-Host "    1. Go to https://console.cloud.google.com" -ForegroundColor Gray
        Write-Host "    2. Create OAuth 2.0 credentials" -ForegroundColor Gray
        Write-Host "    3. Add authorized redirect URI: https://login.microsoftonline.com/{tenant}/oauth2/authresp" -ForegroundColor Gray
        return $null
    }

    $params = @{
        Type     = "Google"
        Name     = "Google"
        ClientId     = $ClientId
        ClientSecret = $ClientSecret
    }

    try {
        # Check if Google provider exists
        $existing = Get-MgIdentityProvider -All | Where-Object { $_.Type -eq "Google" }

        if ($existing) {
            Write-Host "  Google provider exists, updating..." -ForegroundColor Yellow
            $result = Update-MgIdentityProvider -IdentityProviderId $existing.Id -BodyParameter $params
        }
        else {
            Write-Host "  Creating new Google provider..." -ForegroundColor Yellow
            $result = New-MgIdentityProvider -BodyParameter $params
        }

        Write-Host "  Google provider configured successfully!" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Error "  Failed to configure Google: $_"
        return $null
    }
}

function Set-FacebookIdentityProvider {
    param(
        [string]$AppId,
        [string]$AppSecret
    )

    Write-Host "Configuring Facebook Identity Provider..." -ForegroundColor Yellow

    if (-not $AppId -or -not $AppSecret) {
        Write-Warning "Facebook AppId and AppSecret required"
        Write-Host "  To obtain credentials:" -ForegroundColor Gray
        Write-Host "    1. Go to https://developers.facebook.com" -ForegroundColor Gray
        Write-Host "    2. Create an app with Facebook Login product" -ForegroundColor Gray
        Write-Host "    3. Add redirect URI: https://login.microsoftonline.com/{tenant}/oauth2/authresp" -ForegroundColor Gray
        return $null
    }

    $params = @{
        Type     = "Facebook"
        Name     = "Facebook"
        ClientId     = $AppId
        ClientSecret = $AppSecret
    }

    try {
        $existing = Get-MgIdentityProvider -All | Where-Object { $_.Type -eq "Facebook" }

        if ($existing) {
            Write-Host "  Facebook provider exists, updating..." -ForegroundColor Yellow
            $result = Update-MgIdentityProvider -IdentityProviderId $existing.Id -BodyParameter $params
        }
        else {
            Write-Host "  Creating new Facebook provider..." -ForegroundColor Yellow
            $result = New-MgIdentityProvider -BodyParameter $params
        }

        Write-Host "  Facebook provider configured successfully!" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Error "  Failed to configure Facebook: $_"
        return $null
    }
}

function Set-SamlIdentityProvider {
    param(
        [string]$Name,
        [string]$EntityId,
        [string]$LoginUrl,
        [string]$LogoutUrl,
        [string]$Certificate
    )

    Write-Host "Configuring SAML Identity Provider: $Name..." -ForegroundColor Yellow

    $params = @{
        Type      = "SAML"
        Name      = $Name
        IssuerUri = $EntityId
        PassiveSignInUri = $LoginUrl
        LoggingOutUri = $LogoutUrl
        Certificate = $Certificate
    }

    try {
        $result = New-MgIdentityProvider -BodyParameter $params -ErrorAction Stop
        Write-Host "  SAML provider '$Name' configured successfully!" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Error "  Failed to configure SAML provider: $_"
        return $null
    }
}

function Set-OidcIdentityProvider {
    param(
        [string]$Name,
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$AuthorizationUrl,
        [string]$TokenUrl,
        [string]$UserInfoUrl,
        [string]$Issuer,
        [string]$Scope
    )

    Write-Host "Configuring OIDC Identity Provider: $Name..." -ForegroundColor Yellow

    $claimsMapping = @{
        oid = $oid
        given_name = $givenName
        surname = $surname
        displayName = $displayName
        email = $email
    }

    $params = @{
        Type = "OIDC"
        Name = $Name
        ClientId = $ClientId
        ClientSecret = $ClientSecret
        Oauth2Settings = @{
            AuthorizationUrl = $AuthorizationUrl
            TokenUrl = $TokenUrl
            UserInfoUrl = $UserInfoUrl
            Issuer = $Issuer
            Scope = $Scope
        }
        ClaimsMapping = $claimsMapping
    }

    try {
        $result = New-MgIdentityProvider -BodyParameter $params -ErrorAction Stop
        Write-Host "  OIDC provider '$Name' configured successfully!" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Error "  Failed to configure OIDC provider: $_"
        return $null
    }
}

# Execute configuration
Write-Host "Starting identity provider configuration..." -ForegroundColor Cyan
Write-Host ""

$configuredProviders = @()

# Enable Email OTP
if ($EnableEmailOTP) {
    $result = Enable-EmailOTP
    if ($result) {
        $configuredProviders += $result
    }
}

# Configure Google
if ($GoogleClientId -and $GoogleClientSecret) {
    $result = Set-GoogleIdentityProvider -ClientId $GoogleClientId -ClientSecret $GoogleClientSecret
    if ($result) {
        $configuredProviders += $result
    }
}

# Configure Facebook
if ($FacebookAppId -and $FacebookAppSecret) {
    $result = Set-FacebookIdentityProvider -AppId $FacebookAppId -AppSecret $FacebookAppSecret
    if ($result) {
        $configuredProviders += $result
    }
}

# List current providers
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Current Identity Providers" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

$allProviders = Get-MgIdentityProvider -All

if ($allProviders) {
    Write-Host ""
    $allProviders | Format-Table Name, Type, State -AutoSize
}
else {
    Write-Host "No identity providers configured." -ForegroundColor Yellow
    Write-Host "Email one-time passcode is available by default in external tenants." -ForegroundColor Gray
}

Write-Host ""
Write-Host "Configuration complete!" -ForegroundColor Green

<#
.SYNOPSIS
    Lists all configured identity providers.

.EXAMPLE
    .\Set-CIAMIdentityProviders.ps1 -ListProviders
#>
function Get-CIAMIdentityProviders {
    $providers = Get-MgIdentityProvider -All
    return $providers
}

# Export functions for use in other scripts
Export-ModuleMember -Function @(
    'Enable-EmailOTP',
    'Set-GoogleIdentityProvider',
    'Set-FacebookIdentityProvider',
    'Set-SamlIdentityProvider',
    'Set-OidcIdentityProvider',
    'Get-CIAMIdentityProviders'
)
