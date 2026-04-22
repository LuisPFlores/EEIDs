# Entra CIAM - Authentication Protocol Setup Scripts

Quick reference for PowerShell scripts to configure OAuth 2.0/OIDC, SAML 2.0, and WS-Federation.

---

## 📚 Main Documentation

**Comprehensive Guide**: See [../docs/entra-ciam-authentication-protocols.md](../../docs/entra-ciam-authentication-protocols.md)

This guide includes:
- Protocol comparison matrix
- Use case decision matrix
- Complete Azure Portal step-by-step instructions
- Security best practices
- Testing & validation procedures
- Troubleshooting guide

---

## 🚀 Quick Start Scripts

### **1. OAuth 2.0 / OpenID Connect (Recommended)**

**Use when**: Building modern web/mobile apps, need social login, or want simplest implementation.

```powershell
# Prerequisites
Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes "Application.ReadWrite.All"

# Register OIDC app
.\Register-CIAMOIDCApp.ps1 `
    -DisplayName "Customer Portal" `
    -RedirectUri "https://yourdomain.com/auth/redirect"
```

**Output**: 
- Application ID (Client ID)
- Tenant ID
- Client secret (copy immediately!)
- .env template ready to use

**Recommended for**:
- ✅ Single-page applications (React, Angular, Vue)
- ✅ Native mobile apps
- ✅ Backend web applications
- ✅ APIs with access tokens
- ✅ Social login (Google, Facebook, Apple)

---

### **2. SAML 2.0**

**Use when**: Integrating enterprise customers with their own identity providers.

```powershell
# Prerequisites
Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"

# Register SAML app (with metadata)
.\Register-CIAMSAMLApp.ps1 `
    -DisplayName "Okta Partner" `
    -MetadataUrl "https://contoso.okta.com/app/exk.../sso/saml/metadata"

# OR register SAML app (manual configuration)
.\Register-CIAMSAMLApp.ps1 `
    -DisplayName "PingFederate" `
    -Issuer "https://pingfed.example.com" `
    -SignOnUrl "https://pingfed.example.com/idp/SSO.saml2"
```

**Output**:
- Enterprise Application ID
- Service provider configuration values
- Azure Portal step-by-step instructions
- Provider-specific guidance (Okta, PingFederate, JumpCloud)

**Recommended for**:
- ✅ Enterprise customer federation
- ✅ B2B2C scenarios
- ✅ Okta integration
- ✅ PingFederate integration
- ✅ JumpCloud integration
- ✅ Custom SAML 2.0 providers

---

### **3. WS-Federation (Legacy)**

**Use when**: On-premises Active Directory Federation Services (AD FS) is required.

```powershell
# Prerequisites
Install-Module Microsoft.Graph -Scope CurrentUser
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"

# Register WS-Federation app
.\Register-CIAMWSFedApp.ps1 `
    -DisplayName "AD FS Partner" `
    -Realm "https://login.microsoftonline.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/" `
    -PassiveEndpoint "https://adfs.example.com/adfs/ls/" `
    -MetadataUrl "https://adfs.example.com/federationmetadata/2007-06/federationmetadata.xml"
```

**Output**:
- Enterprise Application ID
- WS-Federation configuration
- Azure Portal setup instructions
- AD FS PowerShell commands

**Recommended for**:
- ⚠️ On-premises Active Directory Federation Services (AD FS)
- ⚠️ Shibboleth integration
- ⚠️ Legacy .NET applications requiring WS-*
- ❌ **NOT recommended** for new implementations

---

## 📋 Protocol Decision Matrix

| Need | Protocol | Script |
|------|----------|--------|
| **Modern web app** | OIDC | `Register-CIAMOIDCApp.ps1` |
| **Mobile app** | OIDC | `Register-CIAMOIDCApp.ps1` |
| **Social login** | OIDC | `Register-CIAMOIDCApp.ps1` |
| **Enterprise customer federation** | SAML 2.0 | `Register-CIAMSAMLApp.ps1` |
| **Okta/Ping integration** | SAML 2.0 | `Register-CIAMSAMLApp.ps1` |
| **On-premises AD FS** | WS-Federation | `Register-CIAMWSFedApp.ps1` |
| **Fastest setup** | OIDC | `Register-CIAMOIDCApp.ps1` |
| **Most flexible** | OIDC + SAML | Run both scripts |

---

## 🔐 Prerequisites

### Entra Permissions Required
- **Global Administrator** OR
- **External Identity Administrator** OR
- **Application Administrator**

### PowerShell Setup

```powershell
# Check if Microsoft.Graph is installed
Get-Module -ListAvailable Microsoft.Graph

# If not installed
Install-Module Microsoft.Graph -Scope CurrentUser -AllowClobber

# Import module
Import-Module Microsoft.Graph.Applications

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"

# Check current connection
Get-MgContext
```

---

## 📝 Typical Workflow

### For New CIAM Implementation

1. **Determine your authentication needs**
   - Is it customer-facing? → OIDC
   - Need to federate enterprise customers? → OIDC + SAML
   - Legacy AD FS only? → WS-Federation

2. **Run appropriate script(s)**
   ```powershell
   # Start with OIDC for modern app
   .\Register-CIAMOIDCApp.ps1 -DisplayName "My App" -RedirectUri "https://myapp.com/auth/redirect"
   ```

3. **Gather configuration values**
   - Script outputs configuration automatically
   - Copy to .env file for application

4. **Add to user flows**
   - Go to External Identities > User flows
   - Add the identity provider
   - Test sign-in

5. **Configure in application**
   - Use MSAL.js (SPA) or MSAL-Node (backend)
   - See [../docs/entra-ciam-authentication-protocols.md](../../docs/entra-ciam-authentication-protocols.md) for code samples

---

## 🧪 Testing

### Test OIDC Configuration

```bash
# Test discovery endpoint
curl -X GET "https://{tenant-id}.ciamlogin.com/{tenant-id}/v2.0/.well-known/openid-configuration" | ConvertFrom-Json

# View token claims (after sign-in)
# Visit https://jwt.ms and paste your ID token
```

### Test SAML Configuration

```bash
# View SAML metadata
curl -X GET "https://{tenant-id}.ciamlogin.com/{tenant-id}/Saml2/GetMetadata"

# Validate assertions at https://www.samltool.com/validate_xml.php
```

### Test WS-Federation Configuration

```powershell
# Check AD FS endpoint
Invoke-WebRequest -Uri "https://adfs.example.com/adfs/.well-known/webfinger" -Verbose

# View federation metadata
Invoke-WebRequest -Uri "https://adfs.example.com/federationmetadata/2007-06/federationmetadata.xml"
```

---

## 🐛 Troubleshooting

### Script Fails to Connect

```powershell
# Clear cached credentials
Remove-MgContext -ErrorAction SilentlyContinue

# Reconnect
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"
```

### Client Secret Not Shown

**Issue**: You didn't copy the secret immediately after creation

**Solution**: Delete and recreate:
1. Go to Azure Portal > App registrations
2. Select your app
3. Certificates & secrets
4. Delete old secret
5. Click + New client secret
6. Copy immediately

### Redirect URI Mismatch

**Issue**: Application shows "The redirect URI does not match"

**Solutions**:
1. Ensure REDIRECT_URI in .env matches exactly
2. Check for trailing slashes
3. Check protocol (http vs https)
4. Update registered redirect URIs in Azure Portal

### SAML Metadata Not Found

**Issue**: "Unable to read SAML metadata from IdP"

**Solutions**:
1. Verify metadata URL is accessible from Azure
2. Check IdP hasn't moved the metadata endpoint
3. Try downloading metadata manually and uploading file
4. Verify network connectivity from Azure to IdP

---

## 📚 Related Documentation

- **Full Protocol Guide**: [Entra CIAM Authentication Protocols](../../docs/entra-ciam-authentication-protocols.md)
- **Microsoft Learn - CIAM**: https://learn.microsoft.com/en-us/entra/external-id/customers/
- **OIDC Protocol**: https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols-oidc
- **SAML Apps**: https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-register-saml-app
- **WS-Federation**: https://learn.microsoft.com/en-us/entra/external-id/direct-federation

---

## 📞 Support

- **Azure Support**: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade
- **Microsoft Q&A**: https://learn.microsoft.com/en-us/answers/products/entra
- **GitHub Issues**: https://github.com/AzureAD/microsoft-authentication-library-js/issues

---

**Last Updated**: April 22, 2026
**Status**: ✅ Ready for production use
