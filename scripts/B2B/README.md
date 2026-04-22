# B2B Collaboration PowerShell Scripts

PowerShell scripts for deploying and managing Microsoft Entra B2B Collaboration PoC environments.

## Prerequisites

1. **Microsoft Graph PowerShell SDK**
   ```powershell
   Install-Module Microsoft.Graph -Scope CurrentUser
   ```

2. **Required Permissions**
   - User.ReadWrite.All
   - Application.ReadWrite.All
   - Directory.ReadWrite.All
   - Policy.ReadWrite.ConditionalAccess
   - IdentityProvider.ReadWrite.All
   - Group.ReadWrite.All
   - User.Invite.All

## Quick Start

### 1. Connect to Tenant

```powershell
# Interactive login
.\Connect-EntraB2B.ps1
```

### 2. Full Deployment

```powershell
# Basic B2B setup with guest invitation
.\Deploy-B2BFull.ps1 `
    -PartnerDomain "partner.onmicrosoft.com" `
    -GuestEmail "user@partner.com" `
    -GuestDisplayName "John Doe"

# With MFA requirement
.\Deploy-B2BFull.ps1 `
    -PartnerDomain "partner.onmicrosoft.com" `
    -GuestEmail "user@partner.com" `
    -RequireMfaForGuests

# Using config file
.\Deploy-B2BFull.ps1 -ConfigFile "b2b-config.json"
```

## Scripts Overview

| Script | Purpose |
|--------|---------|
| `Connect-EntraB2B.ps1` | Connect to Microsoft Graph |
| `Set-B2BCollaborationSettings.ps1` | Configure guest access, invitation permissions, domain restrictions |
| `Set-B2BCrossTenantAccess.ps1` | Configure partner organization access settings |
| `Invite-B2BGuest.ps1` | Invite guest users (single or bulk) |
| `Set-B2BConditionalAccess.ps1` | Create CA policies for guests |
| `Deploy-B2BFull.ps1` | Orchestrate full B2B PoC deployment |

## Usage Examples

### Configure Collaboration Settings

```powershell
# Restrictive settings (recommended for PoC)
.\Set-B2BCollaborationSettings.ps1 `
    -GuestUserAccess Limited `
    -GuestInvitePermissions AdminOnly `
    -CollaborationDomains AllowList `
    -Domains @("partner.com", "vendor.com")
```

### Configure Cross-Tenant Access

```powershell
# Enable B2B with trusted partner
.\Set-B2BCrossTenantAccess.ps1 `
    -OrganizationId "partner.onmicrosoft.com" `
    -EnableB2BInbound `
    -TrustMfa Accept

# Enable B2B Direct Connect for Teams
.\Set-B2BCrossTenantAccess.ps1 `
    -OrganizationId "partner.onmicrosoft.com" `
    -EnableB2BDirectConnectInbound `
    -EnableB2BDirectConnectOutbound
```

### Invite Guest Users

```powershell
# Single guest
.\Invite-B2BGuest.ps1 `
    -Email "user@partner.com" `
    -DisplayName "John Doe" `
    -Groups @("Guest Users", "Project Team")

# Bulk invitation from CSV
.\Invite-B2BGuest.ps1 -BulkFile "guests.csv"

# List existing guests
.\Invite-B2BGuest.ps1 -ListOnly
```

**CSV Format for bulk import:**
```csv
Email,DisplayName,Groups
user1@partner.com,User One,Group1;Group2
user2@partner.com,User Two,Group1
```

### Configure Conditional Access

```powershell
# Require MFA for guests
.\Set-B2BConditionalAccess.ps1 `
    -PolicyName "MFA Required for Guests" `
    -Description "Require MFA for all guest users" `
    -RequireMfa `
    -EnablePolicy

# Require compliant device
.\Set-B2BConditionalAccess.ps1 `
    -PolicyName "Compliant Device for Guests" `
    -RequireCompliantDevice `
    -EnablePolicy

# Use standard template
.\Set-B2BConditionalAccess.ps1 -UseStandardTemplate MFARequired -EnablePolicy

# List existing policies
.\Set-B2BConditionalAccess.ps1 -ListPolicies
```

## Configuration File

Create a JSON configuration file for automation:

```json
{
    "PartnerDomain": "partner.onmicrosoft.com",
    "PartnerTenantId": "",
    "GuestEmail": "user@partner.com",
    "GuestDisplayName": "Partner User",
    "GuestGroups": ["Guest Users"],
    "EnableB2BInbound": true,
    "EnableB2BDirectConnect": false,
    "RequireMfaForGuests": true,
    "RequireCompliantDevice": false,
    "RestrictGuestAccess": true,
    "RestrictInvitations": true
}
```

## B2B Collaboration Flow

```
1. Configure collaboration settings
      ↓
2. Add trusted partner (cross-tenant)
      ↓
3. Invite guest user
      ↓
4. Guest receives invitation email
      ↓
5. Guest authenticates at HOME IdP
      ↓
6. (Optional) MFA at resource tenant
      ↓
7. Guest accesses resources
```

## Troubleshooting

### Permission denied
Ensure you have the required admin roles:
- Global Administrator
- User Administrator
- Conditional Access Administrator

### Guest can't accept invitation
- Check spam folder
- Verify domain not in blocklist
- Check invitation email address is correct

### MFA not working for guests
- Verify Conditional Access policy includes "Guest or external users"
- Check that partner tenant has MFA enabled

### Cross-tenant access not working
- Both organizations must configure cross-tenant settings
- Verify partner domain/tenant ID is correct

## Security Best Practices

1. **Restrict guest access** - Use "Limited" or "Restricted" access level
2. **Require MFA** - Enforce MFA for all guest users
3. **Limit invitations** - Only allow admins to invite guests
4. **Use domain allowlist** - Only allow invitations from trusted domains
5. **Implement lifecycle management** - Use access reviews to remove inactive guests
6. **Monitor activity** - Review sign-in logs regularly

---

# B2B Direct Connect (Teams Shared Channels)

## Overview

B2B Direct Connect enables external users to access Teams shared channels **without guest accounts**. Users stay in their home tenant and use SSO.

## Prerequisites

- Microsoft Entra ID P1/P2 (both tenants)
- Teams Administrator + Global Administrator roles
- **Both organizations must configure** - mutual trust required

## Quick Start

```powershell
# Connect to your tenant
.\Connect-EntraB2B.ps1

# Deploy B2B Direct Connect
.\Deploy-B2BDirectConnect.ps1 -PartnerDomain "partner.onmicrosoft.com" -MutualConnection
```

## B2B Direct Connect Scripts

| Script | Purpose |
|--------|---------|
| `Set-B2BDirectConnect.ps1` | Configure cross-tenant B2B Direct Connect settings |
| `Set-TeamsSharedChannelPolicy.ps1` | Configure Teams policies for shared channels |
| `Deploy-B2BDirectConnect.ps1` | Full deployment orchestration |

## Usage Examples

### Configure B2B Direct Connect

```powershell
# Enable mutual B2B Direct Connect with partner
.\Set-B2BDirectConnect.ps1 `
    -OrganizationId "partner.onmicrosoft.com" `
    -EnableInbound `
    -EnableOutbound `
    -TrustMfa Accept

# With device compliance trust
.\Set-B2BDirectConnect.ps1 `
    -OrganizationId "partner.onmicrosoft.com" `
    -EnableInbound `
    -EnableOutbound `
    -TrustMfa Accept `
    -TrustCompliantDevices Accepted
```

### Configure Teams Shared Channels

```powershell
# Enable shared channel policies
.\Set-TeamsSharedChannelPolicy.ps1 `
    -EnableSharedChannels `
    -AllowExternalSharedChannelCreate `
    -AllowExternalSharedChannelJoin

# List current policies
.\Set-TeamsSharedChannelPolicy.ps1 -ListPolicies
```

### Full Deployment

```powershell
# Deploy with Teams configuration
.\Deploy-B2BDirectConnect.ps1 `
    -PartnerDomain "partner.onmicrosoft.com" `
    -MutualConnection `
    -TrustMfa Accept `
    -ConfigureTeams
```

## Important: Mutual Configuration Required

B2B Direct Connect requires **both organizations** to configure:

```
Organization A (You)          Organization B (Partner)
─────────────────────         ───────────────────────
Enable inbound   ✓            Enable inbound   ✓
Enable outbound  ✓            Enable outbound  ✓
Teams policies   ✓            Teams policies   ✓
```

After running the deployment script, share the partner instructions:

```powershell
Get-PartnerInstructions -YourDomain "contoso.onmicrosoft.com"
```

## How It Works

```
1. Configure cross-tenant access (both tenants)
       ↓
2. Both sides enable B2B Direct Connect
       ↓
3. Configure Teams policies (both tenants)
       ↓
4. Create shared channel in Teams
       ↓
5. Add external user by email
       ↓
6. External user sees channel in their Teams (no guest account!)
```

## Troubleshooting

### Shared channel not visible to external user
- Verify both tenants configured cross-tenant access
- Confirm Teams policies allow external shared channels
- Wait up to 24 hours for policy propagation

### MFA prompts excessive
- Configure trust settings to accept partner's MFA claims
- Set `-TrustMfa Accept`

### Can't add external user to channel
- Verify partner enabled B2B Direct Connect outbound
- Check that external user is in allowed users/groups

## Key Differences: B2B vs B2B Direct Connect

| Feature | B2B Collaboration | B2B Direct Connect |
|---------|-------------------|-------------------|
| Guest account created | Yes | No |
| User stays in home tenant | No | Yes |
| Teams shared channels | No | Yes |
| Requires mutual config | No | Yes |
| Lifecycle managed by | Resource org | Home org |
