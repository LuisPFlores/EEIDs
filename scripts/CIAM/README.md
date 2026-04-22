# CIAM PowerShell Scripts

PowerShell scripts for deploying and managing Microsoft Entra External ID (CIAM) environments.

## Prerequisites

1. **Microsoft Graph PowerShell SDK**
   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser
   ```

2. **Azure AD Preview Module** (for tenant creation)
   ```powershell
   Install-Module AzureADPreview -Scope CurrentUser
   ```

3. **Required Permissions**
   - Application.ReadWrite.All
   - Directory.ReadWrite.All
   - IdentityProvider.ReadWrite.All
   - Policy.ReadWrite.B2CConfiguration
   - BrandReadWrite.All
   - User.ReadWrite.All

## Quick Start

### 1. Connect to Tenant

```powershell
# Interactive login
.\Connect-EntraCIAM.ps1

# Or with application permissions
$env:AZURE_CLIENT_ID = "your-client-id"
$env:AZURE_CLIENT_SECRET = "your-client-secret"
.\Connect-EntraCIAM.ps1 -TenantId "tenant-id" -UseAppOnly
```

### 2. Full Deployment

```powershell
# Basic deployment
.\Deploy-CIAMFull.ps1 `
    -TenantDomain "contosocustomers.onmicrosoft.com" `
    -AppName "Customer Portal" `
    -AppUri "http://localhost:3000"

# With Google federation
.\Deploy-CIAMFull.ps1 `
    -TenantDomain "contosocustomers.onmicrosoft.com" `
    -AppName "Customer Portal" `
    -AppUri "http://localhost:3000" `
    -EnableGoogle `
    -GoogleClientId "xxx" `
    -GoogleClientSecret "yyy"

# Using config file
.\Deploy-CIAMFull.ps1 -ConfigFile "ciam-config.json"
```

## Scripts Overview

| Script | Purpose |
|--------|---------|
| `Connect-EntraCIAM.ps1` | Connect to Microsoft Graph |
| `New-CIAMTenant.ps1` | Create external (CIAM) tenant |
| `Set-CIAMIdentityProviders.ps1` | Configure IdPs (Email, Google, Facebook, SAML, OIDC) |
| `New-CIAMUserFlow.ps1` | Create sign-up/sign-in user flows |
| `Register-CIAMApp.ps1` | Register and configure applications |
| `Set-CIAMBranding.ps1` | Configure sign-in page branding |
| `Deploy-CIAMFull.ps1` | Orchestrate full CIAM deployment |

## Usage Examples

### Configure Identity Providers

```powershell
# Email OTP only
.\Set-CIAMIdentityProviders.ps1 -EnableEmailOTP $true

# With Google
.\Set-CIAMIdentityProviders.ps1 `
    -EnableEmailOTP $true `
    -GoogleClientId "your-google-client-id" `
    -GoogleClientSecret "your-google-client-secret"
```

### Register Application

```powershell
.\Register-CIAMApp.ps1 `
    -DisplayName "My Customer App" `
    -RedirectUris @("http://localhost:3000", "https://myapp.com") `
    -ApplicationType "SPA" `
    -SignInAudience "AzureADMultipleOrgs"
```

### Configure Branding

```powershell
.\Set-CIAMBranding.ps1 `
    -BannerText "Contoso Customers" `
    -ButtonColor "#0078D4" `
    -BackgroundColor "#FFFFFF" `
    -LogoPath "./logo.png" `
    -BackgroundImagePath "./background.jpg"
```

## Configuration File

Create a JSON configuration file:

```json
{
    "TenantDomain": "contosocustomers.onmicrosoft.com",
    "AppName": "Customer Portal",
    "AppUri": "http://localhost:3000",
    "EnableGoogle": true,
    "GoogleClientId": "your-client-id",
    "GoogleClientSecret": "your-client-secret",
    "EnableFacebook": false,
    "EnableEmailOTP": true,
    "BannerText": "Customer Portal",
    "PrimaryColor": "#0078D4",
    "BackgroundColor": "#F2F2F2"
}
```

## Troubleshooting

### Module not found
```powershell
Install-Module Microsoft.Graph -AllowClobber -Scope CurrentUser
```

### Permission denied
Ensure you have the required admin roles:
- Global Administrator
- External Identity Administrator
- Application Administrator

### User flow creation fails
User flows for external tenants are managed via Azure Portal:
1. Go to External Identities > User flows
2. Create new user flow
3. Add your application

## Notes

- Some operations require Azure Portal (tenant creation, user flow UI)
- Microsoft Graph API has rate limits - add delays in scripts if needed
- External tenant creation requires Azure subscription
