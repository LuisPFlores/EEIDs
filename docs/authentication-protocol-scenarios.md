# Authentication Protocol Scenarios for Entra External Identities

This document explains the three authentication protocol scenarios used in this repository:
- OAuth 2.0 / OpenID Connect
- SAML 2.0
- WS-Federation

For each scenario, you will find:
- Typical use case
- Main components included
- Expected results after configuration and testing

---

## 1. OAuth 2.0 / OpenID Connect Scenario

### Use case
Use this scenario for modern web applications, SPAs, and mobile apps that need standards-based sign-in, token-based API access, and flexible user journey support in CIAM.

Typical examples:
- Customer portal sign-up and sign-in
- Mobile app sign-in
- Web app calling protected APIs with access tokens

### Components included
Identity and platform components:
- Entra External ID tenant
- App registration for client application
- User flow (for example SignUpSignIn)
- Token endpoints and OpenID metadata endpoint

Application components in this repo:
- webapp app server
- OIDC authentication routes
- Session handling
- Profile endpoint and protected page

Configuration artifacts:
- Tenant ID
- Tenant subdomain
- Client ID and client secret
- Redirect URI
- User flow name

### Expected results
- User can start sign-in from the web app and reach Entra sign-in screen.
- Authentication returns ID token and account claims.
- App establishes authenticated session and grants access to protected profile page.
- User claim data such as display name, email, and object ID is available.
- Logout clears local session and returns to app landing page.

Success indicators:
- Sign-in endpoint responds correctly.
- Redirect callback is successful.
- Protected route is blocked when not authenticated and accessible after sign-in.

---

## 2. SAML 2.0 Scenario

### Use case
Use this scenario when integrating with enterprise identity providers that rely on SAML assertions and metadata exchange, especially for B2B and partner federation.

Typical examples:
- Partner organization federation with Okta or PingFederate
- Legacy enterprise applications requiring SAML assertions
- External workforce access where SAML is the standard

### Components included
Identity and federation components:
- Identity Provider (IdP) metadata or explicit SSO settings
- Service Provider (SP) entity ID
- Assertion Consumer Service (ACS) callback endpoint
- IdP signing certificate for assertion validation

Application components in this repo:
- webapp-saml app server
- SAML auth routes (login, callback, logout, error)
- Metadata publishing endpoint
- Claims display page for validation

Configuration artifacts:
- SP entity ID
- ACS callback URL
- IdP entry point
- IdP issuer
- IdP signing certificate
- Optional metadata URL fallback

### Expected results
- User starts login and is redirected to the configured IdP.
- IdP posts SAMLResponse to ACS callback endpoint.
- Assertion signature is validated with configured IdP certificate.
- App creates authenticated session and exposes mapped user attributes.
- SP metadata endpoint returns valid metadata for federation setup.

Success indicators:
- Metadata endpoint is reachable.
- Callback receives POST assertion without parsing errors.
- Profile page shows NameID and mapped claims.
- Unauthenticated access to protected routes is redirected to login.

---

## 3. WS-Federation Scenario

### Use case
Use this scenario for legacy federation and compatibility cases where systems still use WS-Fed passive flow instead of OIDC or SAML.

Typical examples:
- Legacy AD FS-integrated applications
- Existing enterprise workloads using WS-Federation passive profile
- Migration projects where modern protocol replacement is not immediate

### Components included
Identity and federation components:
- WS-Federation endpoint
- Realm (relying party identifier)
- Federation metadata endpoint
- Signing certificate thumbprints or cert material for token validation

Application components in this repo:
- webapp-wsfed app server
- WS-Fed login and callback routes
- Session handling
- Claims inspection profile view

Configuration artifacts:
- Tenant ID
- WS-Fed realm
- Metadata URL
- Callback URL
- IdP URL
- Certificate thumbprints

### Expected results
- User is redirected to IdP through WS-Fed sign-in flow.
- Token is posted to callback and validated by app middleware.
- Session is established and user profile is displayed.
- Raw claims can be inspected for troubleshooting.
- Logout clears local session and returns user to app home page.

Success indicators:
- Login redirect is generated correctly.
- Callback succeeds without signature or thumbprint mismatch errors.
- Claims are visible in profile output.
- Protected routes require authentication.

---

## Scenario Comparison Summary

| Protocol | Best fit | Main token format | Typical complexity | Recommended for new apps |
|---|---|---|---|---|
| OAuth 2.0 / OpenID Connect | Modern customer apps and APIs | JWT tokens | Medium | Yes |
| SAML 2.0 | Enterprise partner federation | SAML XML assertions | Medium to high | Depends on partner requirement |
| WS-Federation | Legacy federation compatibility | WS-Fed token response with assertions | High | No, only legacy need |

---

## Practical Expected Outcomes by Scenario

After successful setup, each scenario should demonstrate:

OAuth 2.0 / OpenID Connect:
- Interactive sign-in works
- ID token claims are available
- Session and protected routes function

SAML 2.0:
- IdP metadata and ACS callback flow work end to end
- Assertion validation succeeds
- User attributes are mapped and visible

WS-Federation:
- Passive sign-in flow works with configured realm
- Token validation succeeds against configured trust settings
- Claims can be reviewed for troubleshooting and migration planning

---

## Recommended selection guidance

Choose OAuth 2.0 / OpenID Connect when:
- Building a new application
- You need API access tokens
- You want modern SDK support and lower long-term operational overhead

Choose SAML 2.0 when:
- A partner or enterprise IdP requires SAML
- Federation agreements and metadata exchange are already based on SAML

Choose WS-Federation when:
- You must support legacy systems that cannot move yet
- Compatibility is more important than modernization in the short term
