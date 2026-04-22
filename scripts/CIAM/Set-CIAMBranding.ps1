#Requires -Modules Microsoft.Graph.Organization

<#
.SYNOPSIS
    Configures company branding for CIAM tenant.

.DESCRIPTION
    Configures the sign-in page branding including:
    - Company logo
    - Background image
    - Banner text
    - Color scheme
    - Footer links

.PARAMETER BannerText
    Text displayed in the banner area.

.PARAMETER SignInPageText
    Text displayed on the sign-in page.

.PARAMETER LogoPath
    Path to company logo image (PNG/JPG, max 36x245px).

.PARAMETER BackgroundImagePath
    Path to background image (must be JPG/PNG, max 1920x1080px).

.PARAMETER SquareLogoPath
    Path to square logo (50x50px).

.PARAMETER SquareLogoDarkPath
    Path to dark square logo for dark mode.

.PARAMETER HeaderForegroundColor
    Hex color code for header text (e.g., "#FFFFFF").

.PARAMETER ButtonColor
    Hex color code for button background.

.PARAMETER BackgroundColor
    Hex color code for page background.

.PARAMETER ForegroundColor
    Hex color code for text color.

.PARAMETER BackgroundLayout
    Background image layout: FullScreenCentered, FullScreen, Center, None.

.PARAMETER Localize
    Apply branding to specific locale (e.g., "en-US").

.EXAMPLE
    .\Set-CIAMBranding.ps1 -BannerText "Contoso Customer Portal" -ButtonColor "#0078D4"
    Configures basic branding with custom colors.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$BannerText,

    [Parameter()]
    [string]$SignInPageText,

    [Parameter()]
    [string]$LogoPath,

    [Parameter()]
    [string]$BackgroundImagePath,

    [Parameter()]
    [string]$SquareLogoPath,

    [Parameter()]
    [string]$SquareLogoDarkPath,

    [Parameter()]
    [string]$HeaderForegroundColor,

    [Parameter()]
    [string]$ButtonColor,

    [Parameter()]
    [string]$BackgroundColor,

    [Parameter()]
    [string]$ForegroundColor,

    [Parameter()]
    [ValidateSet("FullScreenCentered", "FullScreen", "Center", "None")]
    [string]$BackgroundLayout = "FullScreenCentered",

    [Parameter()]
    [string]$Localize
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Configure CIAM Branding" -ForegroundColor Cyan
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

function Test-ImageFile {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path $Path)) {
        return $false
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLower()
    if ($extension -notin @('.png', '.jpg', '.jpeg')) {
        Write-Warning "Image must be PNG or JPG: $Path"
        return $false
    }

    return $true
}

function Set-CIAMB {
    param(
        [string]$Locale = "default",
        [string]$BannText,
        [string]$SignInTxt,
        [string]$Logo,
        [string]$BgImage,
        [string]$SqLogo,
        [string]$SqLogoDark,
        [string]$HdrFgColor,
        [string]$BtnColor,
        [string]$BgColor,
        [string]$FgColor,
        [string]$BgLayout
    )

    Write-Host "Configuring branding for locale: $Locale" -ForegroundColor Yellow

    $params = @{}

    if ($BannText) { $params.BannerText = $BannText }
    if ($SignInTxt) { $params.SignInPageText = $SignInTxt }
    if ($Logo -and (Test-ImageFile $Logo)) {
        $params.Logo = [System.IO.File]::ReadAllBytes($Logo)
    }
    if ($BgImage -and (Test-ImageFile $BgImage)) {
        $params.BackgroundImage = [System.IO.File]::ReadAllBytes($BgImage)
    }
    if ($SqLogo -and (Test-ImageFile $SqLogo)) {
        $params.SquareLogo = [System.IO.File]::ReadAllBytes($SqLogo)
    }
    if ($SqLogoDark -and (Test-ImageFile $SqLogoDark)) {
        $params.SquareLogoDark = [System.IO.File]::ReadAllBytes($SqLogoDark)
    }

    if ($HdrFgColor) { $params.HeaderForegroundColor = $HdrFgColor }
    if ($BtnColor) { $params.ButtonAuthenticationClientID = $BtnColor }
    if ($BgColor) { $params.BackgroundColor = $BgColor }
    if ($FgColor) { $params.ForegroundColor = $FgColor }
    if ($BgLayout) { $params.BackgroundLayout = $BgLayout }

    if ($params.Count -le 0) {
        Write-Host "No branding parameters specified" -ForegroundColor Yellow
        return
    }

    try {
        # Check if branding exists
        $existingBranding = Get-MgOrganizationBranding -OrganizationId $TenantId -ErrorAction SilentlyContinue

        if ($existingBranding) {
            Write-Host "Updating existing branding..." -ForegroundColor Yellow
            Update-MgOrganizationBranding -OrganizationId $TenantId -BodyParameter $params -ErrorAction Stop
        }
        else {
            Write-Host "Creating new branding..." -ForegroundColor Yellow
            Set-MgOrganizationBranding -OrganizationId $TenantId -BodyParameter $params -ErrorAction Stop
        }

        Write-Host "Branding configured successfully!" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to configure branding: $_"
    }
}

function Set-CIAMBLocalization {
    param(
        [string]$Locale,
        [string]$BannText,
        [string]$SignInTxt,
        [string]$Logo,
        [string]$BgImage
    )

    Write-Host "Configuring localization: $Locale" -ForegroundColor Yellow

    $params = @{}

    if ($BannText) { $params.BannerText = $BannText }
    if ($SignInTxt) { $params.SignInPageText = $SignInTxt }
    if ($Logo -and (Test-ImageFile $Logo)) {
        $params.Logo = [System.IO.File]::ReadAllBytes($Logo)
    }
    if ($BgImage -and (Test-ImageFile $BgImage)) {
        $params.BackgroundImage = [System.IO.File]::ReadAllBytes($BgImage)
    }

    try {
        Set-MgOrganizationBrandingLocalization `
            -OrganizationId $TenantId `
            -LocalizeBrandingID $Locale `
            -BodyParameter $params -ErrorAction Stop

        Write-Host "Localization '$Locale' configured!" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to configure localization: $_"
    }
}

# Apply branding
if ($LogoPath -or $BackgroundImagePath -or $BannerText -or $ButtonColor) {
    Set-CIAMB -Locale "default" `
        -BannText $BannerText `
        -SignInTxt $SignInPageText `
        -Logo $LogoPath `
        -BgImage $BackgroundImagePath `
        -SqLogo $SquareLogoPath `
        -SqLogoDark $SquareLogoDarkPath `
        -HdrFgColor $HeaderForegroundColor `
        -BtnColor $ButtonColor `
        -BgColor $BackgroundColor `
        -FgColor $ForegroundColor `
        -BgLayout $BackgroundLayout
}

# Apply localization if specified
if ($Localize) {
    Set-CIAMBLocalization -Locale $Localize `
        -BannText $BannerText `
        -SignInTxt $SignInPageText `
        -Logo $LogoPath `
        -BgImage $BackgroundImagePath
}

# Display current branding
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Current Branding Status" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

try {
    $branding = Get-MgOrganizationBranding -OrganizationId $TenantId -ErrorAction SilentlyContinue

    if ($branding) {
        Write-Host ""
        Write-Host "Branding configured:" -ForegroundColor Green
        Write-Host "  Banner Text: $($branding.BannerText)" -ForegroundColor White
        Write-Host "  Sign-in Page Text: $($branding.SignInPageText)" -ForegroundColor White
        Write-Host "  Header Foreground: $($branding.HeaderForegroundColor)" -ForegroundColor White
        Write-Host "  Background Color: $($branding.BackgroundColor)" -ForegroundColor White
        Write-Host "  Foreground Color: $($branding.ForegroundColor)" -ForegroundColor White
        Write-Host "  Background Layout: $($branding.BackgroundLayout)" -ForegroundColor White

        $localizations = Get-MgOrganizationBrandingLocalization -OrganizationId $TenantId -All -ErrorAction SilentlyContinue
        if ($localizations) {
            Write-Host ""
            Write-Host "Localizations: $($localizations.Count)" -ForegroundColor Cyan
            $localizations | ForEach-Object { Write-Host "  - $($_.ID)" -ForegroundColor White }
        }
    }
    else {
        Write-Host "No branding configured yet." -ForegroundColor Yellow
    }
}
catch {
    Write-Warning "Could not retrieve branding: $_"
}

Write-Host ""
Write-Host "Branding Best Practices:" -ForegroundColor Cyan
Write-Host "  - Logo: 36x245px PNG (transparent background recommended)" -ForegroundColor Gray
Write-Host "  - Square Logo: 50x50px PNG" -ForegroundColor Gray
Write-Host "  - Background: 1920x1080px JPG/PNG, max 100KB" -ForegroundColor Gray
Write-Host "  - Use company colors for brand consistency" -ForegroundColor Gray
Write-Host "  - Add privacy statement and help desk links" -ForegroundColor Gray

<#
.SYNOPSIS
    Gets current branding configuration.
#>
function Get-CIAMBranding {
    param(
        [string]$Locale = "default"
    )

    try {
        if ($Locale -eq "default") {
            return Get-MgOrganizationBranding -OrganizationId $TenantId
        }
        else {
            return Get-MgOrganizationBrandingLocalization -OrganizationId $TenantId -LocalizeBrandingID $Locale
        }
    }
    catch {
        Write-Warning "Could not retrieve branding: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Removes branding configuration.
#>
function Remove-CIAMBranding {
    param(
        [string]$Locale = "default"
    )

    try {
        if ($Locale -eq "default") {
            Remove-MgOrganizationBranding -OrganizationId $TenantId -ErrorAction Stop
            Write-Host "Default branding removed" -ForegroundColor Green
        }
        else {
            Remove-MgOrganizationBrandingLocalization -OrganizationId $TenantId -LocalizeBrandingID $Locale -ErrorAction Stop
            Write-Host "Localization '$Locale' branding removed" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to remove branding: $_"
    }
}

Export-ModuleMember -Function @('Get-CIAMBranding', 'Remove-CIAMBranding')
