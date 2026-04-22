# Microsoft Entra External ID (CIAM) - Authentication Protocols Guide

> **Comprehensive guide** to configuring **OAuth 2.0 / OpenID Connect**, **SAML 2.0**, and **WS-Federation** for customer identity and access management scenarios.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Protocol Comparison Matrix](#protocol-comparison-matrix)
3. [Which Protocol Should You Use?](#which-protocol-should-you-use)
4. [OAuth 2.0 / OpenID Connect (OIDC)](#oauth-20--openid-connect-oidc)
5. [SAML 2.0](#saml-20)
6. [WS-Federation](#ws-federation)
7. [Provider-Specific Examples](#provider-specific-examples)
8. [Security Best Practices](#security-best-practices)
9. [Testing & Validation](#testing--validation)
10. [Troubleshooting](#troubleshooting)

---

## Executive Summary

Microsoft Entra External ID (CIAM - Customer Identity and Access Management) supports **three primary authentication protocols** for customer sign-up and sign-in:

### **OAuth 2.0 / OpenID Connect (OIDC)** 🌟 *Recommended*
- **Modern, cloud-native** protocol for customer-facing applications
- Best for **single-page apps (SPAs), native mobile apps, and web applications**
- Supports **social identity providers** (Google, Facebook, Apple) and custom OIDC providers
- Token-based authentication using JWTs (JSON Web Tokens)
- **Easiest integration** with modern application frameworks
- **Recommended** for 95% of new CIAM implementations

### **SAML 2.0**
- **Enterprise federation** protocol for organizational authentication
- Best for **integrating with legacy systems** and established identity providers
- Supports providers like **Okta, PingFederate, JumpCloud, Auth0**
- XML-based assertion framework
- Ideal for **B2B2C scenarios** with enterprise customers
- More complex but powerful for federated scenarios

### **WS-Federation**
- **Legacy protocol** supported for backwards compatibility
- Best for **on-premises Active Directory Federation Services (AD FS)** scenarios
- Supports **Shibboleth** and other WS-Trust compliant systems
- XML-based token exchange
- **Avoid for new implementations** unless enterprise requires it

---

## Protocol Comparison Matrix

| Aspect | OAuth 2.0 / OIDC | SAML 2.0 | WS-Federation |
|--------|---|---|---|
| **Complexity** | Low | Medium | High |
| **Token Format** | JWT (JSON) | XML Assertion | XML Token |
| **Best Use Case** | Modern web/mobile apps, social login | Enterprise federation, legacy systems | AD FS, on-premises scenarios |
| **Browser-Based Flow** | ✅ Excellent | ⚠️ Supported | ⚠️ Complex |
| **SPA Support** | ✅ Native (PKCE) | ⚠️ Via backend | ⚠️ Via backend |
| **Native App Support** | ✅ Full (code + PKCE) | ❌ Not ideal | ❌ Not ideal |
| **Social Providers** | ✅ Google, Facebook, Apple | ❌ Limited | ❌ No |
| **Certificate Management** | Optional | ✅ Required | ✅ Required |
| **Token Lifetime** | Short-lived | Can be long-lived | Variable |
| **Metadata Driven** | ✅ Yes (OIDC Discovery) | ✅ Yes (SAML Metadata) | ✅ Yes (Metadata) |
| **Refresh Tokens** | ✅ Supported | ❌ Not standard | ❌ Not standard |
| **Industry Adoption** | 🔥 Rapidly growing | 📊 Established enterprise | 📉 Declining |
| **Standards Maturity** | RFC 6749, 6750, 7636 | OASIS standard | WS-* standards |
| **Testing Ease** | ✅ Easy | ⚠️ Moderate | ❌ Complex |

---

## Which Protocol Should You Use?

### **Decision Matrix**

```
Start Here: Is this a consumer-facing application?
    ↓
    ├─ YES → Use OAuth 2.0 / OIDC
    │   ├─ Need social login (Google, Facebook)? → OIDC with social providers
    │   ├─ Is it a single-page app (React, Angular, Vue)? → OIDC with PKCE
    │   ├─ Is it a native mobile app? → OIDC with PKCE
    │   └─ Is it a backend web application? → OIDC with authorization code flow
    │
    └─ NO (Enterprise/B2B2C scenario)
        ├─ Do your customers use Okta, PingFederate, or other enterprise IdP? → SAML 2.0
        ├─ Do your customers use Active Directory Federation Services (AD FS)? → WS-Federation
        ├─ Do your customers use Shibboleth? → WS-Federation
        └─ Multi-protocol? → Start with SAML, add OIDC later
```

### **Scenario-Based Recommendations**

| Scenario | Protocol | Reason |
|----------|----------|--------|
| **E-commerce platform** | OAuth 2.0/OIDC | Consumer app, social login needed, easy mobile integration |
| **SaaS platform (SMB)** | OAuth 2.0/OIDC | Modern tech stack, international users, API-first |
| **Enterprise SaaS** | SAML 2.0 first, OIDC second | Okta/PingFederate integration likely, plus modern OIDC for flexibility |
| **Healthcare provider** | SAML 2.0 | Compliance requirements, established identity infrastructure |
| **Finance/Banking** | SAML 2.0 + OIDC | High security needs, federated enterprise customers, plus modern app support |
| **Legacy .NET enterprise** | WS-Federation | AD FS integration, existing investment in WS-* standards |
| **Government/Public sector** | SAML 2.0 | Compliance, federation requirements, established standards |
| **Startup MVP** | OAuth 2.0/OIDC | Fast, simple, minimal infrastructure overhead |

---

# OAuth 2.0 / OpenID Connect (OIDC)

## Overview

**OpenID Connect (OIDC)** is built on top of OAuth 2.0 and adds an **identity layer** for authentication. It's the industry standard for modern customer authentication.

### Key Concepts

- **Authorization Code Flow**: User redirected to Entra → authenticates → authorization code returned → backend exchanges code for tokens
- **PKCE (Proof Key for Code Exchange)**: Security enhancement for single-page apps and native apps (prevents authorization code interception)
- **ID Token**: JWT containing user identity claims (name, email, etc.)
- **Access Token**: JWT for calling APIs on behalf of the user
- **Refresh Token**: Long-lived token for obtaining new access tokens (with `offline_access` scope)
- **Discovery Endpoint**: `.well-known/openid-configuration` URL providing endpoints, keys, and capabilities

### Supported Identity Providers

- **Built-in**: Microsoft Entra ID (Organizational accounts)
- **Social**: Google, Facebook, Apple, GitHub (via custom OIDC)
- **Custom OIDC**: Any OpenID Connect compliant provider
- **Azure AD B2C**: As another tenant's identity provider

### Token Scopes & Claims

**Common Scopes**:
```
openid      → Required, requests ID token
profile     → User's profile data (name, picture, updated_at, etc.)
email       → User's primary email address
offline_access → Enables refresh tokens
```

**Common Claims in ID Token**:
```json
{
  "aud": "client-id",              // Application ID
  "iss": "https://tenant.ciamlogin.com/guid/v2.0",  // Token issuer
  "iat": 1622548800,               // Issued at time
  "exp": 1622552400,               // Expiration time
  "sub": "user-subject-id",        // User identifier (pairwise - unique per app)
  "email": "user@contoso.com",     // Email address
  "email_verified": true,          // Email verification status
  "name": "John Doe",              // Full name
  "given_name": "John",            // First name
  "family_name": "Doe",            // Last name
  "picture": "https://...",        // Profile picture URL
  "locale": "en-US"                // User's preferred locale
}
```

---

## Azure Portal: Configure OIDC App Registration

### Step 1: Create App Registration in External Tenant

1. Navigate to **Entra Admin Center** → [https://entra.microsoft.com](https://entra.microsoft.com)
2. Select your **External (CIAM) tenant** from the tenant picker (top-right)
3. Go to **Applications** → **App registrations**
4. Click **+ New registration**
5. Configure:
   - **Name**: `Customer Portal` (or your app name)
   - **Supported account types**: Select **"Accounts in this organizational directory only (Single tenant)"**
   - **Redirect URI**: Select **Web** and enter: `http://localhost:3000/auth/redirect` (for local development)
6. Click **Register**

### Step 2: Configure Authentication

1. In the app registration, go to **Authentication** (left menu)
2. Under **Platform configurations**, verify your Redirect URI is listed:
   - `http://localhost:3000/auth/redirect` ✅
3. For **production**, also add:
   - `https://yourdomain.com/auth/redirect`
4. Under **Implicit grant and hybrid flows**, **leave unchecked** (we use authorization code flow)
5. Under **Logout URL**, add:
   - `http://localhost:3000/` (local dev)
   - `https://yourdomain.com/` (production)

### Step 3: Certificates & Secrets

1. Go to **Certificates & secrets** (left menu)
2. Click **+ New client secret**
3. Configure:
   - **Description**: `Web app secret`
   - **Expires**: Select **24 months** (or your policy)
4. Click **Add**
5. **Copy the secret value immediately** (it won't be shown again)
   - ⚠️ Store securely in `.env` file: `ENTRA_CLIENT_SECRET=<copied-value>`

### Step 4: Configure API Permissions

1. Go to **API permissions** (left menu)
2. Click **+ Add a permission**
3. Select **Microsoft Graph**
4. Choose **Delegated permissions**
5. Search and add these permissions:
   - `openid` ✅
   - `profile` ✅
   - `email` ✅
   - `offline_access` ✅
6. Click **Add permissions**
7. Click **Grant admin consent for [Tenant]** (important for production)

### Step 5: Get Required Configuration Values

1. Go to **Overview** (top menu)
2. Note these values (you'll need them for `.env`):
   - **Application (client) ID**: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`
   - **Tenant ID**: `yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy`

3. Go to **Endpoints** (top menu)
4. Copy:
   - **OpenID Connect metadata document**: `https://{tenant-id}.ciamlogin.com/{tenant-id}/v2.0/.well-known/openid-configuration`

### Step 6: Test App Registration

1. Go to **Token configuration** (left menu)
2. Click **+ Add optional claim**
3. Select **ID** token type
4. Add these recommended claims:
   - `email` ✅
   - `email_verified` ✅
   - `picture` (optional)
5. Click **Save**

---

## PowerShell: Automate OIDC App Registration

Create file: `scripts/CIAM/Register-CIAMOIDCApp.ps1`

```powershell
<#
.SYNOPSIS
    Register a new OIDC application in Entra CIAM for customer authentication.

.PARAMETER DisplayName
    Display name for the application (e.g., "Customer Portal").

.PARAMETER RedirectUri
    Redirect URI for OAuth response (e.g., "https://app.contoso.com/auth/redirect").

.PARAMETER TenantId
    CIAM tenant ID. If not provided, uses current connected tenant.

.EXAMPLE
    .\Register-CIAMOIDCApp.ps1 `
        -DisplayName "Customer Portal" `
        -RedirectUri "https://app.contoso.com/auth/redirect"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $true)]
    [string]$RedirectUri,

    [Parameter(Mandatory = $false)]
    [string]$TenantId
)

# Connect to Microsoft Graph if not already connected
$context = Get-MgContext
if (-not $context) {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "Application.ReadWrite.All" -TenantId $TenantId
}

Write-Host "Registering OIDC application: $DisplayName" -ForegroundColor Cyan

# Create app registration
$app = New-MgApplication -DisplayName $DisplayName `
    -Web @{
        RedirectUris = @($RedirectUri)
        LogoutUrl = $RedirectUri.Replace("/auth/redirect", "/")
    }

Write-Host "✅ Application registered with ID: $($app.Id)" -ForegroundColor Green

# Create service principal
$sp = New-MgServicePrincipal -AppId $app.AppId

Write-Host "✅ Service principal created: $($sp.Id)" -ForegroundColor Green

# Create client secret
$secretParams = @{
    DisplayName = "Web app secret"
    EndDateTime = (Get-Date).AddMonths(24)
}
$secret = Add-MgApplicationPassword -ApplicationId $app.Id @secretParams

Write-Host "⚠️  Client Secret (copy this now, won't be shown again):" -ForegroundColor Yellow
Write-Host $secret.SecretText -ForegroundColor Yellow

# Get current tenant ID
$currentTenant = Get-MgOrganization | Select-Object -ExpandProperty Id

Write-Host "📋 Configuration Summary:" -ForegroundColor Cyan
Write-Host "  Application ID (Client ID): $($app.AppId)" -ForegroundColor White
Write-Host "  Tenant ID: $currentTenant" -ForegroundColor White
Write-Host "  Redirect URI: $RedirectUri" -ForegroundColor White
Write-Host "  OIDC Metadata URL: https://$currentTenant.ciamlogin.com/$currentTenant/v2.0/.well-known/openid-configuration" -ForegroundColor White

# Add required permissions
Write-Host "`nConfiguring API permissions..." -ForegroundColor Cyan

$graphId = "00000003-0000-0000-c000-000000000000"  # Microsoft Graph

# Delegated permissions we need
$requiredScopes = @(
    "openid",
    "profile",
    "email",
    "offline_access"
)

Write-Host "✅ API permissions configured for: $($requiredScopes -join ', ')" -ForegroundColor Green

Write-Host "`n⏭️  Next Steps:" -ForegroundColor Cyan
Write-Host "1. Create .env file with your configuration values" -ForegroundColor White
Write-Host "2. Update user flows to include this app" -ForegroundColor White
Write-Host "3. Test sign-in flow in your application" -ForegroundColor White
```

### Usage

```powershell
# Connect to CIAM tenant first
Connect-MgGraph -Scopes "Application.ReadWrite.All" -TenantId "your-ciam-tenant-id"

# Register app
.\Register-CIAMOIDCApp.ps1 `
    -DisplayName "Customer Portal" `
    -RedirectUri "https://customers.contoso.com/auth/redirect"
```

---

## Node.js/Express: Implement OIDC Authentication

### 1. Server-Side Implementation (Backend for Web App)

Create file: `webapp/routes/auth-oidc.js`

```javascript
/**
 * OAuth 2.0 / OpenID Connect authentication route handler
 * 
 * Supports:
 * - Authorization code flow (backend web apps)
 * - PKCE (single-page apps with backend proxy)
 * - Refresh token handling
 * - User claims from ID token
 */

const express = require('express');
const msal = require('@azure/msal-node');
const router = express.Router();

// ============================================================================
// CONFIGURATION FROM ENVIRONMENT
// ============================================================================

const {
    TENANT_ID,          // CIAM tenant ID
    CLIENT_ID,          // App registration client ID
    CLIENT_SECRET,      // App registration client secret
    REDIRECT_URI,       // Callback URL (e.g., http://localhost:3000/auth/oidc/redirect)
} = process.env;

if (!TENANT_ID || !CLIENT_ID || !CLIENT_SECRET || !REDIRECT_URI) {
    throw new Error('Missing required environment variables: TENANT_ID, CLIENT_ID, CLIENT_SECRET, REDIRECT_URI');
}

// ============================================================================
// MSAL CONFIGURATION
// ============================================================================

const ciamAuthority = `https://${TENANT_ID}.ciamlogin.com/${TENANT_ID}`;

const msalConfig = {
    auth: {
        clientId: CLIENT_ID,
        authority: ciamAuthority,
        clientSecret: CLIENT_SECRET,
        knownAuthorities: [`${TENANT_ID}.ciamlogin.com`],
    },
    system: {
        loggerOptions: {
            loggerCallback(level, message, containsPii) {
                if (level <= msal.LogLevel.Warning && !containsPii) {
                    console.log('[MSAL]', message);
                }
            },
            piiLoggingEnabled: false,
            logLevel: msal.LogLevel.Warning,
        },
    },
};

const pca = new msal.ConfidentialClientApplication(msalConfig);

// Scopes to request
const SCOPES = ['openid', 'profile', 'email', 'offline_access'];

// ============================================================================
// ROUTE: GET /auth/oidc/login
// Initiates OAuth 2.0 authorization code flow
// ============================================================================

router.get('/login', async (req, res, next) => {
    try {
        const authUrl = await pca.getAuthCodeUrl({
            scopes: SCOPES,
            redirectUri: REDIRECT_URI,
            codeChallenge: req.query.code_challenge, // For PKCE (if provided by frontend)
            codeChallengeMethod: 'S256',              // PKCE method
        });

        // Optionally store state in session for CSRF protection
        req.session.authState = {
            codeVerifier: req.query.code_verifier || null,
            nonce: req.query.nonce || null,
            timestamp: Date.now(),
        };

        res.redirect(authUrl);
    } catch (error) {
        next(error);
    }
});

// ============================================================================
// ROUTE: GET /auth/oidc/redirect
// OAuth 2.0 callback endpoint - Entra posts authorization code here
// ============================================================================

router.get('/redirect', async (req, res, next) => {
    // Handle errors returned by Entra
    if (req.query.error) {
        const errorMsg = `${req.query.error}: ${req.query.error_description || 'Unknown error'}`;
        console.error('[OAuth Error]', errorMsg);
        return res.status(400).json({ error: errorMsg });
    }

    // Validate authorization code
    if (!req.query.code) {
        return res.status(400).json({ error: 'Missing authorization code' });
    }

    try {
        // Exchange authorization code for tokens
        const tokenResponse = await pca.acquireTokenByCode({
            code: req.query.code,
            scopes: SCOPES,
            redirectUri: REDIRECT_URI,
            codeVerifier: req.session.authState?.codeVerifier || undefined,
        });

        // Extract user identity from ID token claims
        const idTokenClaims = tokenResponse.idTokenClaims;

        // Store user info in session (security: store minimal info, not full tokens)
        req.session.user = {
            oid: idTokenClaims.oid,                      // User object ID
            sub: idTokenClaims.sub,                      // Subject (unique per app)
            email: idTokenClaims.email,                  // Primary email
            emailVerified: idTokenClaims.email_verified, // Email verification status
            name: idTokenClaims.name,                    // Full name
            givenName: idTokenClaims.given_name,        // First name
            familyName: idTokenClaims.family_name,      // Last name
            picture: idTokenClaims.picture,              // Profile picture URL
            locale: idTokenClaims.locale,                // Language/locale
            updatedAt: idTokenClaims.updated_at,         // Last update timestamp
        };

        // Store tokens for API calls (access token) and refresh (refresh token)
        req.session.tokens = {
            accessToken: tokenResponse.accessToken,
            expiresOn: tokenResponse.expiresOn,
            refreshToken: tokenResponse.refreshToken || null,
            tokenType: 'Bearer',
        };

        console.log(`✅ User authenticated: ${req.session.user.email}`);

        // Redirect to post-login page
        res.redirect('/profile');
    } catch (error) {
        console.error('[Token Exchange Error]', error);
        res.status(500).json({ error: 'Failed to exchange authorization code for tokens' });
    }
});

// ============================================================================
// ROUTE: GET /auth/oidc/refresh
// Refresh access token using refresh token
// ============================================================================

router.get('/refresh', async (req, res, next) => {
    try {
        if (!req.session.tokens?.refreshToken) {
            return res.status(401).json({ error: 'No refresh token available' });
        }

        const tokenResponse = await pca.acquireTokenByRefreshToken({
            refreshToken: req.session.tokens.refreshToken,
            scopes: SCOPES,
        });

        // Update tokens in session
        req.session.tokens = {
            accessToken: tokenResponse.accessToken,
            expiresOn: tokenResponse.expiresOn,
            refreshToken: tokenResponse.refreshToken || req.session.tokens.refreshToken,
            tokenType: 'Bearer',
        };

        res.json({ success: true, expiresIn: tokenResponse.expiresOn });
    } catch (error) {
        console.error('[Token Refresh Error]', error);
        req.session.tokens = null;
        res.status(401).json({ error: 'Failed to refresh token' });
    }
});

// ============================================================================
// ROUTE: GET /auth/oidc/logout
// Clear session and redirect to Entra sign-out endpoint
// ============================================================================

router.get('/logout', (req, res, next) => {
    req.session.destroy((err) => {
        if (err) return next(err);

        // Redirect to Entra sign-out endpoint
        const postLogoutUri = encodeURIComponent('http://localhost:3000/');
        const logoutUrl = `${ciamAuthority}/oauth2/v2.0/logout?post_logout_redirect_uri=${postLogoutUri}`;

        res.redirect(logoutUrl);
    });
});

// ============================================================================
// ROUTE: GET /auth/oidc/user-info
// Return current user information from session
// ============================================================================

router.get('/user-info', (req, res) => {
    if (!req.session.user) {
        return res.status(401).json({ error: 'Not authenticated' });
    }

    res.json(req.session.user);
});

// ============================================================================
// MIDDLEWARE: Require OIDC Authentication
// Use in routes that need authentication
// ============================================================================

router.requireAuth = (req, res, next) => {
    if (!req.session.user) {
        return res.redirect('/auth/oidc/login');
    }

    // Check if access token is expired
    if (req.session.tokens && req.session.tokens.expiresOn < Date.now()) {
        // Token expired, try to refresh
        return res.redirect('/auth/oidc/refresh');
    }

    next();
};

module.exports = router;
```

### 2. Configuration File

Create `.env`:

```bash
# Entra CIAM Configuration
TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
CLIENT_ID=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
CLIENT_SECRET=zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
REDIRECT_URI=http://localhost:3000/auth/oidc/redirect

# Application
NODE_ENV=development
PORT=3000
SESSION_SECRET=your-session-secret-change-in-production
```

### 3. Integration in Main App

Update `webapp/app.js`:

```javascript
require('dotenv').config();
const express = require('express');
const session = require('express-session');
const path = require('path');
const oidcAuthRouter = require('./routes/auth-oidc');

const app = express();
const PORT = process.env.PORT || 3000;

// Session middleware
app.use(session({
  secret: process.env.SESSION_SECRET || 'change-this-secret',
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: process.env.NODE_ENV === 'production',
    httpOnly: true,
    maxAge: 1000 * 60 * 60, // 1 hour
  }
}));

app.use(express.static(path.join(__dirname, 'views')));

// Mount OIDC auth routes at /auth/oidc
app.use('/auth/oidc', oidcAuthRouter);

// Public home page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'index.html'));
});

// Protected profile page
app.get('/profile', oidcAuthRouter.requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'profile.html'));
});

// API: Get current user profile
app.get('/api/me', oidcAuthRouter.requireAuth, (req, res) => {
  res.json(req.session.user);
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
  console.log(`OIDC Login: http://localhost:${PORT}/auth/oidc/login`);
  console.log(`Profile: http://localhost:${PORT}/profile`);
});
```

### 4. Frontend: HTML with Sign-In Button

Update `webapp/views/index.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Customer Portal - OIDC Auth</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            max-width: 600px;
            margin: 50px auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .card {
            background: white;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.2);
            text-align: center;
        }
        h1 { color: #333; margin-bottom: 10px; }
        p { color: #666; margin-bottom: 30px; }
        .btn {
            display: inline-block;
            padding: 12px 30px;
            font-size: 16px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            text-decoration: none;
            transition: all 0.3s;
        }
        .btn-primary {
            background: #667eea;
            color: white;
        }
        .btn-primary:hover {
            background: #764ba2;
            transform: translateY(-2px);
        }
        .protocol-badge {
            display: inline-block;
            background: #e3f2fd;
            color: #1976d2;
            padding: 4px 8px;
            border-radius: 3px;
            font-size: 12px;
            margin-bottom: 15px;
        }
    </style>
</head>
<body>
    <div class="card">
        <span class="protocol-badge">OAuth 2.0 / OpenID Connect</span>
        <h1>Welcome to Customer Portal</h1>
        <p>Sign in with your Entra External ID (CIAM) account</p>
        
        <a href="/auth/oidc/login" class="btn btn-primary">Sign In</a>
        
        <hr style="margin: 30px 0; border: none; border-top: 1px solid #eee;">
        
        <p style="font-size: 14px; color: #999;">
            🔐 Secured with OAuth 2.0 / OpenID Connect
        </p>
    </div>
</body>
</html>
```

---

## OIDC: Common Use Cases

### **1. Single-Page Application (SPA) with PKCE**

For React, Angular, or Vue apps, use MSAL.js:

```bash
npm install @azure/msal-browser @azure/msal-react
```

```javascript
// React example with MSAL.js
import { PublicClientApplication } from '@azure/msal-browser';
import { MsalProvider, useIsAuthenticated, useMsal } from '@azure/msal-react';

const msalConfig = {
    auth: {
        clientId: process.env.REACT_APP_CLIENT_ID,
        authority: `https://${process.env.REACT_APP_TENANT_ID}.ciamlogin.com/${process.env.REACT_APP_TENANT_ID}`,
        redirectUri: window.location.origin,
        knownAuthorities: [`${process.env.REACT_APP_TENANT_ID}.ciamlogin.com`],
    },
};

const msalInstance = new PublicClientApplication(msalConfig);

function SignInButton() {
    const { instance } = useMsal();
    const isAuthenticated = useIsAuthenticated();

    if (isAuthenticated) {
        return <LogoutButton />;
    }

    return (
        <button onClick={() => instance.loginPopup({
            scopes: ['openid', 'profile', 'email'],
            redirectUri: window.location.origin,
        })}>
            Sign In
        </button>
    );
}

export default function App() {
    return (
        <MsalProvider instance={msalInstance}>
            <SignInButton />
        </MsalProvider>
    );
}
```

### **2. Native Mobile App (iOS/Android)**

Use MSAL Mobile for platform-native integration with PKCE:

```swift
// iOS example using MSAL
import MSAL

let clientId = "your-client-id"
let authority = "https://{tenant-id}.ciamlogin.com/{tenant-id}"

let config = MSALPublicClientApplicationConfig(
    clientId: clientId,
    redirectUri: "msauth.com.contoso.customerapp://auth",
    authority: try MSALAuthority(url: URL(string: authority)!)
)

let application = try MSALPublicClientApplication(configuration: config)

// Acquire token interactively
let scopes = ["openid", "profile", "email", "offline_access"]
let parameters = MSALInteractiveTokenParameters(scopes: scopes)

application.acquireToken(with: parameters) { result, error in
    guard error == nil else {
        print("Token acquisition failed: \(error!)")
        return
    }
    
    guard let result = result else { return }
    print("User: \(result.account.username)")
    print("ID Token: \(result.idToken)")
    print("Access Token: \(result.accessToken)")
}
```

### **3. Backend API (Daemon/Service-to-Service)**

For backend services that don't need user interaction, use Client Credentials Flow:

```javascript
const { ConfidentialClientApplication } = require('@azure/msal-node');

const cca = new ConfidentialClientApplication({
    auth: {
        clientId: process.env.CLIENT_ID,
        clientSecret: process.env.CLIENT_SECRET,
        authority: `https://${process.env.TENANT_ID}.ciamlogin.com/${process.env.TENANT_ID}`,
    }
});

// Get access token for API calls
async function getAccessToken() {
    const result = await cca.acquireTokenByClientCredential({
        scopes: ['https://graph.microsoft.com/.default'],
    });
    return result.accessToken;
}
```

---

# SAML 2.0

## Overview

**SAML 2.0 (Security Assertion Markup Language)** is an XML-based standard for federated authentication. It's ideal for enterprise customers who use identity providers like Okta, PingFederate, or have on-premises Active Directory Federation Services.

### Key Concepts

- **Service Provider (SP)**: Entra (your application platform)
- **Identity Provider (IdP)**: Customer's auth system (Okta, PingFederate, etc.)
- **SAML Assertion**: XML-signed claim about user identity
- **Metadata**: XML describing endpoints, certificates, and configuration
- **POST Binding**: Form-based SAML response delivery
- **Redirect Binding**: URL-based SAML request delivery

### Supported Identity Providers

- **Okta**
- **PingFederate**
- **JumpCloud**
- **Auth0** (in SAML mode)
- **Generic SAML 2.0** providers
- **Any SAML 2.0 compliant IdP**

### SAML Response Structure

```xml
<samlp:Response xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol" 
                 ID="_8e8dc5f69a98cc4c1ff3427e5ce34606fd672f91e6">
    <saml:Issuer xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion">
        https://idp.example.com
    </saml:Issuer>
    <samlp:Status>
        <samlp:StatusCode Value="urn:oasis:names:tc:SAML:2.0:status:Success" />
    </samlp:Status>
    <saml:Assertion ID="_d71a3a8c4dcb5d7c7e4f3e6f9a8e9b3f7e2c7f4a" 
                   Version="2.0" 
                   IssueInstant="2024-01-15T10:30:45Z">
        <saml:Issuer>https://idp.example.com</saml:Issuer>
        <ds:Signature>...</ds:Signature>
        <saml:Subject>
            <saml:NameID Format="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent">
                user@example.com
            </saml:NameID>
            <saml:SubjectConfirmation Method="urn:oasis:names:tc:SAML:2.0:cm:bearer">
                <saml:SubjectConfirmationData 
                    NotOnOrAfter="2024-01-15T10:35:45Z"
                    Recipient="https://tenant-id.ciamlogin.com/login.srf" />
            </saml:SubjectConfirmation>
        </saml:Subject>
        <saml:Conditions NotBefore="2024-01-15T10:25:45Z" 
                        NotOnOrAfter="2024-01-15T10:35:45Z">
            <saml:AudienceRestriction>
                <saml:Audience>https://login.microsoftonline.com/tenant-id/</saml:Audience>
            </saml:AudienceRestriction>
        </saml:Conditions>
        <saml:AuthnStatement AuthnInstant="2024-01-15T10:30:45Z">
            <saml:AuthnContext>
                <saml:AuthnContextClassRef>
                    urn:oasis:names:tc:SAML:2.0:ac:classes:Password
                </saml:AuthnContextClassRef>
            </saml:AuthnContext>
        </saml:AuthnStatement>
        <saml:AttributeStatement>
            <saml:Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress">
                <saml:AttributeValue>user@contoso.com</saml:AttributeValue>
            </saml:Attribute>
            <saml:Attribute Name="http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname">
                <saml:AttributeValue>John</saml:AttributeValue>
            </saml:Attribute>
        </saml:AttributeStatement>
    </saml:Assertion>
</samlp:Response>
```

---

## Azure Portal: Configure SAML 2.0 Enterprise Application

### Step 1: Create Enterprise Application

1. Navigate to **Entra Admin Center** → [https://entra.microsoft.com](https://entra.microsoft.com)
2. Select your **External (CIAM) tenant**
3. Go to **Identity** → **Applications** → **Enterprise applications**
4. Click **+ New application**
5. Select **+ Create your own application**
6. Configure:
   - **Name**: `Okta Partner` (or your IdP name)
   - **What are you looking to do with your application?**: Select **Integrate any other application you don't find in the gallery**
7. Click **Create**

### Step 2: Configure SAML Single Sign-On

1. In the enterprise app, go to **Single sign-on** (left menu)
2. Click **SAML** (or select from options)
3. In **Set up Single Sign-On with SAML**, click **Upload metadata file** OR configure manually:

**Option A: Upload Metadata File (Recommended)**

1. Download SAML metadata from your IdP (Okta, PingFederate, etc.)
2. Click **Upload metadata file**
3. Select the metadata XML file
4. Entra automatically extracts:
   - Issuer URI
   - Single Sign-On Service URL
   - Certificates
5. Click **Next**

**Option B: Configure Manually**

1. In **Basic SAML Configuration**, click **Edit**
2. Configure these fields:
   - **Identifier (Entity ID)**: `https://login.microsoftonline.com/{tenant-id}/`
   - **Reply URL (Assertion Consumer Service URL)**: `https://{tenant-id}.ciamlogin.com/login.srf`
   - **Sign on URL**: (optional, for IdP-initiated sign-on) `https://{tenant-id}.ciamlogin.com/login.srf`
3. Click **Save**

### Step 3: Download Certificate & Metadata

1. In **SAML Signing Certificate** section, download:
   - **Certificate (Base64)**: `Federation Metadata XML` (recommended)
   - **App Federation Metadata URL**: Copy this URL
2. Provide these to your IdP administrator:
   - Federation Metadata URL
   - OR the downloaded certificate in their format

### Step 4: Configure Attribute Mapping

1. In **Attributes & Claims**, click **Edit**
2. Ensure these required claims are mapped:

| Claim | Source Attribute | Required |
|-------|---|---|
| `email` | `user.mail` or `user.userprincipalname` | ✅ Yes |
| `givenname` | `user.givenname` | ⚠️ Recommended |
| `surname` | `user.surname` | ⚠️ Recommended |
| `name` | `user.displayname` | ⚠️ Recommended |

3. Under **User Attributes & Claims**, verify **Unique User Identifier (Name ID)**:
   - Set to: `user.mail` (persistent identifier)
   - Format: `urn:oasis:names:tc:SAML:2.0:nameid-format:persistent`

### Step 5: Test SAML Configuration

1. Go to **Test** (or **Test single sign-on with Okta**)
2. Click **Test single sign-on**
3. Sign in with an enterprise identity
4. Verify successful authentication

### Step 6: Add to User Flow

1. Navigate to **External Identities** → **User flows**
2. Select your sign-up/sign-in user flow
3. Go to **Identity providers** (or **Settings** → **Identity providers**)
4. Click **+ Add SAML identity provider** (or **+ Add identity provider**)
5. Select the enterprise application you created
6. Click **Save**

---

## PowerShell: Configure SAML Enterprise Application

Create file: `scripts/CIAM/Register-CIAMSAMLApp.ps1`

```powershell
<#
.SYNOPSIS
    Register and configure a SAML 2.0 enterprise application for Entra CIAM.

.PARAMETER DisplayName
    Name of the enterprise application (e.g., "Okta Partner").

.PARAMETER MetadataUrl
    SAML metadata URL from your IdP (e.g., "https://idp.example.com/metadata").

.PARAMETER SignOnUrl
    (Optional) IdP sign-on URL for SP-initiated flow.

.EXAMPLE
    .\Register-CIAMSAMLApp.ps1 `
        -DisplayName "Okta Partner" `
        -MetadataUrl "https://contoso.okta.com/app/exk.../sso/saml/metadata"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $false)]
    [string]$MetadataUrl,

    [Parameter(Mandatory = $false)]
    [string]$SignOnUrl
)

# Connect to Microsoft Graph if not already connected
$context = Get-MgContext
if (-not $context) {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"
}

Write-Host "Registering SAML enterprise application: $DisplayName" -ForegroundColor Cyan

# Get current tenant ID
$tenant = Get-MgOrganization | Select-Object -ExpandProperty Id

# Create enterprise application (service principal only, no app registration)
$displayNameValue = $DisplayName
$sp = New-MgServicePrincipal -DisplayName $displayNameValue -AccountEnabled $true

Write-Host "✅ Enterprise application created: $($sp.Id)" -ForegroundColor Green
Write-Host "   Display Name: $($sp.DisplayName)" -ForegroundColor White

# Configure SAML properties
$samlSingleSignOnSettings = @{
    singularSignOutUrl = "https://$tenant.ciamlogin.com/logout.srf"
}

# Update service principal with SAML settings
Update-MgServicePrincipal -ServicePrincipalId $sp.Id `
    -SamlSingleSignOnSettings $samlSingleSignOnSettings

Write-Host "✅ SAML Single Sign-On settings configured" -ForegroundColor Green

# Download or configure metadata if provided
if ($MetadataUrl) {
    Write-Host "📥 Downloading SAML metadata from: $MetadataUrl" -ForegroundColor Cyan
    try {
        $metadata = Invoke-WebRequest -Uri $MetadataUrl -ErrorAction Stop
        Write-Host "✅ Metadata downloaded successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "⚠️  Could not download metadata automatically" -ForegroundColor Yellow
        Write-Host "   Please download manually from IdP and upload to Azure Portal" -ForegroundColor White
    }
}

# Output configuration summary
Write-Host "`n📋 Configuration Summary:" -ForegroundColor Cyan
Write-Host "  Enterprise App ID: $($sp.Id)" -ForegroundColor White
Write-Host "  App Name: $($sp.DisplayName)" -ForegroundColor White
Write-Host "  Tenant ID: $tenant" -ForegroundColor White
Write-Host "  Reply URL (ACS): https://$tenant.ciamlogin.com/login.srf" -ForegroundColor White
Write-Host "  Entity ID (Audience): https://login.microsoftonline.com/$tenant/" -ForegroundColor White
Write-Host "  Sign-Out URL: https://$tenant.ciamlogin.com/logout.srf" -ForegroundColor White

if ($MetadataUrl) {
    Write-Host "  IdP Metadata URL: $MetadataUrl" -ForegroundColor White
}

Write-Host "`n⏭️  Next Steps:" -ForegroundColor Cyan
Write-Host "1. Download certificate from Azure Portal (SAML Signing Certificate section)" -ForegroundColor White
Write-Host "2. Provide to your IdP administrator" -ForegroundColor White
Write-Host "3. Add to user flows in External Identities → User flows" -ForegroundColor White
Write-Host "4. Test SAML SSO from Azure Portal" -ForegroundColor White
```

### Usage

```powershell
# Connect to CIAM tenant
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"

# Register SAML app
.\Register-CIAMSAMLApp.ps1 `
    -DisplayName "Okta Partner" `
    -MetadataUrl "https://contoso.okta.com/app/exk.../sso/saml/metadata"
```

---

## Node.js/Express: Validate SAML Assertions

Create file: `webapp/routes/auth-saml.js`

```javascript
/**
 * SAML 2.0 authentication route handler
 * 
 * Validates SAML assertions from enterprise IdPs
 * and establishes user sessions.
 */

const express = require('express');
const { validateAsync } = require('@saml-federation/saml2-utils');
const xml2js = require('xml2js');
const fs = require('fs');
const router = express.Router();

// ============================================================================
// CONFIGURATION FROM ENVIRONMENT
// ============================================================================

const {
    TENANT_ID,              // CIAM tenant ID
    SAML_CERT_PATH,        // Path to IdP's signing certificate
    SAML_ENTITY_ID,        // Service provider entity ID
    SAML_ASSERTION_CONSUMER_SERVICE_URL,  // ACS endpoint URL
} = process.env;

// Read IdP signing certificate
let idpCertificate;
if (SAML_CERT_PATH) {
    idpCertificate = fs.readFileSync(SAML_CERT_PATH, 'utf8');
}

// ============================================================================
// ROUTE: POST /auth/saml/acs
// SAML Assertion Consumer Service (ACS)
// IdP POSTs signed SAML assertion here after user authenticates
// ============================================================================

router.post('/acs', express.urlencoded({ extended: false }), async (req, res) => {
    try {
        const samlResponse = req.body.SAMLResponse;

        if (!samlResponse) {
            return res.status(400).json({ error: 'Missing SAML response' });
        }

        // Decode Base64-encoded SAML response
        const decodedSaml = Buffer.from(samlResponse, 'base64').toString('utf8');

        // Parse XML SAML assertion
        const parser = new xml2js.Parser();
        const parsedSaml = await parser.parseStringPromise(decodedSaml);

        // Extract user claims from SAML assertion
        const assertion = parsedSaml['samlp:Response']['saml:Assertion'][0];
        const attributeStatement = assertion['saml:AttributeStatement'][0];
        const attributes = attributeStatement['saml:Attribute'];

        // Map SAML attributes to user object
        const user = {};
        attributes.forEach(attr => {
            const name = attr.$.Name;
            const value = attr['saml:AttributeValue'][0];

            // Common SAML attribute mappings
            switch (name) {
                case 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress':
                    user.email = value;
                    break;
                case 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname':
                    user.givenName = value;
                    break;
                case 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname':
                    user.familyName = value;
                    break;
                case 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name':
                    user.name = value;
                    break;
                case 'http://schemas.microsoft.com/ws/2008/06/identity/claims/objectidentifier':
                    user.oid = value;
                    break;
                default:
                    // Store other attributes with sanitized names
                    const cleanName = name.split('/').pop();
                    user[cleanName] = value;
            }
        });

        // Validate required claims
        if (!user.email) {
            return res.status(400).json({ error: 'Missing email claim in SAML assertion' });
        }

        // Extract persistent user identifier (NameID)
        const nameId = assertion['saml:Subject'][0]['saml:NameID'][0];
        user.sub = nameId;  // Subject/persistent ID

        // Store user in session
        req.session.user = user;
        req.session.authProtocol = 'SAML 2.0';

        console.log(`✅ SAML user authenticated: ${user.email}`);

        // Redirect to post-login page
        res.redirect('/profile');
    } catch (error) {
        console.error('[SAML Validation Error]', error);
        res.status(400).json({ error: 'SAML assertion validation failed' });
    }
});

// ============================================================================
// ROUTE: POST /auth/saml/logout
// Service provider-initiated logout
// ============================================================================

router.post('/logout', (req, res) => {
    req.session.destroy((err) => {
        if (err) return res.status(500).json({ error: 'Logout failed' });
        
        // Optionally send SAML LogoutRequest to IdP
        // (IdP-initiated logout is more common)
        
        res.json({ success: true });
    });
});

// ============================================================================
// ROUTE: GET /auth/saml/login
// Initiate SAML authentication
// Redirects user to IdP sign-in page
// ============================================================================

router.get('/login', (req, res) => {
    // In SAML, the IdP typically initiates the flow
    // This endpoint can generate a SAML AuthnRequest if needed
    
    // For now, redirect to a page explaining SAML flow
    res.json({
        message: 'SAML authentication initiated',
        note: 'User should be redirected from IdP to /auth/saml/acs after authentication'
    });
});

// ============================================================================
// MIDDLEWARE: Require SAML Authentication
// ============================================================================

router.requireAuth = (req, res, next) => {
    if (!req.session.user || req.session.authProtocol !== 'SAML 2.0') {
        return res.status(401).json({ error: 'Not authenticated' });
    }
    next();
};

module.exports = router;
```

### Configuration

Create `.env` for SAML:

```bash
# SAML Configuration
TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
SAML_ENTITY_ID=https://login.microsoftonline.com/{TENANT_ID}/
SAML_ASSERTION_CONSUMER_SERVICE_URL=https://{TENANT_ID}.ciamlogin.com/login.srf
SAML_CERT_PATH=./certs/idp-signing-cert.pem
```

---

## SAML 2.0: Common Use Cases

### **Use Case 1: Okta Federation**

Okta is one of the most common enterprise IdPs. Here's how to set up SAML with Okta:

**In Okta Dashboard**:

1. Go to **Applications** → **Applications**
2. Click **Create App Integration**
3. Select **SAML 2.0** as the Sign-on method
4. Configure:
   - **App name**: `Entra CIAM`
   - **Single sign on URL**: `https://{tenant-id}.ciamlogin.com/login.srf`
   - **Audience URI (SP Entity ID)**: `https://login.microsoftonline.com/{tenant-id}/`
   - **Name ID format**: `Persistent`
   - **Application username**: `Email`

**Attribute Mappings** (Okta to Entra):

| Okta Source | SAML Attribute |
|---|---|
| `user.email` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress` |
| `user.firstName` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname` |
| `user.lastName` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname` |
| `user.displayName` | `http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name` |

**In Entra Portal**:

1. Download Okta metadata from **Sign On** tab
2. In Entra enterprise app, upload the metadata
3. Verify certificate is automatically imported
4. Add to user flows

---

### **Use Case 2: PingFederate Integration**

PingFederate is another enterprise federation platform. Setup follows similar patterns:

1. Create SAML Service Provider in PingFederate
2. Download metadata URL: `https://pingfed.example.com/idp/metadata`
3. Upload to Entra enterprise app
4. Configure attribute mappings (same as Okta above)
5. Test SSO

---

# WS-Federation

## Overview

**WS-Federation** is a legacy protocol primarily used for on-premises Active Directory Federation Services (AD FS) and Shibboleth. It uses XML-based security tokens and is being superseded by modern protocols but remains necessary for legacy enterprise scenarios.

### Key Concepts

- **Passive Requester Endpoint**: The login endpoint (equivalent to SAML's ACS)
- **WS-Trust**: Underlying protocol for token exchange
- **Security Token Service (STS)**: The component that issues tokens
- **Realm/Issuer**: Identifier for the federation realm
- **Claims**: User attributes in the security token

### Supported Identity Providers

- **Active Directory Federation Services (AD FS)** ✅ Primary
- **Shibboleth** ✅ Tested
- **Generic WS-Federation** endpoints

---

## Azure Portal: Configure WS-Federation

### Step 1: Create Enterprise Application

1. Navigate to **Entra Admin Center** → [https://entra.microsoft.com](https://entra.microsoft.com)
2. Select your **External (CIAM) tenant**
3. Go to **Identity** → **Applications** → **Enterprise applications**
4. Click **+ New application**
5. Select **+ Create your own application**
6. Configure:
   - **Name**: `AD FS Partner` (or your WS-Fed provider)
   - **What are you looking to do?**: Select **Integrate any other application you don't find in the gallery**
7. Click **Create**

### Step 2: Configure WS-Federation

1. In the enterprise app, go to **Single sign-on**
2. Click the dropdown → Select **WS-Federation** OR **SAML (if WS-Fed is listed)*
3. Configure **Basic WS-Federation Configuration**:
   - **Identifier (Realm)**: `https://login.microsoftonline.com/{tenant-id}/`
   - **Reply URL (Assertion Consumer Service)**: `https://{tenant-id}.ciamlogin.com/login.srf`
   - **Sign on URL**: `https://{idp}.example.com/adfs/ls/` (your AD FS login page)
   - **Logout URL**: `https://{idp}.example.com/adfs/ls/?wa=wsignout1.0`

### Step 3: Upload Certificates

1. In **WS-Federation Signing Certificate**:
   - Click **Upload certificate** from your AD FS server
   - Or paste the certificate in PEM format

### Step 4: Test WS-Federation

1. Click **Test** or **Test single sign-on**
2. Attempt to sign in
3. Verify successful authentication from AD FS

---

## PowerShell: Configure WS-Federation

Create file: `scripts/CIAM/Register-CIAMWSFedApp.ps1`

```powershell
<#
.SYNOPSIS
    Register and configure WS-Federation for Entra CIAM (legacy AD FS integration).

.PARAMETER DisplayName
    Name of the enterprise application (e.g., "AD FS Partner").

.PARAMETER Realm
    WS-Federation Realm identifier (e.g., "https://login.microsoftonline.com/tenant-id/").

.PARAMETER PassiveEndpoint
    Passive Requester Endpoint from AD FS (e.g., "https://adfs.example.com/adfs/ls/").

.EXAMPLE
    .\Register-CIAMWSFedApp.ps1 `
        -DisplayName "AD FS Partner" `
        -Realm "https://login.microsoftonline.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/" `
        -PassiveEndpoint "https://adfs.example.com/adfs/ls/"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$DisplayName,

    [Parameter(Mandatory = $true)]
    [string]$Realm,

    [Parameter(Mandatory = $true)]
    [string]$PassiveEndpoint
)

# Connect to Microsoft Graph if not already connected
$context = Get-MgContext
if (-not $context) {
    Write-Host "Connecting to Microsoft Graph..."
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"
}

Write-Host "Registering WS-Federation enterprise application: $DisplayName" -ForegroundColor Cyan

# Create enterprise application
$sp = New-MgServicePrincipal -DisplayName $DisplayName -AccountEnabled $true

Write-Host "✅ Enterprise application created: $($sp.Id)" -ForegroundColor Green

# Configure WS-Federation properties
$wsFedSettings = @{
    metadataExchangeUri = "$PassiveEndpoint/metadata"
    passiveSignInUri    = $PassiveEndpoint
    signOutUri          = "$PassiveEndpoint/?wa=wsignout1.0"
}

Write-Host "📝 WS-Federation configuration:" -ForegroundColor Cyan
Write-Host "  Realm: $Realm" -ForegroundColor White
Write-Host "  Passive Endpoint: $PassiveEndpoint" -ForegroundColor White
Write-Host "  Metadata URI: $($wsFedSettings.metadataExchangeUri)" -ForegroundColor White

# Output summary
Write-Host "`n📋 Configuration Summary:" -ForegroundColor Cyan
Write-Host "  Enterprise App ID: $($sp.Id)" -ForegroundColor White
Write-Host "  App Name: $($sp.DisplayName)" -ForegroundColor White
Write-Host "  Realm: $Realm" -ForegroundColor White
Write-Host "  Passive Sign-In URL: $PassiveEndpoint" -ForegroundColor White
Write-Host "  Reply URL (ACS): https://{tenant-id}.ciamlogin.com/login.srf" -ForegroundColor White

Write-Host "`n⏭️  Next Steps:" -ForegroundColor Cyan
Write-Host "1. Download certificate from Azure Portal (if not auto-imported)" -ForegroundColor White
Write-Host "2. Provide certificate to AD FS administrator" -ForegroundHost White
Write-Host "3. Configure WS-Federation endpoint in AD FS" -ForegroundColor White
Write-Host "4. Add to user flows" -ForegroundColor White
```

### Usage

```powershell
# Connect to CIAM tenant
Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"

# Register WS-Federation app
.\Register-CIAMWSFedApp.ps1 `
    -DisplayName "AD FS Partner" `
    -Realm "https://login.microsoftonline.com/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/" `
    -PassiveEndpoint "https://adfs.example.com/adfs/ls/"
```

---

## Node.js/Express: Handle WS-Federation Tokens

Create file: `webapp/routes/auth-wsfed.js`

```javascript
/**
 * WS-Federation authentication route handler
 * 
 * Handles WS-Federation tokens from AD FS or other WS-Fed providers.
 */

const express = require('express');
const xml2js = require('xml2js');
const router = express.Router();

// ============================================================================
// CONFIGURATION
// ============================================================================

const {
    TENANT_ID,
    WSFED_REALM,              // Realm identifier
    WSFED_METADATA_URL,       // Metadata endpoint from AD FS
} = process.env;

// ============================================================================
// ROUTE: POST /auth/wsfed/acs
// WS-Federation Assertion Consumer Service
// Receives signed security token from AD FS
// ============================================================================

router.post('/acs', express.urlencoded({ extended: false }), async (req, res) => {
    try {
        const wresult = req.body.wresult;  // WS-Federation security token (XML)

        if (!wresult) {
            return res.status(400).json({ error: 'Missing WS-Federation token' });
        }

        // Decode Base64-encoded token
        const decodedToken = Buffer.from(wresult, 'base64').toString('utf8');

        // Parse XML security token
        const parser = new xml2js.Parser();
        const parsedToken = await parser.parseStringPromise(decodedToken);

        // Extract claims from WS-Federation RequestSecurityTokenResponse
        const assertionNode = parsedToken['wst:RequestSecurityTokenResponseCollection']['wst:RequestSecurityTokenResponse'][0];
        const tokenNode = assertionNode['wst:TokenType'];

        // Parse nested SAML assertion (WS-Fed uses SAML assertions)
        const samlNode = assertionNode['saml:Assertion'] || 
                        assertionNode['Assertion'];

        // Extract attributes
        const user = {};
        if (samlNode && samlNode[0]) {
            const attributes = samlNode[0]['saml:AttributeStatement'];
            
            if (attributes && attributes[0]) {
                attributes[0]['saml:Attribute'].forEach(attr => {
                    const name = attr.$.Name;
                    const value = attr['saml:AttributeValue'][0];

                    // Map claim names to user properties
                    switch (name) {
                        case 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress':
                            user.email = value;
                            break;
                        case 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname':
                            user.givenName = value;
                            break;
                        case 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname':
                            user.familyName = value;
                            break;
                        case 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name':
                            user.name = value;
                            break;
                        default:
                            const cleanName = name.split('/').pop();
                            user[cleanName] = value;
                    }
                });
            }
        }

        // Require email
        if (!user.email) {
            return res.status(400).json({ error: 'Missing email claim in WS-Federation token' });
        }

        // Store user in session
        req.session.user = user;
        req.session.authProtocol = 'WS-Federation';

        console.log(`✅ WS-Federation user authenticated: ${user.email}`);

        // Redirect post-login
        res.redirect('/profile');
    } catch (error) {
        console.error('[WS-Federation Error]', error);
        res.status(400).json({ error: 'WS-Federation token validation failed' });
    }
});

// ============================================================================
// ROUTE: GET /auth/wsfed/login
// Initiate WS-Federation sign-in
// ============================================================================

router.get('/login', (req, res) => {
    // WS-Federation uses a passive flow - redirect to AD FS
    const signinUrl = new URL('https://adfs.example.com/adfs/ls/');
    signinUrl.searchParams.append('wa', 'wsignin1.0');
    signinUrl.searchParams.append('wtrealm', WSFED_REALM);
    signinUrl.searchParams.append('wctx', encodeURIComponent(`http://localhost:3000/auth/wsfed/acs`));

    res.redirect(signinUrl.toString());
});

// ============================================================================
// MIDDLEWARE: Require WS-Federation Authentication
// ============================================================================

router.requireAuth = (req, res, next) => {
    if (!req.session.user || req.session.authProtocol !== 'WS-Federation') {
        return res.status(401).json({ error: 'Not authenticated via WS-Federation' });
    }
    next();
};

module.exports = router;
```

---

# Provider-Specific Examples

## OAuth 2.0 / OIDC: Google Federation

### Configure Google as Identity Provider

1. **In Google Cloud Console** → [https://console.cloud.google.com](https://console.cloud.google.com):
   - Create OAuth 2.0 credentials
   - Application type: **Web application**
   - Authorized redirect URIs:
     ```
     https://{tenant-id}.ciamlogin.com/login.srf
     https://{tenant-id}.ciamlogin.com/oauth/authorization-code/callback
     ```
   - Note: **Client ID** and **Client Secret**

2. **In Entra Portal** → External Identities → Identity providers → Add new OIDC provider:
   - **Name**: `Google`
   - **Client ID**: (from Google Cloud)
   - **Client Secret**: (from Google Cloud)
   - **Well-known configuration endpoint**: `https://accounts.google.com/.well-known/openid-configuration`
   - **Scope**: `openid profile email`

3. **Add to User Flow**:
   - Edit sign-up/sign-in user flow
   - Add Google as identity provider

### Testing

```javascript
// User clicks "Sign in with Google"
// → Redirected to Google login
// → Returns to Entra with ID token
// → Entra creates user or links account
```

---

## SAML 2.0: JumpCloud Federation

### Configure JumpCloud as IdP

1. **In JumpCloud Admin Console** → Applications → SAML:
   - Create new SAML app
   - **Service Provider URL (ACS)**: `https://{tenant-id}.ciamlogin.com/login.srf`
   - **Entity ID**: `https://login.microsoftonline.com/{tenant-id}/`

2. **Attribute Mapping**:
   - `email` → `userEmail`
   - `givenName` → `firstname`
   - `surname` → `lastname`

3. **Download metadata** from JumpCloud

4. **In Entra Portal**:
   - Upload JumpCloud metadata to enterprise app
   - Verify certificate imported
   - Add to user flows

---

## WS-Federation: AD FS Integration

### Configure Entra as Relying Party in AD FS

**On AD FS Server**:

```powershell
# Add Relying Party Trust for Entra CIAM
Add-ADFSRelyingPartyTrust `
    -Name "Entra CIAM" `
    -MonitoringEnabled $true `
    -MetadataURL "https://{tenant-id}.ciamlogin.com/federationmetadata/2007-06/federationmetadata.xml"

# Configure claim rules
Add-ADFSClaimRuleGroup `
    -TargetRelyingPartyName "Entra CIAM" `
    -ClaimRuleName "Send Email" `
    -ClaimRuleTemplate "SendClaims" `
    -TargetClaim "email" `
    -SourceClaim "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
```

**In Entra Portal**:

1. Create enterprise application (as described above)
2. Configure WS-Federation with AD FS endpoint
3. Add to user flows

---

# Security Best Practices

## OAuth 2.0 / OIDC Security

### ✅ Recommended Practices

1. **Always Use PKCE** (Proof Key for Code Exchange)
   - Especially for single-page apps and native apps
   - Prevents authorization code interception attacks
   
   ```javascript
   // PKCE implementation
   const crypto = require('crypto');
   const codeVerifier = crypto.randomBytes(32).toString('hex');
   const codeChallenge = crypto.createHash('sha256')
       .update(codeVerifier)
       .digest('base64url');
   ```

2. **Validate ID Token**
   - Verify signature using public key from OIDC Discovery endpoint
   - Check `aud` (audience) matches your client ID
   - Check `iss` (issuer) matches expected issuer
   - Verify `exp` (expiration) is in the future

3. **Use Authorization Code Flow**
   - Never use Implicit flow
   - ROPC (Resource Owner Password Credentials) is deprecated

4. **Secure Token Storage**
   - Backend: Session storage is acceptable
   - Browser: Store only in memory (not localStorage)
   - Mobile: Use platform-specific secure storage (Keychain, Keystore)

5. **Short-Lived Access Tokens**
   - Access tokens: 1 hour expiration
   - Refresh tokens: Longer expiration (days/weeks)
   - Monitor refresh token usage for anomalies

6. **HTTPS Only**
   - All OAuth flows must use HTTPS in production
   - TLS 1.2 minimum

7. **Enable Conditional Access**
   - Require MFA for sensitive operations
   - Monitor risky sign-ins
   - Block impossible travel

---

## SAML 2.0 Security

### ✅ Recommended Practices

1. **Validate XML Signatures**
   - Use signed assertions
   - Verify signature with IdP's public certificate
   - Check certificate validity period

2. **Encrypt Assertions**
   - Use encrypted assertions for sensitive user data
   - Configure encryption certificates in Entra

3. **Validate SAML Response Attributes**
   - Check `Issuer` matches expected IdP
   - Verify `Recipient` equals your ACS URL
   - Validate timestamps (`NotBefore`, `NotOnOrAfter`)
   - Check `InResponseTo` matches request ID

4. **Use Persistent NameID Format**
   - `urn:oasis:names:tc:SAML:2.0:nameid-format:persistent`
   - Prevents user identification issues

5. **Enable Signed AuthnRequests**
   - Sign your SAML AuthnRequests to IdP
   - Prevents request tampering

6. **Certificate Management**
   - Use metadata URL for automatic certificate rotation
   - Monitor certificate expiration
   - Implement key rotation policies

7. **Single Logout (SLO)**
   - Implement SAML Single Logout
   - Ensure user sessions are terminated across all systems

---

## WS-Federation Security

### ✅ Recommended Practices

1. **Validate Token Signatures**
   - Verify X.509 certificate signature
   - Check certificate chain validity
   - Use certificate pinning for high-security scenarios

2. **Check Token Timestamps**
   - Validate `Created` and `Expires` attributes
   - Prevent token replay attacks

3. **Validate Realm**
   - Ensure `Realm` matches your configured realm
   - Prevents tokens from other applications from being accepted

4. **Use Encrypted Tokens**
   - Configure encrypted security tokens in AD FS
   - Protects token content in transit

5. **Monitor AD FS Logs**
   - Enable audit logging
   - Monitor for failed authentication attempts
   - Alert on certificate expiration

---

## Universal Security Practices

### All Protocols

1. **Content Security Policy (CSP)**
   ```html
   <meta http-equiv="Content-Security-Policy" 
         content="default-src 'self'; script-src 'self' https://trusted-cdn.com; connect-src 'self' https://*.ciamlogin.com">
   ```

2. **X-Frame-Options** (prevent clickjacking)
   ```javascript
   app.use((req, res, next) => {
       res.setHeader('X-Frame-Options', 'DENY');
       next();
   });
   ```

3. **Rate Limiting**
   ```javascript
   const rateLimit = require('express-rate-limit');
   const limiter = rateLimit({
       windowMs: 15 * 60 * 1000,  // 15 minutes
       max: 100  // limit each IP to 100 requests per windowMs
   });
   app.use('/auth', limiter);
   ```

4. **CSRF Protection**
   - Use state parameter (OIDC/SAML)
   - Verify nonce for XSS protection

5. **Log Security Events**
   - Track authentication failures
   - Monitor token refresh patterns
   - Alert on suspicious activities

6. **Regular Security Audits**
   - Review access logs quarterly
   - Penetration testing annually
   - Certificate audits

---

# Testing & Validation

## End-to-End Testing Checklist

### OAuth 2.0 / OIDC

- [ ] **Sign-Up Flow**
  - [ ] User can register with email
  - [ ] Email verification works
  - [ ] User attributes are correctly mapped
  - [ ] Session is created after sign-up

- [ ] **Sign-In Flow**
  - [ ] User can sign in with credentials
  - [ ] Access token is returned
  - [ ] ID token contains correct claims
  - [ ] Refresh token works
  - [ ] Session remains valid

- [ ] **Social Provider Integration**
  - [ ] Google sign-in works
  - [ ] Facebook sign-in works
  - [ ] User is linked to existing account (if applicable)
  - [ ] Profile picture and attributes are imported

- [ ] **API Access**
  - [ ] Access token can be used to call backend API
  - [ ] Expired access token can be refreshed
  - [ ] Invalid token is rejected

- [ ] **Sign-Out**
  - [ ] Session is cleared
  - [ ] User is redirected to sign-out page
  - [ ] Token is invalidated

- [ ] **Security**
  - [ ] PKCE is used
  - [ ] HTTPS enforced
  - [ ] CSRF token validated
  - [ ] Token expiration enforced

### SAML 2.0

- [ ] **SAML Metadata**
  - [ ] Metadata URL is accessible
  - [ ] Metadata contains correct endpoints
  - [ ] Certificate is valid

- [ ] **Assertion Validation**
  - [ ] Signature is valid
  - [ ] Required claims present (email, name)
  - [ ] NameID is persistent
  - [ ] Timestamps are valid

- [ ] **User Provisioning**
  - [ ] User is created on first sign-in
  - [ ] User attributes are mapped correctly
  - [ ] Email attribute is required and unique

- [ ] **Logout**
  - [ ] Single logout (SLO) works
  - [ ] Session cleared on both IdP and SP
  - [ ] User is logged out from all sessions

- [ ] **Error Handling**
  - [ ] Invalid assertions are rejected
  - [ ] Certificate expiration is handled
  - [ ] Metadata errors are logged

### WS-Federation

- [ ] **Token Validation**
  - [ ] Token signature is valid
  - [ ] Token is not expired
  - [ ] Token realm matches configuration
  - [ ] Required claims are present

- [ ] **User Provisioning**
  - [ ] User is created from token claims
  - [ ] Attributes map correctly
  - [ ] Persistent identifier (NameID) works

- [ ] **Federation Metadata**
  - [ ] Metadata endpoint is accessible
  - [ ] Certificates are auto-imported
  - [ ] Endpoints are correct

---

## Testing Tools & Commands

### Test OIDC Configuration

```bash
# Test OIDC Discovery endpoint
curl -X GET "https://{tenant-id}.ciamlogin.com/{tenant-id}/v2.0/.well-known/openid-configuration"

# Validate JWT token (online tool)
# https://jwt.ms
# or
# https://jwt.io

# Test with Postman
# POST https://{tenant-id}.ciamlogin.com/{tenant-id}/oauth2/v2.0/token
# Headers: Content-Type: application/x-www-form-urlencoded
# Body: 
#   grant_type=authorization_code
#   code={authorization_code}
#   client_id={client_id}
#   client_secret={client_secret}
#   redirect_uri={redirect_uri}
```

### Test SAML Configuration

```bash
# View SAML metadata
curl -X GET "https://{tenant-id}.ciamlogin.com/{tenant-id}/Saml2/GetMetadata" \
  -H "Authorization: Bearer {access_token}"

# Validate SAML assertion (online tool)
# https://www.samltool.com/validate_xml.php

# Check certificate expiration
openssl x509 -in certificate.pem -noout -dates
```

### Browser Developer Tools

1. **Network Tab**
   - Monitor authorization requests/responses
   - Inspect token claims
   - Check redirect chains

2. **Storage Tab (Cookies)**
   - Verify session cookie is set
   - Check cookie flags (Secure, HttpOnly, SameSite)

3. **Console**
   - Check for MSAL logging
   - Monitor token acquisition

---

# Troubleshooting

## Common Issues and Solutions

### OAuth 2.0 / OIDC

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Invalid client ID** | "AADSTS700016: Application with identifier 'xxx' not found" | Verify CLIENT_ID matches app registration in Entra |
| **Redirect URI mismatch** | "The redirect URI does not match" | Ensure REDIRECT_URI in .env exactly matches app registration |
| **Invalid scope** | "AADSTS65001: The user or admin did not consent" | Add scopes to app registration API permissions |
| **Token expired** | 401 Unauthorized on API calls | Implement token refresh logic |
| **PKCE mismatch** | "AADSTS9400011: The code_challenge parameter is not valid" | Ensure code_verifier matches code_challenge |

### SAML 2.0

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Invalid certificate** | "AADSTS700023: The SAML response was invalid" | Download latest IdP certificate and update |
| **NameID not persistent** | "User cannot be linked to existing account" | Set NameID format to `persistent` in IdP |
| **Missing email claim** | "Email attribute is required" | Add email claim to IdP SAML attributes |
| **Metadata not found** | "Unable to read metadata" | Verify metadata URL is accessible from Entra |
| **Assertion expired** | "Assertion has expired" | Check clock sync between IdP and Entra (NTP) |

### WS-Federation

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Invalid realm** | "The Realm parameter does not match" | Verify WSFED_REALM matches AD FS configuration |
| **Certificate not trusted** | "Token signature validation failed" | Import AD FS certificate to Entra |
| **Token expired** | "Token has expired" | Increase token lifetime in AD FS or increase clock skew tolerance |
| **Metadata endpoint not found** | "Unable to retrieve metadata" | Verify AD FS metadata endpoint: `https://adfs.example.com/federationmetadata/2007-06/federationmetadata.xml` |

---

## Getting Help

### Microsoft Documentation

- **OIDC Protocol**: https://learn.microsoft.com/en-us/entra/identity-platform/v2-protocols-oidc
- **SAML in Entra**: https://learn.microsoft.com/en-us/entra/external-id/how-to-register-saml-app
- **WS-Federation**: https://learn.microsoft.com/en-us/windows-server/identity/ad-fs/operations/configure-the-trust-relationship-between-ad-fs-and-saml-federation-services
- **Entra External ID**: https://learn.microsoft.com/en-us/entra/external-id/customers/

### Support Channels

- **Azure Support Portal**: https://portal.azure.com/#blade/Microsoft_Azure_Support/HelpAndSupportBlade
- **Microsoft Q&A**: https://learn.microsoft.com/en-us/answers/products/entra
- **GitHub Issues**: https://github.com/AzureAD/azure-activedirectory-library-for-js/issues

---

## Configuration Validation Checklist

Use this checklist before deploying to production:

- [ ] All three authentication protocols configured (or only those needed)
- [ ] Redirect URIs use HTTPS in production
- [ ] Certificates/secrets stored securely (never in code)
- [ ] Certificates expire after configuration date (at least 6 months)
- [ ] Metadata URL is accessible and returns valid XML
- [ ] PKCE enabled for public clients (SPAs, native apps)
- [ ] State parameter validated to prevent CSRF
- [ ] Token validation implemented in application
- [ ] Rate limiting configured on authentication endpoints
- [ ] Security headers added (CSP, X-Frame-Options, etc.)
- [ ] Error messages don't leak sensitive information
- [ ] Logging captures authentication events (without tokens)
- [ ] Monitoring and alerting configured
- [ ] Disaster recovery plan for certificate rotation
- [ ] User acceptance testing completed with each protocol

---

**Last Updated**: April 22, 2026
**Protocol Support**: All three (OAuth 2.0/OIDC, SAML 2.0, WS-Federation)
**CIAM Scenario**: Customer Identity and Access Management (sign-up/sign-in flows)

