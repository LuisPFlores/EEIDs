<#
.SYNOPSIS
    Register and configure a SAML 2.0 enterprise application for Entra CIAM.

.DESCRIPTION
    Creates an enterprise application (service principal) configured for SAML 2.0 federation.
    Can accept metadata URL or configure manually for IdPs like Okta, PingFederate, JumpCloud.

.PARAMETER DisplayName
    Name of the enterprise application (e.g., "Okta Partner", "PingFederate").

.PARAMETER MetadataUrl
    (Optional) SAML metadata URL from your IdP.

.PARAMETER Issuer
    (Optional) IdP issuer URI for manual configuration.

.PARAMETER SignOnUrl
    (Optional) IdP single sign-on URL.

.EXAMPLE
    .\Register-CIAMSAMLApp.ps1 -DisplayName "Okta Partner" -MetadataUrl "https://contoso.okta.com/app/exk.../sso/saml/metadata"

.EXAMPLE
    .\Register-CIAMSAMLApp.ps1 -DisplayName "PingFederate" -Issuer "https://pingfed.example.com" -SignOnUrl "https://pingfed.example.com/idp/SSO.saml2"

.NOTES
    Requires: Microsoft.Graph PowerShell SDK
    Scopes needed: Application.ReadWrite.All, Directory.ReadWrite.All
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $false)]
    [string]$MetadataUrl,

    [Parameter(Mandatory = $false)]
    [string]$Issuer,

    [Parameter(Mandatory = $false)]
    [string]$SignOnUrl
)

# Ensure we're connected to Microsoft Graph
$context = Get-MgContext
if (-not $context) {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Registering SAML 2.0 Enterprise Application" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Get current tenant
$tenant = Get-MgOrganization | Select-Object -ExpandProperty Id

# Create enterprise application (service principal)
Write-Host "📝 Creating enterprise application: $DisplayName" -ForegroundColor White

try {
    $sp = New-MgServicePrincipal -DisplayName $DisplayName -AccountEnabled $true
    Write-Host "✅ Enterprise application created: $($sp.Id)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to create enterprise application: $_" -ForegroundColor Red
    exit 1
}

# Download or note metadata if provided
if ($MetadataUrl) {
    Write-Host "📥 Metadata URL provided: $MetadataUrl" -ForegroundColor White
    Write-Host "   (Upload this in Azure Portal > Enterprise Applications > SAML)" -ForegroundColor Gray
}

# Configuration summary
Write-Host "`n📋 CONFIGURATION SUMMARY" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$config = @{
    "Enterprise App ID" = $sp.Id
    "Display Name" = $sp.DisplayName
    "Tenant ID" = $tenant
    "Assertion Consumer Service (ACS) URL" = "https://$tenant.ciamlogin.com/login.srf"
    "Entity ID (Service Provider)" = "https://login.microsoftonline.com/$tenant/"
    "Sign-Out URL" = "https://$tenant.ciamlogin.com/logout.srf"
}

if ($MetadataUrl) {
    $config["IdP Metadata URL"] = $MetadataUrl
}
if ($Issuer) {
    $config["IdP Issuer"] = $Issuer
}
if ($SignOnUrl) {
    $config["IdP Single Sign-On URL"] = $SignOnUrl
}

$config.GetEnumerator() | ForEach-Object {
    Write-Host ("  " + $_.Key.PadRight(40)) -ForegroundColor White -NoNewline
    Write-Host $_.Value -ForegroundColor Cyan
}

# SAML Configuration Steps
Write-Host "`n📋 AZURE PORTAL CONFIGURATION STEPS:" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor White

$portalSteps = @(
    "1. Go to Azure Portal > Enterprise Applications",
    "2. Search for: '$DisplayName'",
    "3. Click 'Single sign-on' (left menu)",
    "4. Select 'SAML' authentication method",
    "5. In 'Basic SAML Configuration', set:",
    "   • Identifier (Entity ID): https://login.microsoftonline.com/$tenant/",
    "   • Reply URL (ACS): https://$tenant.ciamlogin.com/login.srf",
    ""
    "6. If metadata available:",
    "   • Click 'Upload metadata file'",
    "   • Select IdP metadata XML",
    "   "
    "7. Or configure manually:",
    "   • Paste IdP Issuer and Sign-On URL",
    ""
    "8. In 'Attributes & Claims':",
    "   • Ensure 'email' is mapped to user attribute",
    "   • Set Unique User Identifier (Name ID) to 'user.mail'",
    ""
    "9. Download certificate and provide to IdP admin",
    "10. Test in 'Test single sign-on' section",
    ""
)

$portalSteps | ForEach-Object { Write-Host $_ }

# Provider-specific examples
Write-Host "🔗 PROVIDER-SPECIFIC GUIDANCE:" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor White

$providers = @(
    @{
        name = "Okta"
        steps = @(
            "• Create SAML app in Okta",
            "• Set Single sign-on URL: https://$tenant.ciamlogin.com/login.srf",
            "• Set Audience URI: https://login.microsoftonline.com/$tenant/",
            "• Download metadata from Okta",
            "• Upload to this enterprise app in Azure"
        )
    },
    @{
        name = "PingFederate"
        steps = @(
            "• Create Service Provider in PingFederate",
            "• Import Entra metadata URL",
            "• Configure attribute mappings",
            "• Download PingFederate metadata",
            "• Upload to this enterprise app in Azure"
        )
    },
    @{
        name = "JumpCloud"
        steps = @(
            "• Create SAML app in JumpCloud",
            "• Set SAML Protocol: https://$tenant.ciamlogin.com/login.srf",
            "• Entity ID: https://login.microsoftonline.com/$tenant/",
            "• Download JumpCloud SAML metadata",
            "• Upload to this enterprise app in Azure"
        )
    }
)

$providers | ForEach-Object {
    Write-Host "$($_.name):" -ForegroundColor White
    $_.steps | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ""
}

# Next steps
Write-Host "`n⏭️  NEXT STEPS:" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor White

$nextSteps = @(
    "1. Configure in Azure Portal (steps above)",
    "2. Add to your user flows:",
    "   • Go to External Identities > User flows",
    "   • Select your sign-up/sign-in flow",
    "   • Add this SAML provider",
    "",
    "3. Test SAML SSO:",
    "   • Click 'Test' in Azure Portal",
    "   • Complete SAML authentication flow",
    "",
    "4. Monitor:",
    "   • View sign-ins in Azure Portal",
    "   • Check certificate expiration",
    "   • Set up alerts for failures",
    ""
)

$nextSteps | ForEach-Object { Write-Host $_ }

Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "  https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-register-saml-app" -ForegroundColor Gray
Write-Host "  https://learn.microsoft.com/en-us/entra/external-id/direct-federation" -ForegroundColor Gray

Write-Host "`n========================================`n" -ForegroundColor Cyan
