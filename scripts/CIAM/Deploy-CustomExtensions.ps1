<#
.SYNOPSIS
    Deploys Custom Authentication Extensions (OnAttributeCollectionSubmit) for Entra External ID.

.DESCRIPTION
    This script deploys Azure Functions for two scenarios:
    1. Certificate (.cer) file upload validation
    2. CAPTCHA (Google reCAPTCHA) validation

    It creates the necessary Azure resources, deploys the functions, and registers
    them as Custom Authentication Extensions in Entra External ID.

.PARAMETER ResourceGroupName
    Name of the Azure resource group (created if it doesn't exist).

.PARAMETER Location
    Azure region for deployment (default: eastus).

.PARAMETER FunctionAppNamePrefix
    Prefix for the Function App names (default: func-eeid).

.PARAMETER StorageAccountName
    Name for the storage account (auto-generated if not provided).

.PARAMETER RecaptchaSecret
    Google reCAPTCHA secret key (required for CAPTCHA scenario).

.PARAMETER Scenario
    Which scenario to deploy: 'CertValidation', 'CaptchaValidation', or 'Both' (default: Both).

.EXAMPLE
    .\Deploy-CustomExtensions.ps1 -ResourceGroupName "rg-eeid-extensions" -RecaptchaSecret "6Lc..."

.EXAMPLE
    .\Deploy-CustomExtensions.ps1 -Scenario CertValidation -ResourceGroupName "rg-eeid-poc"

.NOTES
    Prerequisites:
    - Azure CLI installed and authenticated (az login)
    - Azure Functions Core Tools v4 (npm install -g azure-functions-core-tools@4)
    - .NET 8 SDK (for certificate validation function)
    - Node.js 18+ (for CAPTCHA validation function)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",

    [Parameter(Mandatory = $false)]
    [string]$FunctionAppNamePrefix = "func-eeid",

    [Parameter(Mandatory = $false)]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $false)]
    [string]$RecaptchaSecret,

    [Parameter(Mandatory = $false)]
    [ValidateSet("CertValidation", "CaptchaValidation", "Both")]
    [string]$Scenario = "Both"
)

$ErrorActionPreference = "Stop"
$env:AZURE_CORE_ONLY_SHOW_ERRORS = "true"

# ─────────────────────────────────────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────────────────────────────────────

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
# Validation
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Validating prerequisites"

# Check Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed. Install from https://aka.ms/installazurecli"
}

# Check Azure Functions Core Tools
if (-not (Get-Command func -ErrorAction SilentlyContinue)) {
    throw "Azure Functions Core Tools not found. Install with: npm install -g azure-functions-core-tools@4"
}

# Check scenarios
if ($Scenario -in @("CaptchaValidation", "Both") -and [string]::IsNullOrWhiteSpace($RecaptchaSecret)) {
    throw "RecaptchaSecret parameter is required for CAPTCHA validation scenario."
}

# Verify Azure login
$account = az account show 2>&1 | ConvertFrom-Json
if (-not $account) {
    throw "Not logged into Azure CLI. Run 'az login' first."
}
Write-Success "Azure CLI authenticated as: $($account.user.name)"

# ─────────────────────────────────────────────────────────────────────────────
# Generate names
# ─────────────────────────────────────────────────────────────────────────────

$timestamp = Get-Date -Format "yyyyMMddHHmm"
if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
    # Storage account names: lowercase, no hyphens, max 24 chars
    $StorageAccountName = ("steeid" + $timestamp).Substring(0, [Math]::Min(24, ("steeid" + $timestamp).Length))
}

$certFunctionAppName = "$FunctionAppNamePrefix-cert-$timestamp"
$captchaFunctionAppName = "$FunctionAppNamePrefix-captcha-$timestamp"

Write-Info "Resource Group: $ResourceGroupName"
Write-Info "Location: $Location"
Write-Info "Storage Account: $StorageAccountName"

# ─────────────────────────────────────────────────────────────────────────────
# Create Azure Resources
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Creating Azure resources"

# Resource Group
az group create --name $ResourceGroupName --location $Location --output none
Write-Success "Resource group '$ResourceGroupName' ready"

# Storage Account
az storage account create `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --sku Standard_LRS `
    --output none
Write-Success "Storage account '$StorageAccountName' created"

# ─────────────────────────────────────────────────────────────────────────────
# Deploy Certificate Validation Function
# ─────────────────────────────────────────────────────────────────────────────

if ($Scenario -in @("CertValidation", "Both")) {
    Write-Step "Deploying Certificate Validation Function"

    # Create Function App (.NET 8 isolated)
    az functionapp create `
        --resource-group $ResourceGroupName `
        --consumption-plan-location $Location `
        --runtime dotnet-isolated `
        --runtime-version 8 `
        --functions-version 4 `
        --name $certFunctionAppName `
        --storage-account $StorageAccountName `
        --output none
    Write-Success "Function App '$certFunctionAppName' created"
    Write-Info "Waiting for Function App to become available..."
    Start-Sleep -Seconds 30

    # Build and deploy
    $certPath = Join-Path $PSScriptRoot "..\..\custom-extensions\cert-validation"
    Push-Location $certPath
    try {
        Write-Info "Building .NET project..."
        dotnet publish -c Release -o ./publish
        if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed" }
        Push-Location ./publish
        func azure functionapp publish $certFunctionAppName --dotnet-isolated
        if ($LASTEXITCODE -ne 0) { throw "Function publish failed" }
        Pop-Location
        Remove-Item -Recurse -Force ./publish -ErrorAction SilentlyContinue
    }
    finally {
        Pop-Location
    }
    Write-Success "Certificate validation function deployed"

    # Get function URL
    $certFuncUrl = az functionapp function show `
        --resource-group $ResourceGroupName `
        --name $certFunctionAppName `
        --function-name ValidateCertUpload `
        --query "invokeUrlTemplate" -o tsv 2>$null

    if ($certFuncUrl) {
        Write-Info "Endpoint: $certFuncUrl"
    } else {
        Write-Info "Endpoint: https://$certFunctionAppName.azurewebsites.net/api/ValidateCertUpload"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Deploy CAPTCHA Validation Function
# ─────────────────────────────────────────────────────────────────────────────

if ($Scenario -in @("CaptchaValidation", "Both")) {
    Write-Step "Deploying CAPTCHA Validation Function"

    # Create Function App (Node.js 18)
    az functionapp create `
        --resource-group $ResourceGroupName `
        --consumption-plan-location $Location `
        --runtime node `
        --runtime-version 22 `
        --functions-version 4 `
        --name $captchaFunctionAppName `
        --storage-account $StorageAccountName `
        --output none
    Write-Success "Function App '$captchaFunctionAppName' created"
    Write-Info "Waiting for Function App to become available..."
    Start-Sleep -Seconds 30

    # Set reCAPTCHA secret
    az functionapp config appsettings set `
        --name $captchaFunctionAppName `
        --resource-group $ResourceGroupName `
        --settings "RECAPTCHA_SECRET=$RecaptchaSecret" "RECAPTCHA_SCORE_THRESHOLD=0.5" `
        --output none
    Write-Success "reCAPTCHA secret configured"

    # Deploy
    $captchaPath = Join-Path $PSScriptRoot "..\..\custom-extensions\captcha-validation"
    Push-Location $captchaPath
    try {
        Write-Info "Installing npm dependencies..."
        npm install --omit=dev
        if ($LASTEXITCODE -ne 0) { throw "npm install failed" }
        func azure functionapp publish $captchaFunctionAppName --javascript
        if ($LASTEXITCODE -ne 0) { throw "Function publish failed" }
    }
    finally {
        Pop-Location
    }
    Write-Success "CAPTCHA validation function deployed"

    # Get function URL
    $captchaFuncUrl = az functionapp function show `
        --resource-group $ResourceGroupName `
        --name $captchaFunctionAppName `
        --function-name ValidateCaptcha `
        --query "invokeUrlTemplate" -o tsv 2>$null

    if ($captchaFuncUrl) {
        Write-Info "Endpoint: $captchaFuncUrl"
    } else {
        Write-Info "Endpoint: https://$captchaFunctionAppName.azurewebsites.net/api/ValidateCaptcha"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary & Next Steps
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Deployment Complete!"

Write-Host "`nNEXT STEPS - Register in Entra Admin Center:" -ForegroundColor Magenta
Write-Host ""
Write-Host "  1. Go to: https://entra.microsoft.com" -ForegroundColor White
Write-Host "  2. Navigate to: External Identities -> Custom authentication extensions" -ForegroundColor White
Write-Host "  3. Click: + Create a custom extension" -ForegroundColor White
Write-Host "  4. Select event: OnAttributeCollectionSubmit" -ForegroundColor White
Write-Host "  5. Configure endpoint URL (from above)" -ForegroundColor White
Write-Host "  6. Set authentication (configure app registration)" -ForegroundColor White
Write-Host "  7. Assign to your User Flow:" -ForegroundColor White
Write-Host "     - User flows -> [Your Flow] -> Attribute collection -> Custom extensions" -ForegroundColor White
Write-Host ""

if ($Scenario -in @("CertValidation", "Both")) {
    Write-Host "  CERT VALIDATION:" -ForegroundColor Yellow
    Write-Host "     - Add custom attribute 'CertificateData' (String) to your user flow"
    Write-Host "     - Your custom UI must Base64-encode the .cer file before submission"
    Write-Host "     - Function App: $certFunctionAppName"
    Write-Host ""
}

if ($Scenario -in @("CaptchaValidation", "Both")) {
    Write-Host "  CAPTCHA VALIDATION:" -ForegroundColor Yellow
    Write-Host "     - Add custom attribute 'CaptchaToken' (String, hidden) to your user flow"
    Write-Host "     - Add reCAPTCHA widget to your custom sign-up page"
    Write-Host "     - Inject token into the CaptchaToken attribute on form submit"
    Write-Host "     - Function App: $captchaFunctionAppName"
    Write-Host ""
}

Write-Host "  Full documentation: docs/custom-authentication-extensions.md" -ForegroundColor Gray
Write-Host ""
