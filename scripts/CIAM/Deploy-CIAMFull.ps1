#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Applications, Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Organization

<#
.SYNOPSIS
    Deploys a complete CIAM environment.

.DESCRIPTION
    Orchestrates the complete CIAM deployment including:
    - Identity provider configuration
    - Application registration
    - User flow creation
    - Branding setup

    This is the main entry point for automated CIAM deployment.

.PARAMETER TenantDomain
    The domain name for the CIAM tenant (e.g., contosocustomers.onmicrosoft.com).

.PARAMETER AppName
    The display name for the customer-facing application.

.PARAMETER AppUri
    The redirect URI for the application.

.PARAMETER EnableGoogle
    Enable Google as an identity provider.

.PARAMETER GoogleClientId
    Google OAuth client ID.

.PARAMETER GoogleClientSecret
    Google OAuth client secret.

.PARAMETER EnableFacebook
    Enable Facebook as an identity provider.

.PARAMETER FacebookAppId
    Facebook App ID.

.PARAMETER FacebookAppSecret
    Facebook App secret.

.PARAMETER EnableEmailOTP
    Enable email one-time passcode (default: true).

.PARAMETER BannerText
    Company name for sign-in page banner.

.PARAMETER PrimaryColor
    Primary brand color (hex).

.PARAMETER BackgroundColor
    Background color (hex).

.PARAMETER LogoPath
    Path to logo file.

.PARAMETER BackgroundImagePath
    Path to background image file.

.EXAMPLE
    .\Deploy-CIAMFull.ps1 -TenantDomain "contosocustomers.onmicrosoft.com" -AppName "Customer Portal" -AppUri "http://localhost:3000"
    Deploys CIAM with default settings.

.EXAMPLE
    .\Deploy-CIAMFull.ps1 -AppName "My App" -EnableGoogle -GoogleClientId "xxx" -GoogleClientSecret "yyy"
    Deploys CIAM with Google federation enabled.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantDomain,

    [Parameter(Mandatory = $true)]
    [string]$AppName,

    [Parameter(Mandatory = $true)]
    [string]$AppUri,

    [Parameter()]
    [switch]$EnableGoogle,

    [Parameter()]
    [string]$GoogleClientId,

    [Parameter()]
    [string]$GoogleClientSecret,

    [Parameter()]
    [switch]$EnableFacebook,

    [Parameter()]
    [string]$FacebookAppId,

    [Parameter()]
    [string]$FacebookAppSecret,

    [Parameter()]
    [bool]$EnableEmailOTP = $true,

    [Parameter()]
    [string]$BannerText,

    [Parameter()]
    [string]$PrimaryColor = "#0078D4",

    [Parameter()]
    [string]$BackgroundColor = "#F2F2F2",

    [Parameter()]
    [string]$LogoPath,

    [Parameter()]
    [string]$BackgroundImagePath,

    [Parameter()]
    [string]$ConfigFile,

    [Parameter()]
    [switch]$SkipBranding,

    [Parameter()]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  CIAM Full Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$deploymentConfig = @{
    TenantDomain = $TenantDomain
    AppName = $AppName
    AppUri = $AppUri
    EnableGoogle = $EnableGoogle.IsPresent
    GoogleClientId = $GoogleClientId
    GoogleClientSecret = $GoogleClientSecret
    EnableFacebook = $EnableFacebook.IsPresent
    FacebookAppId = $FacebookAppId
    FacebookAppSecret = $FacebookAppSecret
    EnableEmailOTP = $EnableEmailOTP
    BannerText = $BannerText
    PrimaryColor = $PrimaryColor
    BackgroundColor = $BackgroundColor
    LogoPath = $LogoPath
    BackgroundImagePath = $BackgroundImagePath
    SkipBranding = $SkipBranding.IsPresent
    DryRun = $DryRun.IsPresent
}

# Load config from file if provided
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    Write-Host "Loading configuration from: $ConfigFile" -ForegroundColor Yellow
    $fileConfig = Get-Content $ConfigFile | ConvertFrom-Json
    foreach ($prop in $fileConfig.PSObject.Properties) {
        if (-not $deploymentConfig.ContainsKey($prop.Name)) {
            $deploymentConfig[$prop.Name] = $prop.Value
        }
    }
}

# Display configuration
Write-Host "Deployment Configuration:" -ForegroundColor Cyan
Write-Host "  Tenant Domain: $($deploymentConfig.TenantDomain)" -ForegroundColor White
Write-Host "  App Name: $($deploymentConfig.AppName)" -ForegroundColor White
Write-Host "  Redirect URI: $($deploymentConfig.AppUri)" -ForegroundColor White
Write-Host "  Email OTP: $($deploymentConfig.EnableEmailOTP)" -ForegroundColor White
Write-Host "  Google: $($deploymentConfig.EnableGoogle)" -ForegroundColor White
Write-Host "  Facebook: $($deploymentConfig.EnableFacebook)" -ForegroundColor White
Write-Host "  Skip Branding: $($deploymentConfig.SkipBranding)" -ForegroundColor White
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
    Write-Host "  .\Connect-EntraCIAM.ps1" -ForegroundColor Gray
    return
}
Write-Host "  Connected to: $($context.TenantId)" -ForegroundColor Green
Write-Host ""

# Step 2: Configure Identity Providers
Write-Host "[2/5] Configuring Identity Providers..." -ForegroundColor Yellow

if ($deploymentConfig.EnableEmailOTP) {
    Write-Host "  Email OTP will be enabled" -ForegroundColor Gray
}

if ($deploymentConfig.EnableGoogle) {
    if ($deploymentConfig.GoogleClientId -and $deploymentConfig.GoogleClientSecret) {
        Write-Host "  Configuring Google: YES" -ForegroundColor Gray
    }
    else {
        Write-Warning "  Google enabled but credentials not provided - skipping"
    }
}

if ($deploymentConfig.EnableFacebook) {
    if ($deploymentConfig.FacebookAppId -and $deploymentConfig.FacebookAppSecret) {
        Write-Host "  Configuring Facebook: YES" -ForegroundColor Gray
    }
    else {
        Write-Warning "  Facebook enabled but credentials not provided - skipping"
    }
}

if (-not $DryRun) {
    # Source and execute the IdP configuration
    . "$PSScriptRoot\Set-CIAMIdentityProviders.ps1"

    if ($deploymentConfig.EnableEmailOTP) {
        Enable-EmailOTP
    }

    if ($deploymentConfig.EnableGoogle -and $deploymentConfig.GoogleClientId -and $deploymentConfig.GoogleClientSecret) {
        Set-GoogleIdentityProvider -ClientId $deploymentConfig.GoogleClientId -ClientSecret $deploymentConfig.GoogleClientSecret
    }

    if ($deploymentConfig.EnableFacebook -and $deploymentConfig.FacebookAppId -and $deploymentConfig.FacebookAppSecret) {
        Set-FacebookIdentityProvider -AppId $deploymentConfig.FacebookAppId -AppSecret $deploymentConfig.FacebookAppSecret
    }
}
Write-Host ""

# Step 3: Register Application
Write-Host "[3/5] Registering Application..." -ForegroundColor Yellow

$appInfo = @{
    AppId = "to-be-created"
    DisplayName = $deploymentConfig.AppName
}

if (-not $DryRun) {
    . "$PSScriptRoot\Register-CIAMApp.ps1"

    $appInfo = Register-CIAMApplication `
        -AppName $deploymentConfig.AppName `
        -RedirectUris @($deploymentConfig.AppUri) `
        -AppType "SPA" `
        -Audience "AzureADMultipleOrgs" `
        -IdToken $true `
        -AccessToken $true

    if ($appInfo) {
        Write-Host "  App ID: $($appInfo.AppId)" -ForegroundColor Green
    }
}
Write-Host ""

# Step 4: User Flows
Write-Host "[4/5] Creating User Flows..." -ForegroundColor Yellow

$providers = @("EmailPasswordless")
if ($deploymentConfig.EnableGoogle -and $deploymentConfig.GoogleClientId) {
    $providers += "Google"
}
if ($deploymentConfig.EnableFacebook -and $deploymentConfig.FacebookAppId) {
    $providers += "Facebook"
}

Write-Host "  Providers: $($providers -join ', ')" -ForegroundColor Gray
Write-Host "  User flow creation requires Azure Portal for CIAM tenants" -ForegroundColor Yellow
Write-Host "  URL template:" -ForegroundColor Gray
Write-Host "  https://login.microsoftonline.com/$($deploymentConfig.TenantDomain)/oauth2/v2.0/authorize?" -ForegroundColor White
Write-Host "      client_id=$($appInfo.AppId)" -ForegroundColor Gray
Write-Host "      redirect_uri=$([System.Uri]::EscapeDataString($deploymentConfig.AppUri))" -ForegroundColor Gray
Write-Host "      response_type=code" -ForegroundColor Gray
Write-Host "      scope=openid profile email" -ForegroundColor Gray
Write-Host "      user_flow=B2C_SignUpSignIn" -ForegroundColor Gray

Write-Host ""
Write-Host ""

# Step 5: Branding
if (-not $deploymentConfig.SkipBranding) {
    Write-Host "[5/5] Configuring Branding..." -ForegroundColor Yellow

    if (-not $DryRun) {
        . "$PSScriptRoot\Set-CIAMBranding.ps1"

        $bannerText = if ($deploymentConfig.BannerText) { $deploymentConfig.BannerText } else { $deploymentConfig.AppName }

        Set-CIAMB -BannText $bannerText `
            -BtnColor $deploymentConfig.PrimaryColor `
            -BgColor $deploymentConfig.BackgroundColor `
            -Logo $deploymentConfig.LogoPath `
            -BgImage $deploymentConfig.BackgroundImagePath `
            -BgLayout "FullScreenCentered"

        Write-Host "  Branding configured" -ForegroundColor Green
    }
}
else {
    Write-Host "[5/5] Skipping Branding..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Summary
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  Application: $($deploymentConfig.AppName)" -ForegroundColor White
Write-Host "  App ID: $($appInfo.AppId)" -ForegroundColor White
Write-Host "  Tenant: $($deploymentConfig.TenantDomain)" -ForegroundColor White
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Create a User Flow in Azure Portal:" -ForegroundColor Yellow
Write-Host "     External Identities > User flows > New user flow" -ForegroundColor Gray
Write-Host "  2. Add your application to the User Flow" -ForegroundColor Gray
Write-Host "  3. Test the sign-up/sign-in experience" -ForegroundColor Gray
Write-Host "  4. Configure API permissions (if needed)" -ForegroundColor Gray
Write-Host "  5. Review and customize branding" -ForegroundColor Gray
Write-Host ""

# Export configuration for reference
$deploymentConfig | ConvertTo-Json -Depth 5

<#
.SYNOPSIS
    Generates a sample configuration file.
#>
function New-CIAMConfigTemplate {
    param(
        [string]$OutputPath = "ciam-config.json"
    )

    $template = @{
        TenantDomain = "contosocustomers.onmicrosoft.com"
        AppName = "Customer Portal"
        AppUri = "http://localhost:3000"
        EnableGoogle = $false
        GoogleClientId = ""
        GoogleClientSecret = ""
        EnableFacebook = $false
        FacebookAppId = ""
        FacebookAppSecret = ""
        EnableEmailOTP = $true
        BannerText = "Customer Portal"
        PrimaryColor = "#0078D4"
        BackgroundColor = "#F2F2F2"
        LogoPath = ""
        BackgroundImagePath = ""
    }

    $template | ConvertTo-Json -Depth 5 | Out-File $OutputPath -Encoding utf8
    Write-Host "Configuration template created: $OutputPath" -ForegroundColor Green
}

Export-ModuleMember -Function @('New-CIAMConfigTemplate')
