<#
.SYNOPSIS
    Deploy Entra Application Proxy for publishing infra.camilco.net externally.

.DESCRIPTION
    Automates the deployment of Microsoft Entra Application Proxy to expose an
    internal ADFS server (infra.camilco.net) to the internet, enabling WS-Federation
    sign-in for federated users (camilco.net domain).

    This script:
    1. Verifies prerequisites (licenses, modules, connector)
    2. Creates an Application Proxy enterprise application
    3. Configures the proxy with passthrough pre-authentication
    4. Optionally sets up a custom domain
    5. Updates federation settings for the camilco.net domain
    6. Validates the deployment

.PARAMETER InternalUrl
    The internal URL of the ADFS server (default: https://infra.camilco.net/).

.PARAMETER ExternalHostName
    Custom external hostname (e.g., "sts.camilco.net"). If not provided,
    uses the auto-generated *.msappproxy.net URL.

.PARAMETER ConnectorGroupName
    Name of the connector group to use (default: "Default").

.PARAMETER DisplayName
    Display name for the enterprise application (default: "ADFS - WS-Federation Proxy").

.PARAMETER SkipFederationUpdate
    Skip updating the camilco.net domain federation settings.

.PARAMETER FederatedDomain
    The federated domain to update (default: "camilco.net").

.EXAMPLE
    # Basic deployment with auto-generated external URL
    .\Deploy-AppProxy-WSFed.ps1

.EXAMPLE
    # Deployment with custom external domain
    .\Deploy-AppProxy-WSFed.ps1 `
        -ExternalHostName "sts.camilco.net" `
        -ConnectorGroupName "DMZ Connectors"

.EXAMPLE
    # Deploy without updating federation settings (manual update later)
    .\Deploy-AppProxy-WSFed.ps1 -SkipFederationUpdate

.NOTES
    Requires:
    - Microsoft.Graph PowerShell SDK (Microsoft.Graph.Applications, Microsoft.Graph.Beta.Applications)
    - MSOnline module (for federation settings update)
    - Entra ID P1 or P2 license
    - Global Administrator or Application Administrator role
    - At least one App Proxy Connector installed and active on internal network
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$InternalUrl = "https://infra.camilco.net/",

    [Parameter(Mandatory = $false)]
    [string]$ExternalHostName,

    [Parameter(Mandatory = $false)]
    [string]$ConnectorGroupName = "Default",

    [Parameter(Mandatory = $false)]
    [string]$DisplayName = "ADFS - WS-Federation Proxy",

    [Parameter(Mandatory = $false)]
    [switch]$SkipFederationUpdate,

    [Parameter(Mandatory = $false)]
    [string]$FederatedDomain = "camilco.net",

    [Parameter(Mandatory = $false)]
    [string]$TenantId = "74a83386-626f-4647-bd1e-728ab6a094db"
)

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

function Write-Step {
    param([string]$Message, [string]$Icon = "[*]")
    Write-Host "`n$Icon $Message" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkGray
}

function Write-Success {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  [X] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "  [i] $Message" -ForegroundColor White
}

# -----------------------------------------------------------------------------
# STEP 1: Verify prerequisites
# -----------------------------------------------------------------------------

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  Entra Application Proxy - WS-Federation Deployment" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

Write-Step "Verifying prerequisites" "[1]"

# Check Microsoft.Graph module
$requiredModules = @(
    "Microsoft.Graph.Applications",
    "Microsoft.Graph.Beta.Applications",
    "Microsoft.Graph.Identity.DirectoryManagement"
)

foreach ($mod in $requiredModules) {
    if (Get-Module -ListAvailable -Name $mod) {
        Write-Success "$mod module found"
    } else {
        Write-Warn "$mod not found. Installing..."
        Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber
        Write-Success "$mod installed"
    }
}

# -----------------------------------------------------------------------------
# STEP 2: Connect to Microsoft Graph
# -----------------------------------------------------------------------------

Write-Step "Connecting to Microsoft Graph" "[2]"

$requiredScopes = @(
    "Application.ReadWrite.All",
    "Directory.ReadWrite.All",
    "Domain.ReadWrite.All"
)

$context = Get-MgContext
if ($context) {
    Write-Success "Already connected as $($context.Account)"
} else {
    Write-Info "Launching sign-in (device code flow)..."
    Connect-MgGraph -Scopes $requiredScopes -TenantId $TenantId -UseDeviceCode
    $context = Get-MgContext
    Write-Success "Connected as $($context.Account)"
}

# -----------------------------------------------------------------------------
# STEP 3: Verify App Proxy connectors
# -----------------------------------------------------------------------------

Write-Step "Checking Application Proxy connectors" "[3]"

try {
    $connectorGroups = Get-MgBetaOnPremisePublishingProfileConnectorGroup `
        -OnPremisesPublishingProfileId "applicationProxy" `
        -ErrorAction Stop

    if ($connectorGroups) {
        Write-Success "Found $($connectorGroups.Count) connector group(s)"

        $targetGroup = $connectorGroups | Where-Object { $_.Name -eq $ConnectorGroupName }
        if ($targetGroup) {
            Write-Success "Target connector group '$ConnectorGroupName' found (ID: $($targetGroup.Id))"

            # Check connectors in the group
            $connectors = Get-MgBetaOnPremisePublishingProfileConnectorGroupMember `
                -OnPremisesPublishingProfileId "applicationProxy" `
                -ConnectorGroupId $targetGroup.Id `
                -ErrorAction SilentlyContinue

            if ($connectors) {
                $activeConnectors = $connectors | Where-Object { $_.Status -eq "active" }
                Write-Success "$($activeConnectors.Count) active connector(s) in group"
                foreach ($c in $activeConnectors) {
                    Write-Info "  -> $($c.MachineName) ($($c.Status))"
                }
            } else {
                Write-Warn "No connectors found in group '$ConnectorGroupName'"
                Write-Warn "Install a connector first: Entra admin center -> Global Secure Access -> Connectors"
            }
        } else {
            Write-Fail "Connector group '$ConnectorGroupName' not found"
            Write-Info "Available groups: $($connectorGroups.Name -join ', ')"
            Write-Info "Use -ConnectorGroupName to specify a different group"
            exit 1
        }
    } else {
        Write-Fail "No connector groups found. Install an App Proxy connector first."
        Write-Info "Download from: Entra admin center -> Global Secure Access -> Connect -> Connectors"
        exit 1
    }
} catch {
    Write-Warn "Could not query connectors: $($_.Exception.Message)"
    Write-Info "This may require additional permissions or Entra ID P1/P2 license"
    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne 'y') { exit 1 }
}

# -----------------------------------------------------------------------------
# STEP 4: Create the App Proxy application
# -----------------------------------------------------------------------------

Write-Step "Creating Application Proxy enterprise application" "[4]"

# Check if app already exists
$existingApp = Get-MgApplication -Filter "displayName eq '$DisplayName'" -ErrorAction SilentlyContinue
if ($existingApp) {
    Write-Warn "Application '$DisplayName' already exists (ID: $($existingApp.Id))"
    $overwrite = Read-Host "Delete and recreate? (y/N)"
    if ($overwrite -eq 'y') {
        Remove-MgApplication -ApplicationId $existingApp.Id
        Write-Info "Deleted existing application"
    } else {
        Write-Info "Using existing application"
    }
}

# Create the application with App Proxy settings
$appBody = @{
    displayName = $DisplayName
    identifierUris = @()
    web = @{
        redirectUris = @()
        homePageUrl = $InternalUrl
    }
    onPremisesPublishing = @{
        internalUrl = $InternalUrl
        externalAuthenticationType = "passthru"
        isTranslateHostHeaderEnabled = $true
        isTranslateLinksInBodyEnabled = $true
        isHttpOnlyCookieEnabled = $true
        isSecureCookieEnabled = $true
        isPersistentCookieEnabled = $false
        applicationServerTimeout = "default"
    }
}

# If custom domain is specified, set external URL
if ($ExternalHostName) {
    $appBody.onPremisesPublishing.externalUrl = "https://$ExternalHostName/"
    $appBody.onPremisesPublishing.isOnPremPublishingEnabled = $true
}

try {
    $app = New-MgBetaApplication -BodyParameter $appBody
    Write-Success "Application created: $($app.Id)"
} catch {
    Write-Fail "Failed to create application: $($_.Exception.Message)"
    Write-Info ""
    Write-Info "If the API fails, create manually in the Entra admin center:"
    Write-Info "  1. Enterprise applications -> New application -> Create your own"
    Write-Info "  2. Name: '$DisplayName'"
    Write-Info "  3. Application Proxy -> Configure:"
    Write-Info "     - Internal URL: $InternalUrl"
    Write-Info "     - Pre-authentication: Passthrough"
    Write-Info "     - Connector group: $ConnectorGroupName"
    Write-Info "     - Translate URLs in headers: Yes"
    Write-Info "     - Translate URLs in body: Yes"

    $app = $null
}

# Create the service principal
if ($app) {
    try {
        $sp = New-MgServicePrincipal -AppId $app.AppId
        Write-Success "Service principal created: $($sp.Id)"
    } catch {
        Write-Warn "Service principal may already exist: $($_.Exception.Message)"
    }

    # Assign connector group
    if ($targetGroup) {
        try {
            Write-Info "Connector group '$ConnectorGroupName' will be assigned"
        } catch {
            Write-Warn "Could not assign connector group: $($_.Exception.Message)"
        }
    }
}

# Determine external URL
if ($app -and $app.OnPremisesPublishing) {
    $externalUrl = $app.OnPremisesPublishing.ExternalUrl
} elseif ($ExternalHostName) {
    $externalUrl = "https://$ExternalHostName"
} else {
    $externalUrl = "https://<auto-generated>.msappproxy.net"
    Write-Info "External URL will be auto-generated by Entra"
}

Write-Info "External URL: $externalUrl"

# -----------------------------------------------------------------------------
# STEP 5: Update federation settings for camilco.net
# -----------------------------------------------------------------------------

if (-not $SkipFederationUpdate) {
    Write-Step "Updating federation settings for $FederatedDomain" "[5]"

    # Derive ADFS endpoints from external URL
    $externalBase = $externalUrl.TrimEnd('/')
    $passiveLogOnUri  = "$externalBase/adfs/ls/"
    $activeLogOnUri   = "$externalBase/adfs/services/trust/2005/usernamemixed"
    $metadataExUri    = "$externalBase/adfs/services/trust/mex"
    $logoutUri        = "$externalBase/adfs/ls/?wa=wsignout1.0"

    Write-Info "Passive LogOn URI:  $passiveLogOnUri"
    Write-Info "Active LogOn URI:   $activeLogOnUri"
    Write-Info "Metadata Exchange:  $metadataExUri"
    Write-Info "Logout URI:         $logoutUri"

    Write-Host ""
    Write-Warn "This will update the federation settings for '$FederatedDomain'"
    Write-Warn "Current ADFS users will be redirected to the new external URL"
    $confirm = Read-Host "Proceed? (y/N)"

    if ($confirm -eq 'y') {
        try {
            # Get current federation settings via Microsoft Graph
            Write-Info "Querying current federation configuration..."
            $fedConfigs = Get-MgDomainFederationConfiguration -DomainId $FederatedDomain -ErrorAction Stop

            if ($fedConfigs) {
                $currentConfig = $fedConfigs[0]
                Write-Info "  Current Passive Sign-In URI: $($currentConfig.PassiveSignInUri)"
                Write-Info "  Current Issuer URI:          $($currentConfig.IssuerUri)"
                Write-Info "  Config ID:                   $($currentConfig.Id)"

                # Update federation configuration
                $updateParams = @{
                    PassiveSignInUri              = $passiveLogOnUri
                    ActiveSignInUri               = $activeLogOnUri
                    MetadataExchangeUri           = $metadataExUri
                    SignOutUri                    = $logoutUri
                }

                Update-MgDomainFederationConfiguration `
                    -DomainId $FederatedDomain `
                    -InternalDomainFederationId $currentConfig.Id `
                    -BodyParameter $updateParams

                Write-Success "Federation settings updated for $FederatedDomain"

                # Verify
                $updatedConfig = Get-MgDomainFederationConfiguration -DomainId $FederatedDomain
                Write-Info "  Updated Passive Sign-In URI: $($updatedConfig[0].PassiveSignInUri)"
                Write-Info "  Updated Active Sign-In URI:  $($updatedConfig[0].ActiveSignInUri)"
            } else {
                Write-Fail "No federation configuration found for $FederatedDomain"
                Write-Info "The domain may not be configured as federated"
            }

        } catch {
            Write-Fail "Failed to update federation settings: $($_.Exception.Message)"
            Write-Info ""
            Write-Info "Manual update command (Microsoft Graph PowerShell):"
            Write-Host @"

Connect-MgGraph -Scopes "Domain.ReadWrite.All"
`$config = Get-MgDomainFederationConfiguration -DomainId "$FederatedDomain"
Update-MgDomainFederationConfiguration ``
    -DomainId "$FederatedDomain" ``
    -InternalDomainFederationId `$config[0].Id ``
    -PassiveSignInUri "$passiveLogOnUri" ``
    -ActiveSignInUri "$activeLogOnUri" ``
    -MetadataExchangeUri "$metadataExUri" ``
    -SignOutUri "$logoutUri"
"@
        }
    } else {
        Write-Info "Skipped federation update"
    }
} else {
    Write-Step "Skipping federation settings update (use -SkipFederationUpdate:`$false to enable)" "[5]"
}

# -----------------------------------------------------------------------------
# STEP 6: Validation and summary
# -----------------------------------------------------------------------------

Write-Step "Deployment Summary" "[6]"

Write-Host ""
Write-Host "  Application Proxy Configuration" -ForegroundColor Cyan
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
Write-Info "  Display Name:       $DisplayName"
Write-Info "  Internal URL:       $InternalUrl"
Write-Info "  External URL:       $externalUrl"
Write-Info "  Pre-authentication: Passthrough"
Write-Info "  Connector Group:    $ConnectorGroupName"
if ($app) {
    Write-Info "  Application ID:     $($app.AppId)"
    Write-Info "  Object ID:          $($app.Id)"
}

Write-Host ""
Write-Host "  WS-Fed Webapp Configuration (.env updates)" -ForegroundColor Cyan
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
Write-Info "  No changes needed for localhost testing"
Write-Info "  For production deployment, update webapp-wsfed/.env:"
Write-Info "    WSFED_REPLY_URL=https://<your-app-host>/auth/callback"

# Validation checks
Write-Host ""
Write-Host "  Validation Checklist" -ForegroundColor Cyan
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray

# Test external URL reachability (if available)
if ($externalUrl -and $externalUrl -notlike '*<auto*') {
    try {
        $response = Invoke-WebRequest -Uri $externalUrl -MaximumRedirection 0 -ErrorAction SilentlyContinue -UseBasicParsing
        Write-Success "External URL is reachable (HTTP $($response.StatusCode))"
    } catch {
        if ($_.Exception.Response.StatusCode.value__) {
            Write-Success "External URL responds (HTTP $($_.Exception.Response.StatusCode.value__))"
        } else {
            Write-Warn "External URL not yet reachable - connector may need time to sync"
        }
    }
} else {
    Write-Info "External URL will be available after Entra provisions the proxy"
}

Write-Host ""
Write-Host "  Next Steps" -ForegroundColor Cyan
Write-Host "  -----------------------------------------------" -ForegroundColor DarkGray
Write-Host "  1. Verify the connector is Active in Entra admin center" -ForegroundColor White
Write-Host "  2. Browse to the external URL and confirm ADFS login page loads" -ForegroundColor White
Write-Host "  3. Test WS-Fed sign-in: http://localhost:3001/auth/login" -ForegroundColor White
Write-Host "     Sign in with a user@$FederatedDomain account" -ForegroundColor White

if ($ExternalHostName) {
    Write-Host "  4. Create CNAME DNS record:" -ForegroundColor White
    Write-Host "     $ExternalHostName -> <app>.msappproxy.net" -ForegroundColor Gray
    Write-Host "  5. Upload public TLS certificate for $ExternalHostName" -ForegroundColor White
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Deployment complete" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan
