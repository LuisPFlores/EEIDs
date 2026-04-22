# Entra External Identities - PoC Setup Guide

This guide walks through deploying Proof of Concept implementations for all three External Identities scenarios.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Microsoft Entra ID P1/P2 license | Required for Conditional Access on guests |
| Two Microsoft 365 tenants | One as "Host" org, one as "Partner" org |
| Global Administrator access | Required for configuration |
| Test user accounts in both tenants | At least 1 per organization |

---

# Scenario 1: B2B Collaboration (Guest Users)

## Overview
Invite external users as guest accounts to access your apps and resources. They authenticate with their home organization.

## Step 1: Configure External Collaboration Settings

1. Sign into **Entra Admin Center** (entra.microsoft.com)
2. Navigate to **Identity** → **External Identities** → **External collaboration settings**

### Configure these settings:

| Setting | Recommended Value | Purpose |
|---------|-------------------|---------|
| Guest user access | Guest access restricted to properties and memberships of their own directory objects | Security baseline |
| Guest invite settings | Only users assigned to specific admin roles can invite | Control invitations |
| Collaboration restrictions | Allow specific domains (your partners) | Limit to trusted orgs |

## Step 2: Configure Cross-Tenant Access Settings

1. Go to **External Identities** → **Cross-tenant access settings**
2. Click **Add organization**
3. Enter partner's tenant ID or domain (e.g., `partner.onmicrosoft.com`)

### Configure Inbound Settings:

```
B2B Collaboration:
├── Users and groups: Allow → Select specific users/groups or All users
└── Applications: Allow → Select apps or All Microsoft and custom apps

Trust settings:
└── MFA: Accept (trust partner's MFA) OR Require (enforce in your tenant)
```

### Configure Outbound Settings (optional):

```
Control which of YOUR users can collaborate externally
```

## Step 3: Invite a Guest User

### Option A: Via Portal

1. Go to **Users** → **All users** → **Invite external user**
2. Enter the guest's email: `user@partnerdomain.com`
3. Fill in display name and personal message
4. Configure:
   - **Groups**: Add to appropriate security group
   - **Roles**: Assign app roles if needed
5. Click **Invite**

### Option B: Via PowerShell

```powershell
# Connect to Microsoft Graph
Connect-MgGraph -Scopes "User.Invite.All"

# Invite guest user
New-MgUserInvite -UserType "Guest" `
    -EmailAddress "partneruser@partnerdomain.com" `
    -SendInvitationMessage:$true `
    -InviteRedirectUrl "https://myapps.microsoft.com"
```

## Step 4: Apply Conditional Access for Guests

1. Go to **Protection** → **Conditional Access** → **New Policy**
2. Configure:

| Setting | Value |
|---------|-------|
| Name | MFA Required for Guest Users |
| Users | Select "Guest or external users" → "All guest and external users" |
| Target resources | Select apps or "All cloud apps" |
| Grant | Require multifactor authentication |

3. Enable policy → Create

## Step 5: Test the Flow

1. Guest receives invitation email
2. Clicks "Accept Invitation"
3. Redirected to partner's IdP → authenticates with work account
4. Redirected to your tenant → completes MFA if required
5. Lands on MyApps portal or assigned app

---

# Scenario 2: B2B Direct Connect (Teams Shared Channels)

## Overview
External users access Teams shared channels WITHOUT guest accounts. They stay in their home tenant and use their own credentials.

## Step 1: Enable B2B Direct Connect (Both Tenants)

**Both organizations must configure this:**

1. Go to **External Identities** → **Cross-tenant access settings**
2. Select the partner organization (already added in Scenario 1)
3. Under **Inbound settings**:

```
B2B Direct Connect:
├── Users and groups: Allow
└── Applications: Allow → Microsoft Teams
```

4. Under **Outbound settings** (in partner's tenant):
```
B2B Direct Connect:
└── Enable for your organization
```

## Step 2: Configure Teams Policies

In **Teams Admin Center** (admin.teams.microsoft.com):

1. Go to **Teams** → **Teams policies**
2. Create or edit the Global policy:
   - **Allow shared channels**: On
   - **Allow channel meeting**: On

3. Go to **Org-wide settings** → **External access**:
   - **Users can communicate with external users**: On
   - **Enable guest access**: On (for B2B collaboration fallback)

## Step 3: Create a Shared Channel

In **Microsoft Teams**:

1. Go to your team → **Add channel**
2. Channel name: `Joint Project - [YourOrg] x [PartnerOrg]`
3. Channel type: **Shared**
4. Add members from your org
5. Click **Add** → Search for partner users by email
6. They appear as external participants (not guests)

## Step 4: Verify External User Access

External user experience:
1. Partner user sees shared channel in their Teams client
2. No invitation needed - appears automatically
3. Authenticates with their org's credentials
4. Can chat, call, share files within the channel
5. Appears as `user@partner.com` (not as guest)

---

# Scenario 3: CIAM (Customer Identity)

## Overview
Create a separate external tenant for consumer-facing applications. Customers self-register and manage their own profiles.

## Step 1: Create External Tenant

1. Go to **Entra Admin Center** → **Manage tenants** → **Create**
2. Select **External** (CIAM scenario)
3. Enter:
   - **Initial domain name**: `yourapp.onmicrosoft.com`
   - **Domain name**: `yourapp.com` (verified later)
4. Complete wizard

## Step 2: Configure CIAM Settings

In your **External Tenant**:

1. Go to **External Identities** → **All identity providers**
2. Configure identity providers:

| Provider | Setup Required |
|----------|---------------|
| Email/One-time passcode | Built-in - enable it |
| Google | Create Google Cloud project → Get client ID/secret |
| Facebook | Create Facebook App → Get app ID/secret |
| Azure AD (B2B) | Add as SAML/OIDC provider |

## Step 3: Create User Flow (Sign-up/Sign-in)

1. Go to **External Identities** → **User flows** → **New user flow**
2. Select **Sign-up and sign-in**
3. Configure:

| Setting | Options |
|---------|---------|
| Identity providers | Select enabled IdPs |
| User attributes | Collect: Display name, Email, Country |
| App access | Select your registered apps |
| MFA | Optional or Required |
| User attributes (token) | Select attributes to return in token |

4. Create user flow

## Step 4: Register Your Application

1. Go to **App registrations** → **New registration**
2. Configure:

| Setting | Value |
|---------|-------|
| Name | Your Customer App |
| Supported accounts | Accounts in any identity provider |
| Redirect URI | Platform (Web/Mobile/SPA) + URL |

3. Note **Application (client) ID** and **Directory (tenant) ID**

## Step 5: Connect App to User Flow

1. Go to **App integrations** → Add integration
2. Select your user flow
3. Users now access your app via the configured user flow URL:

```
https://login.microsoftonline.com/{tenant}/...
/oauth2/v2.0/authorize?
client_id={app-id}&
redirect_uri={redirect-uri}&
response_type=code&
scope=openid profile email&
user_flow={user-flow-id}
```

## Step 6: Customize Branding (Optional)

1. Go to **Company branding** → **Localize**
2. Upload:
   - Banner logo
   - Background image
   - Sign-in page text
   - Hex colors matching your brand

---

# Verification Checklist

## B2B Collaboration
- [ ] Guest user received invitation email
- [ ] Guest can authenticate at home IdP
- [ ] Guest can access assigned apps
- [ ] Conditional Access MFA enforced
- [ ] Guest shows as user type "Guest" in directory

## B2B Direct Connect
- [ ] Shared channel visible in partner's Teams
- [ ] Partner user can post in channel
- [ ] No guest account created in host tenant
- [ ] File sharing works in shared channel
- [ ] Cross-tenant chat/calls functional

## CIAM
- [ ] External tenant created
- [ ] User flow accessible via URL
- [ ] Self-service registration works
- [ ] Email one-time passcode works
- [ ] Social provider (Google/Facebook) works
- [ ] Custom branding applied
- [ ] User appears in external tenant directory

---

# Troubleshooting

| Issue | Solution |
|-------|----------|
| Guest can't accept invitation | Check spam folder, verify email domain not blocked |
| MFA not working | Verify Conditional Access policy scope includes guests |
| Partner can't see shared channel | Confirm B2B Direct Connect enabled on BOTH tenants |
| CIAM user flow not loading | Verify app registration redirect URIs match |
| Users can't self-register | Check user flow "Identity providers" includes self-service option |

---

# Next Steps (Production)

1. **Implement Identity Governance**:
   - Set up Entitlement Management for access packages
   - Configure Access Reviews for periodic guest access auditing
   - Set up lifecycle policies (auto-remove after X days)

2. **Security Hardening**:
   - Enable session risk detection
   - Configure token protection
   - Set up sensitive resource protection

3. **Monitoring**:
   - Review Sign-in logs for external users
   - Set up alerts for unusual external activity
   - Monitor guest user count growth
