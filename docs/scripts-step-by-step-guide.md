# Entra External Identities - PowerShell Scripts Step-by-Step Guide

This guide provides detailed step-by-step instructions for executing all PowerShell scripts in this repository.

---

# Prerequisites

Before running any scripts, complete these setup steps:

## Step 1: Install Required PowerShell Modules

```powershell
# Open PowerShell as Administrator

# Install Microsoft Graph PowerShell SDK
Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber

# Install Microsoft Teams module (for B2B Direct Connect)
Install-Module MicrosoftTeams -Scope CurrentUser -AllowClobber

# Install Azure AD Preview (for tenant creation)
Install-Module AzureADPreview -Scope CurrentUser -AllowClobber

# Verify installations
Get-Module -ListAvailable Microsoft.Graph, MicrosoftTeams, AzureADPreview
```

## Step 2: Verify Required Permissions

You need one of these admin roles:
- **Global Administrator**
- **External Identity Administrator**
- **User Administrator**
- **Conditional Access Administrator**
- **Teams Administrator**

## Step 3: Choose Your Scenario

| Scenario | Scripts | Page |
|----------|---------|------|
| CIAM (Customer Identity) | 8 scripts | Page 2 |
| B2B Collaboration | 7 scripts | Page 9 |
| B2B Direct Connect | 3 scripts | Page 16 |

---

# SCENARIO 1: CIAM (Customer Identity)

## When to Use CIAM
- Building consumer-facing applications
- Customers self-register to access your app
- Separate identity management from employees

---

## Step 1: Connect-EntraCIAM.ps1

**Purpose**: Connect to Microsoft Graph for CIAM operations

### Steps:

1. Open PowerShell
2. Navigate to scripts folder:
   ```powershell
   cd C:\Users\luflores\OneDrive - Microsoft\07-Git\EEIDs\scripts\CIAM
   ```
3. Run the connection script:
   ```powershell
   .\Connect-EntraCIAM.ps1
   ```
4. A browser window will open - sign in with your admin account
5. Verify connection - you should see:
   - Connected successfully!
   - Tenant ID
   - Account email

**Alternative - Application Permissions (for automation):**
```powershell
$env:AZURE_CLIENT_ID = "your-app-client-id"
$env:AZURE_CLIENT_SECRET = "your-app-secret"
.\Connect-EntraCIAM.ps1 -TenantId "your-tenant-id" -UseAppOnly
```

---

## Step 2: New-CIAMTenant.ps1

**Purpose**: Create a new External (CIAM) tenant

### Steps:

1. Ensure you're connected (Step 1)
2. Run the script:
   ```powershell
   .\New-CIAMTenant.ps1 -DisplayName "Contoso Customers" -DomainName "contosocustomers"
   ```
3. Note: Tenant creation typically requires Azure Portal

**Alternative - Via Azure Portal:**
1. Go to https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/RegisteredServicesView
2. Click "Create"
3. Select "External" for CIAM scenario
4. Follow the wizard

**Alternative - Via Azure CLI:**
```powershell
az login
az tenant create --display-name "Contoso Customers" --domain-name "contosocustomers"
```

---

## Step 3: Set-CIAMIdentityProviders.ps1

**Purpose**: Configure identity providers (Email OTP, Google, Facebook)

### Steps:

1. Connect to your CIAM tenant:
   ```powershell
   .\Connect-EntraCIAM.ps1
   ```

2. **Option A - Email OTP Only:**
   ```powershell
   .\Set-CIAMIdentityProviders.ps1 -EnableEmailOTP $true
   ```

3. **Option B - Email + Google:**
   ```powershell
   .\Set-CIAMIdentityProviders.ps1 `
       -EnableEmailOTP $true `
       -GoogleClientId "your-google-client-id" `
       -GoogleClientSecret "your-google-client-secret"
   ```

4. **Option C - All Providers:**
   ```powershell
   .\Set-CIAMIdentityProviders.ps1 `
       -EnableEmailOTP $true `
       -GoogleClientId "xxx" `
       -GoogleClientSecret "yyy" `
       -FacebookAppId "abc" `
       -FacebookAppSecret "def"
   ```

**Getting Google Credentials:**
1. Go to https://console.cloud.google.com
2. Create a project
3. APIs & Services > Credentials > Create OAuth 2.0
4. Add redirect URI: `https://login.microsoftonline.com/{tenant}/oauth2/authresp`
5. Copy Client ID and Secret

---

## Step 4: New-CIAMUserFlow.ps1

**Purpose**: Create sign-up/sign-in user flows

### Steps:

1. Connect to CIAM tenant:
   ```powershell
   .\Connect-EntraCIAM.ps1
   ```

2. Create a sign-up/sign-in flow:
   ```powershell
   .\New-CIAMUserFlow.ps1 -Name "SignUpSignIn" -UserFlowType "SignUpSignIn"
   ```

3. **Note**: User flow creation UI is in Azure Portal:
   - Go to External Identities > User flows
   - Click "New user flow"
   - Select "Sign up and sign in"
   - Configure providers and attributes

4. Get user flow URL for your app:
   ```powershell
   # After registering your app (Step 5)
   .\New-CIAMUserFlow.ps1
   # Script will display the authorization URL
   ```

---

## Step 5: Register-CIAMApp.ps1

**Purpose**: Register applications for customer access

### Steps:

1. Connect to CIAM tenant:
   ```powershell
   .\Connect-EntraCIAM.ps1
   ```

2. **Option A - Basic SPA:**
   ```powershell
   .\Register-CIAMApp.ps1 `
       -DisplayName "Customer Portal" `
       -RedirectUris @("http://localhost:3000") `
       -ApplicationType "SPA"
   ```

3. **Option B - Web App:**
   ```powershell
   .\Register-CIAMApp.ps1 `
       -DisplayName "Customer Web App" `
       -RedirectUris @("https://myapp.com/signin-oidc") `
       -ApplicationType "Web" `
       -SignInAudience "AzureADMultipleOrgs"
   ```

4. **Option C - With API Permissions:**
   ```powershell
   .\Register-CIAMApp.ps1 `
       -DisplayName "My App" `
       -RedirectUris @("http://localhost:3000") `
       -ApplicationType "SPA" `
       -RequiredResourceAccess @("User.Read", "User.ReadBasic.All")
   ```

5. Note the output:
   - App ID (Client ID)
   - Tenant Domain
   - Authorization URLs

---

## Step 6: Set-CIAMBranding.ps1

**Purpose**: Customize sign-in page with company branding

### Steps:

1. Connect to CIAM tenant:
   ```powershell
   .\Connect-EntraCIAM.ps1
   ```

2. **Option A - Basic Colors:**
   ```powershell
   .\Set-CIAMBranding.ps1 `
       -BannerText "Contoso Customer Portal" `
       -ButtonColor "#0078D4" `
       -BackgroundColor "#F2F2F2"
   ```

3. **Option B - With Logo:**
   ```powershell
   .\Set-CIAMBranding.ps1 `
       -BannerText "My Company" `
       -ButtonColor "#0078D4" `
       -LogoPath "C:\images\logo.png" `
       -BackgroundImagePath "C:\images\background.jpg"
   ```

4. **Option C - Full Branding:**
   ```powershell
   .\Set-CIAMBranding.ps1 `
       -BannerText "Contoso" `
       -SignInPageText "Sign in to your account" `
       -ButtonColor "#0078D4" `
       -BackgroundColor "#FFFFFF" `
       -ForegroundColor "#000000" `
       -HeaderForegroundColor "#FFFFFF" `
       -LogoPath ".\logo.png" `
       -BackgroundImagePath ".\background.jpg" `
       -BackgroundLayout "FullScreenCentered"
   ```

**Image Requirements:**
- Logo: 36x245px PNG (transparent background)
- Square Logo: 50x50px PNG
- Background: 1920x1080px JPG/PNG, max 100KB

---

## Step 7: Deploy-CIAMFull.ps1

**Purpose**: Orchestrate complete CIAM deployment

### Steps:

1. Connect to CIAM tenant:
   ```powershell
   .\Connect-EntraCIAM.ps1
   ```

2. **Option A - Basic Deployment:**
   ```powershell
   .\Deploy-CIAMFull.ps1 `
       -TenantDomain "contosocustomers.onmicrosoft.com" `
       -AppName "Customer Portal" `
       -AppUri "http://localhost:3000"
   ```

3. **Option B - With Google:**
   ```powershell
   .\Deploy-CIAMFull.ps1 `
       -TenantDomain "contosocustomers.onmicrosoft.com" `
       -AppName "Customer Portal" `
       -AppUri "http://localhost:3000" `
       -EnableGoogle `
       -GoogleClientId "your-client-id" `
       -GoogleClientSecret "your-client-secret"
   ```

4. **Option C - Using Config File:**
   ```powershell
   # First, create config template
   New-CIAMConfigTemplate -OutputPath "my-ciam-config.json"
   
   # Edit the JSON file with your values
   # Then run:
   .\Deploy-CIAMFull.ps1 -ConfigFile "my-ciam-config.json"
   ```

5. **Option D - Dry Run:**
   ```powershell
   .\Deploy-CIAMFull.ps1 `
       -TenantDomain "contosocustomers.onmicrosoft.com" `
       -AppName "Customer Portal" `
       -AppUri "http://localhost:3000" `
       -DryRun
   ```

6. Follow the on-screen prompts and confirm

---

## Step 8: CIAM - List Existing Guests

### Steps:

```powershell
.\Connect-EntraCIAM.ps1

# List all external users
Get-MgUser -All -Filter "userType eq 'Guest'" | Format-Table DisplayName, Mail, UserType
```

---

# SCENARIO 2: B2B Collaboration

## When to Use B2B Collaboration
- Invite external partners as guest users
- Share Microsoft 365 resources
- Grant access to enterprise applications

---

## Step 9: Connect-EntraB2B.ps1

**Purpose**: Connect to Microsoft Graph for B2B operations

### Steps:

1. Open PowerShell
2. Navigate to B2B scripts:
   ```powershell
   cd C:\Users\luflores\OneDrive - Microsoft\07-Git\EEIDs\scripts\B2B
   ```
3. Run connection:
   ```powershell
   .\Connect-EntraB2B.ps1
   ```
4. Sign in with admin account in browser
5. Verify connection shows:
   - Connected successfully!
   - Tenant name
   - Account

---

## Step 10: Set-B2BCollaborationSettings.ps1

**Purpose**: Configure guest access permissions and invitation settings

### Steps:

1. Connect to your tenant:
   ```powershell
   .\Connect-EntraB2B.ps1
   ```

2. **Option A - Most Restrictive:**
   ```powershell
   .\Set-B2BCollaborationSettings.ps1 `
       -GuestUserAccess "Restricted" `
       -GuestInvitePermissions "AdminOnly" `
       -CollaborationDomains "AllowList" `
       -Domains @("trustedpartner.com")
   ```

3. **Option B - Limited Access:**
   ```powershell
   .\Set-B2BCollaborationSettings.ps1 `
       -GuestUserAccess "Limited" `
       -GuestInvitePermissions "UserInvitePermissions"
   ```

4. **Option C - Allow All (Testing Only):**
   ```powershell
   .\Set-B2BCollaborationSettings.ps1 `
       -GuestUserAccess "Full" `
       -GuestInvitePermissions "Anyone" `
       -CollaborationDomains "BlockList" `
       -Domains @("blocked.com")
   ```

**Settings Explained:**
| GuestUserAccess | Description |
|-----------------|-------------|
| Restricted | Can only see own profile |
| Limited | Can see group memberships of groups they're in |
| Full | Same as members (not recommended) |

| GuestInvitePermissions | Description |
|-----------------------|-------------|
| Anyone | All users can invite guests |
| UserInvitePermissions | Users with guest inviter role can invite |
| AdminOnly | Only admins can invite |

---

## Step 11: Set-B2BCrossTenantAccess.ps1

**Purpose**: Configure cross-tenant access settings for specific partners

### Steps:

1. Connect:
   ```powershell
   .\Connect-EntraB2B.ps1
   ```

2. **Option A - Enable B2B with Partner:**
   ```powershell
   .\Set-B2BCrossTenantAccess.ps1 `
       -OrganizationId "partner.onmicrosoft.com" `
       -EnableB2BInbound
   ```

3. **Option B - Enable Both Directions:**
   ```powershell
   .\Set-B2BCrossTenantAccess.ps1 `
       -OrganizationId "partner.onmicrosoft.com" `
       -EnableB2BInbound `
       -EnableB2BOutbound
   ```

4. **Option C - With MFA Trust:**
   ```powershell
   .\Set-B2BCrossTenantAccess.ps1 `
       -OrganizationId "partner.onmicrosoft.com" `
       -EnableB2BInbound `
       -TrustMfa "Accept"
   ```

5. **Option D - Block All, Allow Specific:**
   ```powershell
   # First block all (set in Default settings)
   # Then allow specific org:
   .\Set-B2BCrossTenantAccess.ps1 `
       -OrganizationId "trustedpartner.com" `
       -EnableB2BInbound
   ```

---

## Step 12: Invite-B2BGuest.ps1

**Purpose**: Invite external users as guests

### Steps:

1. Connect:
   ```powershell
   .\Connect-EntraB2B.ps1
   ```

2. **Option A - Simple Invitation:**
   ```powershell
   .\Invite-B2BGuest.ps1 `
       -Email "john@partnercompany.com" `
       -DisplayName "John Smith"
   ```

3. **Option B - With Group Assignment:**
   ```powershell
   .\Invite-B2BGuest.ps1 `
       -Email "jane@partnercompany.com" `
       -DisplayName "Jane Doe" `
       -Groups @("Guest Users", "Project Alpha Team")
   ```

4. **Option C - With Custom Message:**
   ```powershell
   .\Invite-B2BGuest.ps1 `
       -Email "user@partner.com" `
       -DisplayName "Partner User" `
       -InvitedByMessage "Welcome to our collaboration platform!"
   ```

5. **Option D - Bulk Import from CSV:**
   ```powershell
   # First create CSV file guests.csv:
   # Email,DisplayName,Groups
   # user1@partner.com,User One,Group1;Group2
   # user2@partner.com,User Two,Group1
   
   .\Invite-B2BGuest.ps1 -BulkFile ".\guests.csv"
   ```

6. **Option E - List Existing Guests:**
   ```powershell
   .\Invite-B2BGuest.ps1 -ListOnly
   ```

7. **Option F - Remove a Guest:**
   ```powershell
   .\Invite-B2BGuest.ps1
   # Then use:
   Remove-B2BGuest -Email "user@partner.com"
   ```

---

## Step 13: Set-B2BConditionalAccess.ps1

**Purpose**: Create Conditional Access policies for guest users

### Steps:

1. Connect:
   ```powershell
   .\Connect-EntraB2B.ps1
   ```

2. **Option A - Require MFA for Guests:**
   ```powershell
   .\Set-B2BConditionalAccess.ps1 `
       -PolicyName "MFA Required for Guest Users" `
       -Description "Require MFA for all external guest users" `
       -RequireMfa `
       -EnablePolicy
   ```

3. **Option B - Require Compliant Device:**
   ```powershell
   .\Set-B2BConditionalAccess.ps1 `
       -PolicyName "Compliant Device for Guests" `
       -RequireCompliantDevice `
       -EnablePolicy
   ```

4. **Option C - Block Unmanaged Devices:**
   ```powershell
   .\Set-B2BConditionalAccess.ps1 `
       -PolicyName "Block Unmanaged Devices" `
       -BlockUnmanagedDevices `
       -EnablePolicy
   ```

5. **Option D - Use Standard Template:**
   ```powershell
   .\Set-B2BConditionalAccess.ps1 -UseStandardTemplate "MFARequired" -EnablePolicy
   ```

6. **Option E - Target Specific Apps:**
   ```powershell
   .\Set-B2BConditionalAccess.ps1 `
       -PolicyName "MFA for Guest Access to SharePoint" `
       -RequireMfa `
       -TargetApps @("SharePoint Online ID") `
       -EnablePolicy
   ```

7. **Option F - List All Policies:**
   ```powershell
   .\Set-B2BConditionalAccess.ps1 -ListPolicies
   ```

8. **Option G - Disable a Policy:**
   ```powershell
   .\Set-B2BConditionalAccess.ps1 -DisablePolicy "MFA Required for Guest Users"
   ```

---

## Step 14: Deploy-B2BFull.ps1

**Purpose**: Orchestrate complete B2B Collaboration deployment

### Steps:

1. Connect:
   ```powershell
   .\Connect-EntraB2B.ps1
   ```

2. **Option A - Basic B2B Setup:**
   ```powershell
   .\Deploy-B2BFull.ps1 `
       -PartnerDomain "partner.onmicrosoft.com" `
       -GuestEmail "user@partner.com" `
       -GuestDisplayName "Partner User"
   ```

3. **Option B - With Security Settings:**
   ```powershell
   .\Deploy-B2BFull.ps1 `
       -PartnerDomain "partner.onmicrosoft.com" `
       -GuestEmail "user@partner.com" `
       -GuestDisplayName "John Doe" `
       -RequireMfaForGuests `
       -RestrictGuestAccess `
       -RestrictInvitations
   ```

4. **Option C - Using Config File:**
   ```powershell
   # Create template
   New-B2BConfigTemplate -OutputPath "b2b-config.json"
   
   # Edit JSON with your values
   .\Deploy-B2BFull.ps1 -ConfigFile "b2b-config.json"
   ```

5. **Option D - Dry Run:**
   ```powershell
   .\Deploy-B2BFull.ps1 `
       -PartnerDomain "partner.com" `
       -GuestEmail "test@partner.com" `
       -DryRun
   ```

---

# SCENARIO 3: B2B Direct Connect

## When to Use B2B Direct Connect
- External users need Teams shared channel access
- No guest account management wanted
- Mutual trust between two organizations

**NOTE**: Both organizations must run these scripts!

---

## Step 15: Set-B2BDirectConnect.ps1

**Purpose**: Configure B2B Direct Connect cross-tenant settings

### Steps:

1. **Organization A runs first:**
   ```powershell
   .\Connect-EntraB2B.ps1
   
   .\Set-B2BDirectConnect.ps1 `
       -OrganizationId "partner.onmicrosoft.com" `
       -EnableInbound `
       -EnableOutbound `
       -TrustMfa "Accept"
   ```

2. **Organization B must then run:**
   ```powershell
   .\Connect-EntraB2B.ps1
   
   .\Set-B2BDirectConnect.ps1 `
       -OrganizationId "contoso.onmicrosoft.com" `
       -EnableInbound `
       -EnableOutbound `
       -TrustMfa "Accept"
   ```

3. **Options explained:**
   | Parameter | Description |
   |-----------|-------------|
   | EnableInbound | Allow partner users to access YOUR shared channels |
   | EnableOutbound | Allow YOUR users to access PARTNER shared channels |
   | TrustMfa Accept | Accept MFA from partner (recommended) |
   | TrustMfa Require | Require MFA even if partner validated |
   | TrustCompliantDevices Accepted | Accept partner's Intune compliance |

4. **Verify status:**
   ```powershell
   Get-B2BDirectConnectStatus
   ```

5. **Test connection:**
   ```powershell
   Test-B2BDirectConnectConnection -PartnerOrgId "partner.onmicrosoft.com"
   ```

---

## Step 16: Set-TeamsSharedChannelPolicy.ps1

**Purpose**: Configure Teams policies for shared channels

### Steps:

1. **Connect to Teams:**
   ```powershell
   Connect-MicrosoftTeams
   # Sign in with admin account
   ```

2. **Option A - Enable All Shared Channel Features:**
   ```powershell
   .\Set-TeamsSharedChannelPolicy.ps1 `
       -EnableSharedChannels `
       -AllowExternalSharedChannelCreate `
       -AllowExternalSharedChannelJoin `
       -AllowUserToParticipateInExternalSharedChannel
   ```

3. **Option B - Basic Shared Channel:**
   ```powershell
   .\Set-TeamsSharedChannelPolicy.ps1 -EnableSharedChannels
   ```

4. **Option C - With External Access:**
   ```powershell
   .\Set-TeamsSharedChannelPolicy.ps1 `
       -EnableExternalAccess `
       -AllowFederatedUsers `
       -EnableGuestAccess
   ```

5. **Option D - List Current Policies:**
   ```powershell
   .\Set-TeamsSharedChannelPolicy.ps1 -ListPolicies
   ```

6. **Option E - Custom Policy Name:**
   ```powershell
   .\Set-TeamsSharedChannelPolicy.ps1 `
       -PolicyName "Marketing-SharedChannels" `
       -AllowExternalSharedChannelCreate `
       -AllowExternalSharedChannelJoin
   ```

---

## Step 17: Deploy-B2BDirectConnect.ps1

**Purpose**: Full B2B Direct Connect deployment

### Steps:

1. **Organization A runs:**
   ```powershell
   .\Connect-EntraB2B.ps1
   
   .\Deploy-B2BDirectConnect.ps1 `
       -PartnerDomain "partner.onmicrosoft.com" `
       -MutualConnection `
       -TrustMfa Accept `
       -ConfigureTeams
   ```

2. **Organization B runs (with Organization A's domain):**
   ```powershell
   .\Connect-EntraB2B.ps1
   
   .\Deploy-B2BDirectConnect.ps1 `
       -PartnerDomain "contoso.onmicrosoft.com" `
       -MutualConnection `
       -TrustMfa Accept `
       -ConfigureTeams
   ```

3. **Option - Dry Run:**
   ```powershell
   .\Deploy-B2BDirectConnect.ps1 `
       -PartnerDomain "partner.com" `
       -MutualConnection `
       -DryRun
   ```

4. **Get Partner Instructions:**
   ```powershell
   Get-PartnerInstructions -YourDomain "contoso.onmicrosoft.com"
   # This outputs instructions to share with partner
   ```

---

# Testing Your Deployment

## Test CIAM (Customer Identity)

1. Get the user flow URL from script output
2. Open in browser (incognito)
3. Click "Sign up now"
4. Complete registration
5. Verify user appears in CIAM tenant

## Test B2B Collaboration

1. Guest receives invitation email
2. Click "Accept Invitation"
3. Sign in with home organization credentials
4. Complete MFA if prompted
5. Access assigned resources

## Test B2B Direct Connect

1. Create a shared channel in Teams
2. Add external user by email
3. External user sees channel in their Teams
4. No invitation email needed
5. User appears as "(External)" in channel

---

# Troubleshooting

## Common Issues

| Issue | Solution |
|-------|----------|
| Module not found | `Install-Module Microsoft.Graph` |
| Permission denied | Check admin roles |
| Guest can't accept invite | Check spam, verify domain not blocked |
| MFA not working | Verify CA policy includes guests |
| Shared channel not visible | Both tenants must configure |
| Partner can't see channel | Verify mutual B2B DC configured |

## Get Help

```powershell
# Check current connection
Get-MgContext

# List all guest users
.\Invite-B2BGuest.ps1 -ListOnly

# List CA policies
.\Set-B2BConditionalAccess.ps1 -ListPolicies

# Test B2B Direct Connect
Test-B2BDirectConnectConnection -PartnerOrgId "partner.com"
```
