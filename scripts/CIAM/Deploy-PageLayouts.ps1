<#
.SYNOPSIS
    Deploys custom page layouts to Azure Blob Storage for Entra External ID.

.DESCRIPTION
    Uploads the custom HTML page layout (with reCAPTCHA) to Azure Blob Storage
    and configures CORS so Entra can load it. Outputs the URL to use in
    Entra Admin Center -> User flows -> Page layouts.

.PARAMETER ResourceGroupName
    Resource group name (default: rg-eeid-extensions).

.PARAMETER StorageAccountName
    Storage account name for hosting pages (auto-generated if not provided).

.PARAMETER Location
    Azure region (default: eastus).

.PARAMETER RecaptchaSiteKey
    Your Google reCAPTCHA site key (public key) to inject into the HTML.

.EXAMPLE
    .\Deploy-PageLayouts.ps1 -RecaptchaSiteKey "6Lc_your_site_key"

.EXAMPLE
    .\Deploy-PageLayouts.ps1 -ResourceGroupName "rg-eeid-extensions" -RecaptchaSiteKey "6LcXXXXXXX"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RecaptchaSiteKey,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-eeid-extensions",

    [Parameter(Mandatory = $false)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus"
)

$ErrorActionPreference = "Stop"
$env:AZURE_CORE_ONLY_SHOW_ERRORS = "true"

function Write-Step {
    param([string]$Message)
    Write-Host "`n--- $Message ---" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [i] $Message" -ForegroundColor Yellow
}

# ─────────────────────────────────────────────────────────────────────────────
# Validate
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Validating prerequisites"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed."
}

$account = az account show 2>&1 | ConvertFrom-Json
if (-not $account) { throw "Not logged into Azure CLI. Run 'az login' first." }
Write-Success "Authenticated as: $($account.user.name)"

# ─────────────────────────────────────────────────────────────────────────────
# Setup storage
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Setting up Azure Blob Storage"

if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
    $timestamp = Get-Date -Format "yyyyMMddHHmm"
    $StorageAccountName = ("steeidpages" + $timestamp).Substring(0, [Math]::Min(24, ("steeidpages" + $timestamp).Length))
}

# Create resource group (if needed)
az group create --name $ResourceGroupName --location $Location --output none
Write-Success "Resource group ready"

# Create storage account
az storage account create `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku Standard_LRS `
    --kind StorageV2 `
    --output none
Write-Success "Storage account '$StorageAccountName' created"

# Enable static website hosting (creates $web container)
az storage blob service-properties update `
    --account-name $StorageAccountName `
    --static-website `
    --index-document "index.html" `
    --output none
Write-Success "Static website hosting enabled"

# Configure CORS for Entra
az storage cors add `
    --account-name $StorageAccountName `
    --services b `
    --methods GET OPTIONS `
    --origins "https://login.microsoftonline.com" "https://*.ciamlogin.com" "https://*.b2clogin.com" `
    --allowed-headers "*" `
    --exposed-headers "*" `
    --max-age 3600
Write-Success "CORS configured for Entra domains"

# ─────────────────────────────────────────────────────────────────────────────
# Prepare and upload HTML
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Preparing custom page layout"

$htmlSourcePath = Join-Path $PSScriptRoot "..\..\custom-extensions\page-layouts\signup-captcha.html"

if (-not (Test-Path $htmlSourcePath)) {
    throw "HTML template not found at: $htmlSourcePath"
}

# Read HTML and inject reCAPTCHA site key
$htmlContent = Get-Content $htmlSourcePath -Raw
$htmlContent = $htmlContent -replace "REPLACE_WITH_YOUR_RECAPTCHA_SITE_KEY", $RecaptchaSiteKey

# Write to temp file for upload
$tempFile = Join-Path $env:TEMP "signup-captcha.html"
$htmlContent | Set-Content $tempFile -Encoding UTF8
Write-Success "reCAPTCHA site key injected"

# Upload to $web container
Write-Step "Uploading to Azure Blob Storage"

$containerName = '$web'
az storage blob upload `
    --account-name $StorageAccountName `
    --container-name $containerName `
    --name "signup-captcha.html" `
    --file $tempFile `
    --content-type "text/html" `
    --overwrite `
    --auth-mode login `
    --output none
Write-Success "Page layout uploaded"

# Clean up temp file
Remove-Item $tempFile -Force -ErrorAction SilentlyContinue

# Get the static website URL
$webEndpoint = az storage account show `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --query "primaryEndpoints.web" -o tsv

$pageUrl = "${webEndpoint}signup-captcha.html"

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Deployment Complete!"

Write-Host ""
Write-Host "  Custom page layout URL:" -ForegroundColor White
Write-Host "  $pageUrl" -ForegroundColor Green
Write-Host ""
Write-Host "  Configure in Entra Admin Center:" -ForegroundColor White
Write-Host "  1. Go to: External Identities -> User flows" -ForegroundColor White
Write-Host "  2. Select your sign-up flow" -ForegroundColor White
Write-Host "  3. Go to: Page layouts" -ForegroundColor White
Write-Host "  4. Select 'Sign up page' (or 'Attribute collection page')" -ForegroundColor White
Write-Host "  5. Set 'Use custom page content' to Yes" -ForegroundColor White
Write-Host "  6. Paste the URL above into 'Custom page URI'" -ForegroundColor White
Write-Host "  7. Save" -ForegroundColor White
Write-Host ""
Write-Host "  Storage account: $StorageAccountName" -ForegroundColor Gray
Write-Host "  Container: `$web" -ForegroundColor Gray
Write-Host ""
