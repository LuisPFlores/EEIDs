<#
.SYNOPSIS
    Register a new OIDC application in Entra CIAM for customer authentication.

.DESCRIPTION
    Creates an app registration in External (CIAM) tenant configured for OAuth 2.0 / OpenID Connect.
    Automatically creates client secret and configures API permissions.

.PARAMETER DisplayName
    Display name for the application (e.g., "Customer Portal").

.PARAMETER RedirectUri
    Redirect URI for OAuth response (e.g., "https://app.contoso.com/auth/redirect").

.PARAMETER TenantId
    CIAM tenant ID. If not provided, uses current connected tenant.

.PARAMETER SecretExpireMonths
    Certificate/secret expiration period in months (default: 24).

.EXAMPLE
    .\Register-CIAMOIDCApp.ps1 `
        -DisplayName "Customer Portal" `
        -RedirectUri "https://app.contoso.com/auth/redirect"

.EXAMPLE
    .\Register-CIAMOIDCApp.ps1 `
        -DisplayName "Customer Portal" `
        -RedirectUri "https://localhost:3000/auth/redirect" `
        -SecretExpireMonths 12

.NOTES
    Requires: Microsoft.Graph PowerShell SDK
    Scopes needed: Application.ReadWrite.All
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $true)]
    [string]$RedirectUri,

    [Parameter(Mandatory = $false)]
    [string]$TenantId,

    [Parameter(Mandatory = $false)]
    [int]$SecretExpireMonths = 24
)

# Ensure we're connected to Microsoft Graph
$context = Get-MgContext
if (-not $context) {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    if ($TenantId) {
        Connect-MgGraph -Scopes "Application.ReadWrite.All" -TenantId $TenantId
    }
    else {
        Connect-MgGraph -Scopes "Application.ReadWrite.All"
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Registering OIDC Application" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Create app registration
Write-Host "📝 Creating app registration: $DisplayName" -ForegroundColor White

try {
    $app = New-MgApplication -DisplayName $DisplayName `
        -Web @{
            RedirectUris = @($RedirectUri)
            LogoutUrl = $RedirectUri.Replace("/auth/redirect", "/").Replace("/auth/oidc/redirect", "/")
        }
    
    Write-Host "✅ Application registered with ID: $($app.Id)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to create application: $_" -ForegroundColor Red
    exit 1
}

# Create service principal
Write-Host "🔐 Creating service principal..." -ForegroundColor White

try {
    $sp = New-MgServicePrincipal -AppId $app.AppId
    Write-Host "✅ Service principal created: $($sp.Id)" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Service principal creation failed (may already exist): $_" -ForegroundColor Yellow
}

# Create client secret
Write-Host "🔑 Creating client secret..." -ForegroundColor White

try {
    $secretParams = @{
        DisplayName = "Web app secret (OIDC)"
        EndDateTime = (Get-Date).AddMonths($SecretExpireMonths)
    }
    $secret = Add-MgApplicationPassword -ApplicationId $app.Id @secretParams
    
    Write-Host "✅ Client secret created" -ForegroundColor Green
    Write-Host "`n⚠️  IMPORTANT: Copy your client secret NOW (shown only once):" -ForegroundColor Yellow
    Write-Host "═════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host $secret.SecretText -ForegroundColor Yellow
    Write-Host "═════════════════════════════════════════════════════════`n" -ForegroundColor Yellow
}
catch {
    Write-Host "❌ Failed to create client secret: $_" -ForegroundColor Red
}

# Get current tenant
$currentTenant = Get-MgOrganization | Select-Object -ExpandProperty Id

# Build configuration output
Write-Host "📋 CONFIGURATION SUMMARY" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$config = @{
    "Application ID (Client ID)" = $app.AppId
    "Application Object ID" = $app.Id
    "Tenant ID" = $currentTenant
    "Redirect URI" = $RedirectUri
    "OIDC Metadata URL" = "https://$currentTenant.ciamlogin.com/$currentTenant/v2.0/.well-known/openid-configuration"
    "Token Endpoint" = "https://$currentTenant.ciamlogin.com/$currentTenant/oauth2/v2.0/token"
    "Authorization Endpoint" = "https://$currentTenant.ciamlogin.com/$currentTenant/oauth2/v2.0/authorize"
}

$config.GetEnumerator() | ForEach-Object {
    Write-Host ("  " + $_.Key.PadRight(30)) -ForegroundColor White -NoNewline
    Write-Host $_.Value -ForegroundColor Cyan
}

# .env template
Write-Host "`n📄 .ENV TEMPLATE (for your application):" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor White

$envTemplate = @"
# Entra CIAM - OAuth 2.0 / OpenID Connect Configuration
TENANT_ID=$currentTenant
CLIENT_ID=$($app.AppId)
CLIENT_SECRET=$(if ($secret) { '(paste from above)' } else { '(create in Azure Portal)' })
REDIRECT_URI=$RedirectUri

# Application settings
NODE_ENV=development
PORT=3000
SESSION_SECRET=your-session-secret-here
"@

Write-Host $envTemplate -ForegroundColor White

# Next steps
Write-Host "`n⏭️  NEXT STEPS:" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor White

$steps = @(
    "1. Copy the configuration values above to your .env file",
    "2. (Optional) Verify app in Azure Portal: portal.azure.com",
    "3. Identify your app registration in External tenant",
    "4. Add additional redirect URIs if needed (Settings > Authentication)",
    "5. For production, add HTTPS redirect URIs",
    "6. Add to user flows (External Identities > User flows > Identity providers)",
    "7. Test sign-in with your application",
    ""
)

$steps | ForEach-Object { Write-Host $_ }

Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "  https://learn.microsoft.com/en-us/entra/external-id/customers/concept-authentication-methods-customers" -ForegroundColor Gray
Write-Host "  https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols-oidc" -ForegroundColor Gray

Write-Host "`n========================================`n" -ForegroundColor Cyan
