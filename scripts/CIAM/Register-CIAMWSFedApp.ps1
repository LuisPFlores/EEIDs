<#
.SYNOPSIS
    Register and configure WS-Federation for Entra CIAM (legacy AD FS integration).

.DESCRIPTION
    Creates an enterprise application configured for WS-Federation.
    Primarily used for on-premises Active Directory Federation Services (AD FS) integration.

.PARAMETER DisplayName
    Name of the enterprise application (e.g., "AD FS Partner", "On-Prem IdP").

.PARAMETER Realm
    WS-Federation Realm identifier (e.g., "https://login.microsoftonline.com/tenant-id/").

.PARAMETER PassiveEndpoint
    Passive Requester Endpoint from AD FS (e.g., "https://adfs.example.com/adfs/ls/").

.PARAMETER MetadataUrl
    (Optional) Federation metadata URL for automatic certificate renewal.

.EXAMPLE
    .\Register-CIAMWSFedApp.ps1 `
        -DisplayName "AD FS Partner" `
        -Realm "https://login.microsoftonline.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/" `
        -PassiveEndpoint "https://adfs.example.com/adfs/ls/"

.EXAMPLE
    .\Register-CIAMWSFedApp.ps1 `
        -DisplayName "On-Prem IdP" `
        -Realm "https://login.microsoftonline.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/" `
        -PassiveEndpoint "https://idp.internal.com/adfs/ls/" `
        -MetadataUrl "https://idp.internal.com/federationmetadata/2007-06/federationmetadata.xml"

.NOTES
    Requires: Microsoft.Graph PowerShell SDK
    Scopes needed: Application.ReadWrite.All, Directory.ReadWrite.All
    
    WS-Federation is a legacy protocol. Use SAML 2.0 or OIDC for new implementations.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $true)]
    [string]$Realm,

    [Parameter(Mandatory = $true)]
    [string]$PassiveEndpoint,

    [Parameter(Mandatory = $false)]
    [string]$MetadataUrl
)

# Ensure we're connected to Microsoft Graph
$context = Get-MgContext
if (-not $context) {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Registering WS-Federation Enterprise Application" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "⚠️  NOTE: WS-Federation is a legacy protocol." -ForegroundColor Yellow
Write-Host "   Prefer SAML 2.0 or OAuth 2.0 for new implementations.`n" -ForegroundColor Yellow

# Create enterprise application
Write-Host "📝 Creating enterprise application: $DisplayName" -ForegroundColor White

try {
    $sp = New-MgServicePrincipal -DisplayName $DisplayName -AccountEnabled $true
    Write-Host "✅ Enterprise application created: $($sp.Id)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to create enterprise application: $_" -ForegroundColor Red
    exit 1
}

# Configuration summary
Write-Host "`n📋 CONFIGURATION SUMMARY" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$config = @{
    "Enterprise App ID" = $sp.Id
    "Display Name" = $sp.DisplayName
    "Realm (Service Provider ID)" = $Realm
    "Passive Sign-In Endpoint" = $PassiveEndpoint
    "Metadata URI" = if ($MetadataUrl) { $MetadataUrl } else { "$($PassiveEndpoint.TrimEnd('/')) /metadata" }
    "Sign-Out URL" = "$($PassiveEndpoint.TrimEnd('/'))/?wa=wsignout1.0"
}

$config.GetEnumerator() | ForEach-Object {
    Write-Host ("  " + $_.Key.PadRight(40)) -ForegroundColor White -NoNewline
    Write-Host $_.Value -ForegroundColor Cyan
}

# Azure Portal steps
Write-Host "`n📋 AZURE PORTAL CONFIGURATION STEPS:" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor White

$portalSteps = @(
    "1. Go to Azure Portal > Enterprise Applications",
    "2. Search for: '$DisplayName'",
    "3. Click 'Single sign-on' (left menu)",
    "4. Select 'WS-Federation' (or 'SAML' if WS-Federation is grouped with it)",
    "5. In 'Basic WS-Federation Configuration', set:",
    "   • Identifier (Realm): $Realm",
    "   • Reply URL: https://{tenant-id}.ciamlogin.com/login.srf",
    "   • Sign-On URL: $PassiveEndpoint",
    ""
    if ($MetadataUrl) {
        @(
            "6. WS-Federation Metadata:",
            "   • Paste metadata URL: $MetadataUrl",
            "   • Or upload metadata file directly",
            ""
        )
    } else {
        @(
            "6. Manually upload certificate from AD FS (if no metadata URL)",
            ""
        )
    }
    "7. Download certificate from Azure Portal",
    "8. Provide certificate to AD FS administrator",
    ""
)

$portalSteps | Where-Object { $_ } | ForEach-Object { Write-Host $_ }

# AD FS Configuration Steps
Write-Host "🔗 AD FS CONFIGURATION STEPS (On AD FS Server):" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor White

$adfSteps = @(
    "Execute on AD FS server (PowerShell as Administrator):",
    ""
    "# 1. Add Relying Party Trust",
    "`$metadata = 'https://{tenant-id}.ciamlogin.com/federationmetadata/2007-06/federationmetadata.xml'",
    "Add-ADFSRelyingPartyTrust ``",
    "    -Name 'Entra CIAM' ``",
    "    -MonitoringEnabled `$true ``",
    "    -MetadataURL `$metadata",
    ""
    "# 2. Configure Claim Rules",
    "`$ruleGroup = 'c1:[Type == ""http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress""]",
    "    => issue(Type = ""http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"", ",
    "    Issuer = c1.Issuer, OriginalIssuer = c1.OriginalIssuer, Value = c1.Value, ValueType = c1.ValueType);'",
    ""
    "Add-ADFSClaimRuleGroup ``",
    "    -TargetRelyingPartyName 'Entra CIAM' ``",
    "    -ClaimRuleName 'Email Claim' ``",
    "    -RuleGroup `$ruleGroup",
    ""
)

$adfSteps | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

# Next steps
Write-Host "`n⏭️  NEXT STEPS:" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor White

$nextSteps = @(
    "1. Configure in Azure Portal (steps above)",
    "2. Configure Relying Party Trust in AD FS (steps above)",
    "3. Add to your user flows:",
    "   • Go to External Identities > User flows",
    "   • Select your sign-up/sign-in flow",
    "   • Add this WS-Federation provider",
    "",
    "4. Test WS-Federation:",
    "   • Initiate sign-in from your app",
    "   • User redirected to AD FS",
    "   • Verify token exchange succeeds",
    "",
    "5. Manage certificates:",
    "   • Monitor expiration in Azure Portal",
    "   • Set up auto-renewal if metadata URL provided",
    "   • Or manually renew before expiration",
    ""
)

$nextSteps | ForEach-Object { Write-Host $_ }

Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "  https://learn.microsoft.com/en-us/windows-server/identity/ad-fs/overview/ad-fs-overview" -ForegroundColor Gray
Write-Host "  https://learn.microsoft.com/en-us/entra/external-id/direct-federation" -ForegroundColor Gray

Write-Host "`n⚠️  IMPORTANT NOTES:" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════`n" -ForegroundColor White

Write-Host "• Time synchronization: Ensure AD FS server time is synchronized with Azure (NTP)" -ForegroundColor Yellow
Write-Host "• Certificate renewal: Use metadata URL for automatic renewal when possible" -ForegroundColor Yellow
Write-Host "• Legacy protocol: WS-Federation is deprecated. Plan migration to OIDC/SAML" -ForegroundColor Yellow
Write-Host "• Testing: Use AD FS test endpoint before production rollout" -ForegroundColor Yellow

Write-Host "`n========================================`n" -ForegroundColor Cyan
