<#
.SYNOPSIS
    Registers an App Registration for Custom Authentication Extensions in Entra External ID.

.DESCRIPTION
    This script creates and configures an App Registration required for
    OnAttributeCollectionSubmit custom authentication extensions. It:
    1. Creates an app registration (or updates an existing one)
    2. Sets the Identifier URI (api://{appId})
    3. Adds the CustomAuthenticationExtension.Receive.Payload permission
    4. Creates a service principal
    5. Grants admin consent

.PARAMETER DisplayName
    Display name for the app registration (default: "Custom Auth Extension API").

.PARAMETER FunctionAppName
    Name of the deployed Azure Function App to configure authentication for.

.PARAMETER ResourceGroupName
    Resource group containing the Function App.

.EXAMPLE
    .\Register-CustomExtensionApp.ps1 -FunctionAppName "func-eeid-cert-202605061502"

.EXAMPLE
    .\Register-CustomExtensionApp.ps1 -DisplayName "Cert Validation Extension" -FunctionAppName "func-eeid-cert-202605061502" -ResourceGroupName "rg-eeid-extensions"

.NOTES
    Prerequisites:
    - Azure CLI installed and authenticated (az login)
    - Sufficient permissions to create app registrations in Entra
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DisplayName = "Custom Auth Extension API",

    [Parameter(Mandatory = $false)]
    [string]$FunctionAppName,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName
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
# Validate prerequisites
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Validating prerequisites"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is not installed."
}

$account = az account show 2>&1 | ConvertFrom-Json
if (-not $account) {
    throw "Not logged into Azure CLI. Run 'az login' first."
}
Write-Success "Authenticated as: $($account.user.name)"

$tenantId = $account.tenantId
Write-Info "Tenant ID: $tenantId"

# ─────────────────────────────────────────────────────────────────────────────
# Create App Registration
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Creating App Registration: $DisplayName"

# Create the app registration
$appJson = az ad app create `
    --display-name $DisplayName `
    --sign-in-audience "AzureADMyOrg" `
    --output json | ConvertFrom-Json

$appId = $appJson.appId
$objectId = $appJson.id

Write-Success "App Registration created"
Write-Info "Application (client) ID: $appId"
Write-Info "Object ID: $objectId"

# ─────────────────────────────────────────────────────────────────────────────
# Set Identifier URI
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Configuring Identifier URI"

$identifierUri = "api://$appId"
az ad app update --id $appId --identifier-uris $identifierUri
Write-Success "Identifier URI set to: $identifierUri"

# ─────────────────────────────────────────────────────────────────────────────
# Add API Permission: CustomAuthenticationExtension.Receive.Payload
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Configuring API permissions"

# Microsoft Graph App ID
$graphAppId = "00000003-0000-0000-c000-000000000000"

# CustomAuthenticationExtensions.Receive.Payload permission ID
# This is the well-known ID for this permission
$customExtPermissionId = "214e810f-fda8-4fd7-a475-29461495eb00"

az ad app permission add `
    --id $appId `
    --api $graphAppId `
    --api-permissions "$customExtPermissionId=Role"

Write-Success "Added CustomAuthenticationExtensions.Receive.Payload permission"

# ─────────────────────────────────────────────────────────────────────────────
# Create Service Principal
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Creating Service Principal"

$spJson = az ad sp create --id $appId --output json 2>$null | ConvertFrom-Json
if ($spJson) {
    Write-Success "Service Principal created"
} else {
    # SP might already exist
    $spJson = az ad sp show --id $appId --output json | ConvertFrom-Json
    Write-Success "Service Principal already exists"
}
Write-Info "Service Principal Object ID: $($spJson.id)"

# ─────────────────────────────────────────────────────────────────────────────
# Grant Admin Consent
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Granting admin consent"

# Wait a moment for propagation
Start-Sleep -Seconds 5

az ad app permission admin-consent --id $appId
Write-Success "Admin consent granted"

# ─────────────────────────────────────────────────────────────────────────────
# Configure Function App Authentication (optional)
# ─────────────────────────────────────────────────────────────────────────────

if ($FunctionAppName -and $ResourceGroupName) {
    Write-Step "Configuring Function App authentication"

    az webapp auth update `
        --name $FunctionAppName `
        --resource-group $ResourceGroupName `
        --enabled true `
        --action LoginWithAzureActiveDirectory `
        --aad-allowed-token-audiences $identifierUri `
        --aad-client-id $appId `
        --aad-token-issuer-url "https://login.microsoftonline.com/$tenantId/v2.0"

    Write-Success "Function App '$FunctionAppName' authentication configured"
}

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────

Write-Step "Registration Complete!"

Write-Host ""
Write-Host "  Use these values when configuring the Custom Authentication Extension:" -ForegroundColor White
Write-Host ""
Write-Host "  Application (client) ID:  $appId" -ForegroundColor Green
Write-Host "  Identifier URI:           $identifierUri" -ForegroundColor Green
Write-Host "  Tenant ID:                $tenantId" -ForegroundColor Green
Write-Host ""
Write-Host "  In Entra Admin Center:" -ForegroundColor White
Write-Host "  1. Go to: External Identities -> Custom authentication extensions" -ForegroundColor White
Write-Host "  2. Create extension -> select OnAttributeCollectionSubmit" -ForegroundColor White
Write-Host "  3. For 'App registration', select: $DisplayName" -ForegroundColor White
Write-Host "  4. The Target URL is your Azure Function endpoint" -ForegroundColor White
Write-Host ""

if (-not $FunctionAppName) {
    Write-Host "  TIP: Re-run with -FunctionAppName and -ResourceGroupName to also" -ForegroundColor Gray
    Write-Host "       configure Function App authentication automatically." -ForegroundColor Gray
    Write-Host ""
}
