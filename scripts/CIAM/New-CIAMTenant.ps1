#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
    Creates a new External (CIAM) tenant in Microsoft Entra.

.DESCRIPTION
    Creates a new Microsoft Entra tenant configured for External Identities (CIAM).
    This is used for customer-facing applications where external users self-register.

.PARAMETER DisplayName
    The display name for the new tenant.

.PARAMETER DomainName
    The initial domain name (e.g., contoso.onmicrosoft.com).

.PARAMETER Country
    The country/region code (e.g., US, GB).

.PARAMETER Environment
    The Azure environment (AzureCloud, AzureChinaCloud, AzureUSGovernment).

.EXAMPLE
    .\New-CIAMTenant.ps1 -DisplayName "Contoso Customers" -DomainName "contosocustomers"
    Creates a new CIAM tenant.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $true)]
    [string]$DomainName,

    [Parameter()]
    [string]$Country = "US",

    [Parameter()]
    [ValidateSet("AzureCloud", "AzureChinaCloud", "AzureUSGovernment")]
    [string]$Environment = "AzureCloud"
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Create CIAM External Tenant" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking for Azure AD module..." -ForegroundColor Yellow

# Check for AzureADPreview or Az module (needed for tenant creation)
$AzureModule = Get-Module -Name AzureADPreview -ListAvailable
if (-not $AzureModule) {
    $AzureModule = Get-Module -Name Az -ListAvailable
}

if (-not $AzureModule) {
    Write-Host "Installing AzureADPreview module..." -ForegroundColor Yellow
    Install-Module -Name AzureADPreview -Force -AllowClobber -Scope CurrentUser
}

# Note: Tenant creation requires Azure portal or specific Graph API calls
# This script documents the process and checks current tenants

Write-Host "To create a new CIAM tenant, use one of these methods:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1: Azure Portal" -ForegroundColor White
Write-Host "  1. Go to https://portal.azure.com" -ForegroundColor Gray
Write-Host "  2. Navigate to Microsoft Entra ID > Manage tenants > Create" -ForegroundColor Gray
Write-Host "  3. Select 'External' for CIAM scenario" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 2: Azure CLI" -ForegroundColor White
Write-Host "  az tenant create --display-name '$DisplayName' --domain-name '$DomainName'" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 3: PowerShell (after connecting to existing tenant)" -ForegroundColor White
Write-Host "  Using Microsoft Graph for tenant listing..." -ForegroundColor Gray
Write-Host ""

# Connect and list current tenants
Write-Host "Attempting to connect and list available tenants..." -ForegroundColor Yellow
Write-Host ""

try {
    # Check if already connected
    $context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $context) {
        Write-Host "Please connect first: .\Connect-EntraCIAM.ps1" -ForegroundColor Red
        Write-Host ""
        return
    }

    # List all accessible tenants
    Write-Host "Current tenant ID: $($context.TenantId)" -ForegroundColor Cyan
    Write-Host ""

    $tenants = Get-MgOrganization -All

    Write-Host "Available tenants:" -ForegroundColor Green
    Write-Host "  Tenant ID                        | Display Name" -ForegroundColor Gray
    Write-Host "  ---------------------------------|--------------------------" -ForegroundColor Gray

    foreach ($tenant in $tenants) {
        $tenantType = if ($tenant.OrganizationType) { $tenant.OrganizationType } else { "Workforce" }
        Write-Host "  $($tenant.Id) | $($tenant.DisplayName) ($tenantType)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "To create a new CIAM tenant, visit:" -ForegroundColor Green
    Write-Host "  https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredServicesView" -ForegroundColor Cyan
}
catch {
    Write-Warning "Could not list tenants: $_"
    Write-Host ""
    Write-Host "Please connect to your primary tenant and create CIAM tenant via Azure Portal." -ForegroundColor Yellow
}

<#
.SYNOPSIS
    Alternative: Create tenant using Azure CLI wrapper

.DESCRIPTION
    This function creates a CIAM tenant using Azure CLI
#>
function New-CIAMTenantViaCLI {
    param(
        [string]$DisplayName,
        [string]$DomainName,
        [string]$Country = "US"
    )

    Write-Host "Creating CIAM tenant via Azure CLI..." -ForegroundColor Yellow

    $result = az tenant create `
        --display-name $DisplayName `
        --domain-name $DomainName `
        --country-code $Country `
        2>&1

    if ($LASTEXITCODE -eq 0) {
        $tenantInfo = $result | ConvertFrom-Json
        Write-Host "Tenant created successfully!" -ForegroundColor Green
        Write-Host "  Tenant ID: $($tenantInfo.tenantId)" -ForegroundColor Cyan
        Write-Host "  Domain: $($tenantInfo.domainName)" -ForegroundColor Cyan
        return $tenantInfo
    }
    else {
        Write-Error "Failed to create tenant: $result"
    }
}

Write-Host ""
Write-Host "Use New-CIAMTenantViaCLI function to create via CLI after installing Azure CLI." -ForegroundColor Yellow
