# Microsoft Entra External Identities (EEIDS) - Proof of Concept Repository

![Entra External ID](https://img.shields.io/badge/Microsoft%20Entra-External%20ID-0078D4?style=flat-square&logo=microsoft)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen?style=flat-square)

Comprehensive guide and automation scripts for implementing **Microsoft Entra External Identities** (CIAM - Customer Identity and Access Management) and **B2B Collaboration** scenarios.

---

## 📋 Overview

This repository provides:

- 🎯 **Step-by-step PoC guides** for all Entra External ID scenarios
- 🔐 **Three authentication protocols** – OAuth 2.0/OIDC, SAML 2.0, WS-Federation
- 🤖 **PowerShell automation scripts** for rapid deployment
- 💻 **Sample web application** with working authentication
- ✅ **Testing checklists** and validation procedures
- 🛡️ **Security best practices** and hardening guidelines

### Scenarios Covered

| Scenario | Purpose | Location |
|----------|---------|----------|
| **CIAM** | Customer sign-up/sign-in | `docs/`, `scripts/CIAM/` |
| **B2B Collaboration** | Guest user access | `docs/`, `scripts/B2B/` |
| **B2B Direct Connect** | Cross-tenant team collaboration | `scripts/B2B/`, `docs/` |
| **Multi-Protocol Auth** | OAuth 2.0, SAML 2.0, WS-Federation | `docs/entra-ciam-authentication-protocols.md` |

---

##  Quick Start

### Prerequisites

- **Microsoft Azure** with at least one tenant
- **Microsoft Entra ID P1/P2** license (for Conditional Access)
- **PowerShell 7+** or **Windows PowerShell 5.1+**
- **Node.js 18+** (for web app)
- **Global Administrator** or **External Identity Administrator** role

### 1️⃣ CIAM - Customer Sign-Up/Sign-In

**Fastest path**: 10 minutes to working sign-up/sign-in

```powershell
# 1. Create External (CIAM) tenant
.\scripts/CIAM/New-CIAMTenant.ps1 -DisplayName "Contoso Customers" -DomainName "contosocustomers"

# 2. Connect to CIAM tenant
.\scripts/CIAM/Connect-EntraCIAM.ps1

# 3. Register OIDC application
.\scripts/CIAM/Register-CIAMOIDCApp.ps1 `
    -DisplayName "Customer Portal" `
    -RedirectUri "https://yourdomain.com/auth/redirect"

# 4. Create sign-up/sign-in user flow
.\scripts/CIAM/New-CIAMUserFlow.ps1 -UserFlowName "SignUpSignIn"

# 5. Deploy full CIAM setup (optional)
.\scripts/CIAM/Deploy-CIAMFull.ps1
```

📖 **Detailed guide**: [docs/entra-external-id-poc-guide.md](docs/entra-external-id-poc-guide.md)

---

### 2️⃣ B2B - Guest User Collaboration

**Fastest path**: Invite external users in 5 minutes

```powershell
# 1. Connect to B2B tenant
.\scripts/B2B/Connect-EntraB2B.ps1

# 2. Configure external collaboration settings
.\scripts/B2B/Set-B2BCollaborationSettings.ps1

# 3. Invite a guest user
.\scripts/B2B/Invite-B2BGuest.ps1 `
    -GuestEmail "partner@example.com" `
    -GuestDisplayName "John Doe"

# 4. Set Conditional Access
.\scripts/B2B/Set-B2BConditionalAccess.ps1

# 5. Deploy full B2B setup (optional)
.\scripts/B2B/Deploy-B2BFull.ps1
```

📖 **Detailed guide**: [docs/entra-external-id-poc-guide.md](docs/entra-external-id-poc-guide.md)

---

### 3️⃣ Authentication Protocols

**Choose your authentication method**:

| Protocol | Best For | Setup |
|----------|----------|-------|
| **OAuth 2.0 / OIDC** | Modern web/mobile apps, social login | 15 min |
| **SAML 2.0** | Enterprise customer federation | 20 min |
| **WS-Federation** | Legacy AD FS scenarios | 15 min |

```powershell
# OAuth 2.0 / OIDC (recommended for most scenarios)
.\scripts/CIAM/Register-CIAMOIDCApp.ps1 `
    -DisplayName "My App" `
    -RedirectUri "https://myapp.com/auth/redirect"

# SAML 2.0 (for enterprise federation)
.\scripts/CIAM/Register-CIAMSAMLApp.ps1 `
    -DisplayName "Okta Partner" `
    -MetadataUrl "https://contoso.okta.com/app/exk.../sso/saml/metadata"

# WS-Federation (legacy AD FS)
.\scripts/CIAM/Register-CIAMWSFedApp.ps1 `
    -DisplayName "AD FS" `
    -Realm "https://login.microsoftonline.com/tenant-id/" `
    -PassiveEndpoint "https://adfs.example.com/adfs/ls/"
```

📖 **Deep dive**: [docs/entra-ciam-authentication-protocols.md](docs/entra-ciam-authentication-protocols.md)

---

### 4️⃣ Test Auth — OAuth 2.0 / OpenID Connect (`webapp/`)

A Node.js app using **MSAL-node** that demonstrates the OAuth 2.0 Authorization Code flow with PKCE against an Entra External ID (CIAM) tenant.

**Port:** `3000` · **Protocol:** OAuth 2.0 / OIDC · **Library:** `@azure/msal-node`

```bash
# 1. Navigate to the OIDC webapp
cd webapp

# 2. Install dependencies
npm install

# 3. Create and fill in .env
cp .env.example .env
```

Edit `.env` with your Entra CIAM values:

```bash
TENANT_ID=<your-ciam-tenant-id>
TENANT_SUBDOMAIN=<your-subdomain>         # subdomain prefix of your ciamlogin.com URL, NOT the GUID
CLIENT_ID=<your-app-registration-id>
CLIENT_SECRET=<your-app-secret>
REDIRECT_URI=http://localhost:3000/auth/redirect
USER_FLOW=<your-user-flow-name>           # e.g. B2C_1_SignUpSignIn
```

> ⚠️ `TENANT_SUBDOMAIN` must be the subdomain prefix of your CIAM login URL (e.g. `contoso` from `contoso.ciamlogin.com`), **not** the tenant GUID.

```bash
# 4. Start the app
npm start

# 5. Open in browser
# http://localhost:3000
# Sign in → http://localhost:3000/auth/login
```

What this app tests:
- ✅ OAuth 2.0 Authorization Code + PKCE flow
- ✅ OIDC ID token validation
- ✅ User profile claims (name, email, OID)
- ✅ Session management and protected routes
- ✅ Sign-out and token cleanup

---

### 5️⃣ Test Auth — WS-Federation (`webapp-wsfed/`)

A Node.js app using **passport-wsfed-saml2** that demonstrates the WS-Federation passive sign-in flow against a standard Entra (workforce) tenant. Useful for validating legacy AD FS federation scenarios.

**Port:** `3001` · **Protocol:** WS-Federation · **Library:** `passport-wsfed-saml2`

#### Azure Portal Setup (one-time)

Before running, register the app in Entra:

1. Go to [Entra Admin Center](https://entra.microsoft.com) → **Enterprise applications** → **New application** → **Create your own application**
2. Name it (e.g. `WS-Fed Test App`) and select **"Integrate any other application you don't find in the gallery"**
3. Go to **Single sign-on** → **SAML**
4. Set **Identifier (Entity ID)**: `https://login.microsoftonline.com/<TENANT_ID>/`
5. Set **Reply URL (ACS URL)**: `http://localhost:3001/auth/callback`
6. Go to **Users and groups** → assign your test user

#### Run the App

```bash
# 1. Navigate to the WS-Fed webapp
cd webapp-wsfed

# 2. Install dependencies
npm install

# 3. Create and fill in .env
cp .env.example .env
```

Edit `.env` with your values:

```bash
TENANT_ID=<your-tenant-id>
WSFED_REALM=https://login.microsoftonline.com/<TENANT_ID>/
WSFED_IDP_URL=https://login.microsoftonline.com/<TENANT_ID>/wsfed
WSFED_METADATA_URL=https://login.microsoftonline.com/<TENANT_ID>/federationmetadata/2007-06/federationmetadata.xml
WSFED_CALLBACK_URL=http://localhost:3001/auth/callback
WSFED_THUMBPRINTS=<comma-separated SHA1 thumbprints>
SESSION_SECRET=<random-string>
```

> **Getting thumbprints:** Run the following from the `webapp-wsfed/` directory and paste the output into `WSFED_THUMBPRINTS`:
>
> ```bash
> node -e "
> const https=require('https'),crypto=require('crypto');
> https.get('https://login.microsoftonline.com/<TENANT_ID>/federationmetadata/2007-06/federationmetadata.xml',r=>{
>   let d='';r.on('data',c=>d+=c);
>   r.on('end',()=>{
>     const m=d.match(/<X509Certificate[^>]*>([^<]+)<\/X509Certificate>/g)||[];
>     const t=[...new Set(m.map(x=>{const b=x.replace(/<[^>]+>/g,'').replace(/\s/g,'');
>       return crypto.createHash('sha1').update(Buffer.from(b,'base64')).digest('hex').toUpperCase();}))];
>     console.log(t.join(','));
>   });
> });
> "
> ```
>
> If you get a thumbprint mismatch error after signing in, add the `calculated:` value from the error message to your `WSFED_THUMBPRINTS` — Entra sometimes signs tokens with a cert not yet reflected in the metadata endpoint.

```bash
# 4. Start the app
npm start

# 5. Open in browser
# http://localhost:3001
# Sign in → http://localhost:3001/auth/login
```

What this app tests:
- ✅ WS-Federation passive redirect (`wa=wsignin1.0`)
- ✅ XML security token signature validation
- ✅ Entra claim extraction (OID, email, UPN, name)
- ✅ Raw WS-Federation claims display (for debugging)
- ✅ Session management and protected routes
- ✅ WS-Fed global sign-out (`wa=wsignout1.0`)

---

### 6️⃣ Test Auth - SAML 2.0 (`webapp-saml/`)

A standalone Node.js app using **Passport + SAML strategy** for testing SAML 2.0 sign-in with an external IdP (Okta, ADFS, PingFederate, or similar).

**Port:** `3002` · **Protocol:** SAML 2.0 · **Library:** `@node-saml/passport-saml`

#### Run the App

```bash
# 1. Navigate to the SAML webapp
cd webapp-saml

# 2. Install dependencies
npm install

# 3. Create and fill in .env
cp .env.example .env
```

Option A - explicit IdP settings in `.env`:

```bash
PORT=3002
SESSION_SECRET=<random-string>

SAML_SP_ENTITY_ID=http://localhost:3002/metadata.xml
SAML_CALLBACK_URL=http://localhost:3002/auth/callback

SAML_IDP_ENTRY_POINT=https://idp.example.com/sso/saml
SAML_IDP_ISSUER=https://idp.example.com/entity-id
SAML_IDP_CERT=<base64-x509-or-pem-certificate>
```

Option B - metadata URL fallback:

```bash
SAML_IDP_METADATA_URL=https://idp.example.com/metadata
```

If explicit IdP values are missing, the app attempts to resolve issuer, SSO entry point, and signing cert from metadata.

```bash
# 4. Start the app
npm start

# 5. Open in browser
# http://localhost:3002
# Sign in -> http://localhost:3002/auth/login
# Metadata -> http://localhost:3002/metadata.xml
```

What this app tests:
- ✅ SAML AuthnRequest initiation via redirect
- ✅ Assertion Consumer Service callback (`POST /auth/callback`)
- ✅ SAML assertion signature validation
- ✅ User claim extraction and profile display
- ✅ Service Provider metadata publishing (`/metadata.xml`)
- ✅ Session-protected routes and sign-out

---

## 📚 Documentation

### 📖 Main Guides

1. **[entra-external-id-poc-guide.md](docs/entra-external-id-poc-guide.md)** *(START HERE)*
   - Complete PoC walkthrough for all scenarios
   - Step-by-step Azure Portal configuration
   - Expected outcomes and testing

2. **[entra-ciam-authentication-protocols.md](docs/entra-ciam-authentication-protocols.md)**
   - OAuth 2.0 / OpenID Connect deep dive
   - SAML 2.0 enterprise federation
   - WS-Federation for legacy systems
   - Code samples for each protocol
   - Security best practices
   - Troubleshooting guide

3. **[authentication-protocol-scenarios.md](docs/authentication-protocol-scenarios.md)**
  - Scenario-by-scenario protocol summary
  - Use cases for OAuth 2.0, SAML 2.0, and WS-Federation
  - Included components and expected results

4. **[scripts-step-by-step-guide.md](docs/scripts-step-by-step-guide.md)**
   - Detailed PowerShell script execution guide
   - Parameter descriptions
   - Expected outputs
   - Error handling

5. **[entra-external-id-testing-checklist.md](docs/entra-external-id-testing-checklist.md)**
   - End-to-end testing procedures
   - Validation checklists
   - Common test scenarios
   - Success criteria

### 🚀 Quick References

- **[scripts/CIAM/AUTHENTICATION-PROTOCOLS.md](scripts/CIAM/AUTHENTICATION-PROTOCOLS.md)** – Quick protocol selection & setup
- **[scripts/CIAM/README.md](scripts/CIAM/README.md)** – CIAM scripts overview
- **[scripts/B2B/README.md](scripts/B2B/README.md)** – B2B scripts overview

---

## 🔐 Security Best Practices

This repository includes security hardening guidance for:

- ✅ **OAuth 2.0 / OIDC**
  - PKCE implementation
  - Token validation
  - Session management
  - Secure storage

- ✅ **SAML 2.0**
  - XML signature validation
  - Encrypted assertions
  - Certificate management
  - Single logout (SLO)

- ✅ **Conditional Access**
  - MFA policies
  - Risk detection
  - Device compliance
  - Location-based access

- ✅ **General Security**
  - Rate limiting
  - CSRF protection
  - Content Security Policy (CSP)
  - Certificate lifecycle management

See [docs/entra-ciam-authentication-protocols.md#security-best-practices](docs/entra-ciam-authentication-protocols.md#security-best-practices)

---

## 🧪 Testing & Validation

Complete testing procedures included:

```bash
# Run full PoC validation
# See: docs/entra-external-id-testing-checklist.md

# Test OIDC configuration
curl -X GET "https://{tenant-id}.ciamlogin.com/{tenant-id}/v2.0/.well-known/openid-configuration"

# Validate JWT tokens
# Visit: https://jwt.ms

# Test SAML metadata
curl -X GET "https://{tenant-id}.ciamlogin.com/{tenant-id}/Saml2/GetMetadata"
```

---

## 📋 Script Overview

### CIAM Scripts (Customer Identity)

| Script | Purpose | Time |
|--------|---------|------|
| `Connect-EntraCIAM.ps1` | Connect to CIAM tenant | 1 min |
| `New-CIAMTenant.ps1` | Create External tenant | 5 min |
| `Register-CIAMApp.ps1` | Register app (generic) | 3 min |
| `Register-CIAMOIDCApp.ps1` | Register OIDC app | 3 min |
| `Register-CIAMSAMLApp.ps1` | Register SAML app | 3 min |
| `Register-CIAMWSFedApp.ps1` | Register WS-Federation app | 3 min |
| `New-CIAMUserFlow.ps1` | Create sign-up/sign-in flow | 5 min |
| `Set-CIAMIdentityProviders.ps1` | Add identity providers (Google, Facebook, etc.) | 5 min |
| `Set-CIAMBranding.ps1` | Customize branding | 5 min |
| `Deploy-CIAMFull.ps1` | Deploy complete CIAM setup | 15 min |

### B2B Scripts (Guest Collaboration)

| Script | Purpose | Time |
|--------|---------|------|
| `Connect-EntraB2B.ps1` | Connect to B2B tenant | 1 min |
| `Invite-B2BGuest.ps1` | Invite external users | 2 min |
| `Set-B2BCollaborationSettings.ps1` | Configure collaboration | 5 min |
| `Set-B2BCrossTenantAccess.ps1` | Set cross-tenant access | 5 min |
| `Set-B2BConditionalAccess.ps1` | Configure CA policies | 10 min |
| `Set-B2BDirectConnect.ps1` | Enable Direct Connect | 5 min |
| `Set-TeamsSharedChannelPolicy.ps1` | Configure Teams channels | 5 min |
| `Deploy-B2BFull.ps1` | Deploy complete B2B setup | 15 min |
| `Deploy-B2BDirectConnect.ps1` | Deploy Direct Connect | 15 min |

---

## 🛠️ Technology Stack

### Documentation
- Markdown with embedded YAML

### Automation
- **PowerShell 7+** with Microsoft.Graph SDK
- **AzureAD PowerShell** module

### Web Application
- **Node.js 18+** runtime
- **Express 4.x** web framework
- **MSAL-node** for OAuth 2.0 / OIDC
- **express-session** for session management
- **dotenv** for configuration

### Cloud Platform
- **Microsoft Azure**
- **Microsoft Entra ID** (formerly Azure AD)
- **Entra External ID** (CIAM + B2B)

---

## 📥 Installation & Setup

### Clone Repository

```bash
git clone https://github.com/your-org/EEIDs.git
cd EEIDs
```

### Install PowerShell Modules

```powershell
# Microsoft Graph PowerShell SDK
Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber

# Azure AD Preview (for tenant creation)
Install-Module AzureADPreview -Scope CurrentUser -AllowClobber

# Microsoft Teams (for B2B Direct Connect)
Install-Module MicrosoftTeams -Scope CurrentUser -AllowClobber

# Verify installation
Get-Module -ListAvailable Microsoft.Graph, AzureADPreview, MicrosoftTeams
```

### Install Node.js Dependencies (Web App)

```bash
cd webapp
npm install
npm start
```

---

## 🔧 Configuration

### Environment Variables

The web application uses a `.env` file for configuration:

```bash
# Entra CIAM Configuration
TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
CLIENT_ID=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
CLIENT_SECRET=zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
REDIRECT_URI=http://localhost:3000/auth/redirect

# Application
NODE_ENV=development
PORT=3000
SESSION_SECRET=your-session-secret-here
```

See [webapp/.env.example](webapp/.env.example) for template.

---

## 🐛 Troubleshooting

### PowerShell Scripts

```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Check Microsoft Graph connection
Get-MgContext

# Clear cached credentials
Remove-MgContext -ErrorAction SilentlyContinue

# Reconnect
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"
```

### Web Application

```bash
# Check environment variables
node -e "console.log(process.env)"

# Enable debug logging
DEBUG=msal:* npm start

# Test OIDC metadata
curl https://{tenant-id}.ciamlogin.com/{tenant-id}/v2.0/.well-known/openid-configuration
```

### Common Issues

See [docs/entra-ciam-authentication-protocols.md#troubleshooting](docs/entra-ciam-authentication-protocols.md#troubleshooting) for detailed solutions.

---

## 📊 Scenario Comparison

| Feature | CIAM | B2B | B2B Direct Connect |
|---------|------|-----|-------------------|
| **Use Case** | Customer sign-up | Partner guest access | Cross-tenant teams |
| **User Type** | External customers | Guest users | Member in partner org |
| **Authentication** | OIDC/SAML/WS-Fed | Native tenant auth | Native tenant auth |
| **Access Control** | User flows, policies | Conditional Access | Teams policies |
| **Data Isolation** | Full isolation | Controlled sharing | Limited sharing |
| **Cost** | Per-auth pricing | Per-guest pricing | Included in Teams |
| **Complexity** | Medium | Low | Low |

---

## 📝 License

This repository is provided under the **MIT License**. See LICENSE file for details.

Includes examples and patterns from Microsoft documentation and best practices.

---

## 🤝 Contributing

Contributions are welcome! Please:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Guidelines

- Update documentation with any changes
- Include examples for new features
- Test PowerShell scripts before submitting
- Follow Microsoft naming conventions

---

## 📞 Support & Resources

### Microsoft Documentation

- [Entra External ID Overview](https://learn.microsoft.com/en-us/entra/external-id/)
- [CIAM Documentation](https://learn.microsoft.com/en-us/entra/external-id/customers/)
- [B2B Collaboration](https://learn.microsoft.com/en-us/entra/external-id/b2b/)
- [B2B Direct Connect](https://learn.microsoft.com/en-us/entra/external-id/b2b-direct-connect-overview)

### Support Channels

- **Azure Support Portal**: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade
- **Microsoft Q&A**: https://learn.microsoft.com/en-us/answers/products/entra
- **GitHub Issues**: For questions about this repository

### Learning Resources

- [Microsoft Learn - Entra ID](https://learn.microsoft.com/en-us/training/paths/implement-applications-external-users-azure-ad/)
- [Entra ID Blog](https://techcommunity.microsoft.com/t5/azure-active-directory-identity/bg-p/Identity)
- [Azure Architecture Center](https://learn.microsoft.com/en-us/azure/architecture/)

---

## 📈 Roadmap

- [ ] Azure CLI script equivalents
- [ ] Terraform/Infrastructure-as-Code examples
- [ ] Python SDK samples
- [ ] Java SDK samples
- [ ] Advanced conditional access policies
- [ ] Risk detection and remediation examples
- [ ] Multi-cloud federation guidance

---

## 👥 Authors

Created by the Microsoft Entra External Identities team with contributions from implementation partners.

---

## ✅ Status & Support

| Component | Status | Support |
|-----------|--------|---------|
| CIAM Scripts | ✅ Production Ready | Full |
| B2B Scripts | ✅ Production Ready | Full |
| Auth Protocols | ✅ Production Ready | Full |
| Web App Sample | ✅ Production Ready | Community |
| Documentation | ✅ Complete | Full |

---

## 📅 Last Updated

**April 22, 2026**

---

## Quick Links

- 🚀 [Get Started](docs/entra-external-id-poc-guide.md)
- 📖 [Authentication Protocols](docs/entra-ciam-authentication-protocols.md)
- 📄 [Authentication Protocol Scenarios](docs/authentication-protocol-scenarios.md)
- 🧪 [Testing Guide](docs/entra-external-id-testing-checklist.md)
- ⚙️ [Script Reference](docs/scripts-step-by-step-guide.md)
- 🔐 [Security Best Practices](docs/entra-ciam-authentication-protocols.md#security-best-practices)

---

**Ready to get started?** Follow the [Quick Start](#-quick-start) section above! 🚀
