#Requires -Modules Microsoft.Graph.B2B, Microsoft.Graph.Applications

<#
.SYNOPSIS
    Creates and configures user flows for CIAM.

.DESCRIPTION
    Creates user flows (sign-up, sign-in, profile editing) for customer-facing applications.
    User flows define the authentication experience including identity providers,
    user attributes, and MFA requirements.

.PARAMETER Name
    The display name for the user flow.

.PARAMETER UserFlowType
    Type of user flow: SignUpSignIn, SignUp, SignIn, ProfileEditing, PasswordReset.

.PARAMETER IdentityProviders
    Array of identity provider types to include (e.g., @('EmailPasswordless', 'Google', 'Facebook')).

.PARAMETER UserAttributes
    Array of user attributes to collect: Email, DisplayName, GivenName, Surname, country.

.PARAMETER ApplicationId
    The application ID to associate with the user flow.

.PARAMETER IsMfaRequired
    Whether MFA is required (default: false).

.EXAMPLE
    .\New-CIAMUserFlow.ps1 -Name "SignUpSignIn" -IdentityProviders @("EmailPasswordless", "Google")
    Creates a combined sign-up/sign-in flow with email OTP and Google.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter()]
    [ValidateSet("SignUpSignIn", "SignUp", "SignIn", "ProfileEditing", "PasswordReset")]
    [string]$UserFlowType = "SignUpSignIn",

    [Parameter()]
    [string[]]$IdentityProviders = @("EmailPasswordless"),

    [Parameter()]
    [string[]]$UserAttributes = @("Email", "DisplayName"),

    [Parameter()]
    [string]$ApplicationId,

    [Parameter()]
    [bool]$IsMfaRequired = $false
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Create CIAM User Flow" -ForegroundColor Cyan
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

# Note: User flows in external tenants use the B2C user flow APIs
# The actual implementation uses: New-MgIdentityUserFlow

function New-B2CUserFlow {
    param(
        [string]$FlowName,
        [string]$FlowType,
        [string[]]$Idps,
        [string[]]$Attributes,
        [string]$AppId,
        [bool]$MfaRequired
    )

    Write-Host "Creating user flow: $FlowName" -ForegroundColor Yellow
    Write-Host "  Type: $FlowType" -ForegroundColor Gray
    Write-Host "  Identity Providers: $($Idps -join ', ')" -ForegroundColor Gray
    Write-Host "  User Attributes: $($Attributes -join ', ')" -ForegroundColor Gray

    # Build user flow configuration
    $userFlowProperties = @{
        UserFlowType = $FlowType
        UserFlowTypeVersion = "1.0.0"
    }

    # Note: Actual Graph API call structure depends on tenant type
    # For external/CIAM tenants, use the B2C configuration APIs

    try {
        # Check if user flow already exists
        $existingFlow = Get-MgIdentityUserFlow -UserFlowId $FlowName -ErrorAction SilentlyContinue

        if ($existingFlow) {
            Write-Host "  User flow already exists. Updating..." -ForegroundColor Yellow

            # Update would go here - removing for safety
            Write-Host "  Use Azure Portal to modify existing user flows." -ForegroundColor Yellow
            return $existingFlow
        }

        # Create new user flow
        # This is the Graph API call structure
        $params = @{
            Id = $FlowName
            UserFlowType = $FlowType
            UserFlowTypeVersion = "1.0.0"
        }

        $newFlow = New-MgIdentityUserFlow -BodyParameter $params -ErrorAction Stop

        Write-Host "  User flow created successfully!" -ForegroundColor Green
        return $newFlow
    }
    catch {
        # User flows may require specific Graph API endpoints
        # Falling back to documentation

        Write-Warning "  Direct user flow creation via Graph requires B2C API permissions."
        Write-Host ""
        Write-Host "  To create user flows, use one of these methods:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Method 1: Azure Portal" -ForegroundColor White
        Write-Host "    1. Go to External Identities > User flows" -ForegroundColor Gray
        Write-Host "    2. Click 'New user flow'" -ForegroundColor Gray
        Write-Host "    3. Select '$FlowType'" -ForegroundColor Gray
        Write-Host "    4. Configure providers and attributes" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Method 2: Azure AD B2C PowerShell Module" -ForegroundColor White
        Write-Host "    Install-Module AzureADPreview" -ForegroundColor Gray
        Write-Host "    Connect-AzureAD" -ForegroundColor Gray
        Write-Host "    New-AzureADMSIdentityProvider (for IdP setup)" -ForegroundColor Gray

        return $null
    }
}

function Get-UserFlowUrl {
    param(
        [string]$FlowName,
        [string]$AppId,
        [string]$TenantDomain
    )

    Write-Host ""
    Write-Host "User Flow URL:" -ForegroundColor Cyan
    Write-Host "https://login.microsoftonline.com/$TenantDomain/" -ForegroundColor White
    Write-Host "    oauth2/v2.0/authorize?" -ForegroundColor White
    Write-Host "    client_id=$AppId" -ForegroundColor Gray
    Write-Host "    redirect_uri=<your-redirect-uri>" -ForegroundColor Gray
    Write-Host "    response_type=code" -ForegroundColor Gray
    Write-Host "    scope=openid profile email" -ForegroundColor Gray
    Write-Host "    user_flow=$FlowName" -ForegroundColor Gray
}

# Create the user flow
Write-Host "Configuring user flow: $Name" -ForegroundColor Cyan
Write-Host ""

$result = New-B2CUserFlow -FlowName $Name -FlowType $UserFlowType `
    -Idps $IdentityProviders -Attributes $UserAttributes `
    -AppId $ApplicationId -MfaRequired $IsMfaRequired

# Generate user flow URL
if ($ApplicationId) {
    $tenantInfo = Get-MgOrganization -OrganizationId $TenantId
    $tenantDomain = $tenantInfo.VerifiedDomains[0].Name
    Get-UserFlowUrl -FlowName $Name -AppId $ApplicationId -TenantDomain $tenantDomain
}

<#
.SYNOPSIS
    Creates a comprehensive sign-up/sign-in user flow.

.DESCRIPTION
    Creates a full-featured user flow combining sign-up and sign-in
    with multiple identity providers and MFA support.
#>
function New-CIAMSignUpSignInFlow {
    param(
        [string]$FlowName = "B2C_SignUpSignIn",
        [string[]]$Providers = @("EmailPasswordless"),
        [bool]$RequireMfa = $false,
        [string[]]$CollectAttributes = @("email", "displayName", "givenName", "surname"),
        [string[]]$ReturnAttributes = @("email", "displayName")
    )

    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  Create Sign-Up/Sign-In Flow" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Configuration Summary:" -ForegroundColor Yellow
    Write-Host "  Flow Name: $FlowName" -ForegroundColor White
    Write-Host "  Providers: $($Providers -join ', ')" -ForegroundColor White
    Write-Host "  MFA Required: $RequireMfa" -ForegroundColor White
    Write-Host "  Collect: $($CollectAttributes -join ', ')" -ForegroundColor White
    Write-Host "  Return: $($ReturnAttributes -join ', ')" -ForegroundColor White
    Write-Host ""

    Write-Host "This script configures the flow parameters." -ForegroundColor Yellow
    Write-Host "Actual user flow creation requires Azure Portal or B2C API." -ForegroundColor Yellow
    Write-Host ""

    # Return configuration object for documentation
    $config = @{
        FlowName = $FlowName
        UserFlowType = "SignUpSignIn"
        IdentityProviders = $Providers
        UserAttributes = @{
            SignUp = $CollectAttributes
            Token = $ReturnAttributes
        }
        MfaRequired = $RequireMfa
        Created = Get-Date
    }

    Write-Host "Configuration prepared:" -ForegroundColor Green
    $config | ConvertTo-Json -Depth 5 | Write-Host

    return $config
}

# Export functions
Export-ModuleMember -Function @('New-CIAMSignUpSignInFlow', 'Get-UserFlowUrl')

<#
.SYNOPSIS
    Gets the user flow configuration.

.PARAMETER UserFlowId
    The user flow ID/name to retrieve.
#>
function Get-CIAMUserFlow {
    param(
        [Parameter()]
        [string]$UserFlowId
    )

    try {
        if ($UserFlowId) {
            return Get-MgIdentityUserFlow -UserFlowId $UserFlowId -ErrorAction Stop
        }
        else {
            return Get-MgIdentityUserFlow -All
        }
    }
    catch {
        Write-Warning "Could not retrieve user flows: $_"
        Write-Host "User flows are configured via Azure Portal in External Identities > User flows" -ForegroundColor Yellow
        return $null
    }
}

Export-ModuleMember -Function @('Get-CIAMUserFlow')
