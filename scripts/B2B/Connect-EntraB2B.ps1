#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
    Connects to Microsoft Graph for B2B Collaboration operations.

.DESCRIPTION
    Establishes connection to Microsoft Graph with the required scopes for B2B collaboration management.

.PARAMETER TenantId
    The tenant ID to connect to. If not specified, will use the default tenant.

.PARAMETER UseAppOnly
    Use application permissions instead of delegated permissions.

.EXAMPLE
    .\Connect-EntraB2B.ps1
    Connects using interactive delegated authentication.

.EXAMPLE
    .\Connect-EntraB2B.ps1 -TenantId "your-tenant-id" -UseAppOnly
    Connects using application permissions.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TenantId,

    [Parameter()]
    [switch]$UseAppOnly
)

$ErrorActionPreference = "Stop"

$RequiredScopes = @(
    "User.ReadWrite.All",
    "Application.ReadWrite.All",
    "Directory.ReadWrite.All",
    "Directory.AccessAsUser.All",
    "Policy.ReadWrite.ConditionalAccess",
    "IdentityProvider.ReadWrite.All",
    "Group.ReadWrite.All",
    "PartnerLeader.Read.All"
)

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Entra B2B Collaboration Connect" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

try {
    if ($UseAppOnly) {
        if (-not $TenantId) {
            Write-Error "TenantId is required when using Application permissions."
            return
        }
        Write-Host "Connecting with Application permissions to: $TenantId" -ForegroundColor Yellow

        $params = @{
            ClientId     = $env:AZURE_CLIENT_ID
            ClientSecret = $env:AZURE_CLIENT_SECRET
            TenantId     = $TenantId
        }

        if ($env:AZURE_CERTIFICATE_THUMBPRINT) {
            $params.CertificateThumbprint = $env:AZURE_CERTIFICATE_THUMBPRINT
        }

        Connect-MgGraph @params -Scopes $RequiredScopes | Out-Null
    }
    else {
        Write-Host "Connecting with Delegated permissions..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes $RequiredScopes
    }

    $context = Get-MgContext
    Write-Host ""
    Write-Host "Connected successfully!" -ForegroundColor Green
    Write-Host "  Tenant: $($context.TenantId)" -ForegroundColor Gray
    
    # Get tenant details
    try {
        $tenant = Get-MgOrganization -OrganizationId $context.TenantId
        Write-Host "  Display Name: $($tenant.DisplayName)" -ForegroundColor Gray
    }
    catch {
        Write-Host "  (Could not retrieve tenant details)" -ForegroundColor Gray
    }
    
    Write-Host "  Account: $($context.Account)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Error "Failed to connect: $_"
    throw
}
