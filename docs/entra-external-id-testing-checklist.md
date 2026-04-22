# Entra External Identities - Testing Checklist

Use this checklist to verify each PoC scenario is working correctly.

---

## Pre-Flight Checks

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 1 | Global Admin access confirmed | Can access Entra Admin Center | [ ] |
| 2 | Partner org identified | Partner tenant ID/domain documented | [ ] |
| 3 | Test users created | At least 1 internal + 1 external test account | [ ] |
| 4 | Test apps registered | At least 1 app available for guest access | [ ] |
| 5 | Communication channel with partner | Email/Teams channel for coordination | [ ] |

---

# Scenario 1: B2B Collaboration Testing

## 1.1 Configuration Verification

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 1.1.1 | External collaboration settings accessible | Page loads in Entra Admin Center | [ ] |
| 1.1.2 | Guest user access set to "Restricted" | Setting shows "Guest access restricted..." | [ ] |
| 1.1.3 | Guest invite set to "Admin roles only" | Only admins can invite guests | [ ] |
| 1.1.4 | Domain allowlist configured | Partner domain in allowlist | [ ] |

## 1.2 Cross-Tenant Access Setup

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 1.2.1 | Partner organization added | Partner appears in Cross-tenant access list | [ ] |
| 1.2.2 | Inbound B2B collaboration enabled | "Allow" for Users and groups | [ ] |
| 1.2.3 | MFA trust setting configured | "Accept" or "Require" selected | [ ] |
| 1.2.4 | Outbound settings verified (if needed) | Configured per requirements | [ ] |

## 1.3 Guest Invitation Flow

| # | Test Step | Expected Result | Pass |
|---|-----------|-----------------|------|
| 1.3.1 | Send invitation via portal | Invitation email received | [ ] |
| 1.3.2 | Click acceptance link | Redirected to sign-in page | [ ] |
| 1.3.3 | Authenticate with home IdP | Successful login to partner tenant | [ ] |
| 1.3.4 | Complete redemption | Redirected to MyApps or resource | [ ] |
| 1.3.5 | Guest appears in directory | User type = "Guest" | [ ] |
| 1.3.6 | Guest has correct groups | Member of assigned groups | [ ] |
| 1.3.7 | Guest has correct app access | Can access assigned apps | [ ] |

## 1.4 Conditional Access

| # | Test Step | Expected Result | Pass |
|---|-----------|-----------------|------|
| 1.4.1 | Guest without MFA tries access | Prompted for MFA | [ ] |
| 1.4.2 | Guest completes MFA | Can access resource | [ ] |
| 1.4.3 | CA policy visible in sign-in logs | Policy applied to guest sign-in | [ ] |

## 1.5 Guest Lifecycle

| # | Test Step | Expected Result | Pass |
|---|-----------|-----------------|------|
| 1.5.1 | Guest can view profile | Own profile visible | [ ] |
| 1.5.2 | Guest CANNOT view other users | Access denied error | [ ] |
| 1.5.3 | Guest CANNOT see group membership | Only own groups visible | [ ] |
| 1.5.4 | Guest can reset password (if enabled) | Self-service password works | [ ] |

---

# Scenario 2: B2B Direct Connect Testing

## 2.1 Cross-Tenant Configuration (Both Tenants)

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 2.1.1 | Partner organization added | Partner in Cross-tenant access | [ ] |
| 2.1.2 | Inbound B2B Direct Connect enabled | "Allow" for Users and groups | [ ] |
| 2.1.3 | Outbound B2B Direct Connect enabled | Enabled in partner tenant | [ ] |
| 2.1.4 | Teams included in app settings | Microsoft Teams = Allow | [ ] |

## 2.2 Teams Policy Configuration

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 2.2.1 | Shared channels policy enabled | Global policy allows shared channels | [ ] |
| 2.2.2 | External access enabled | Org-wide settings allow external | [ ] |
| 2.2.3 | Guest access enabled (fallback) | Guest access turned on | [ ] |

## 2.3 Shared Channel Creation

| # | Test Step | Expected Result | Pass |
|---|-----------|-----------------|------|
| 2.3.1 | Create shared channel in host org | Channel created successfully | [ ] |
| 2.3.2 | Add external user to channel | External user appears as member | [ ] |
| 2.3.3 | External user receives notification | Notification in their Teams | [ ] |
| 2.3.4 | External user sees channel | Shared channel visible in their Teams | [ ] |

## 2.4 Channel Functionality

| # | Test Step | Expected Result | Pass |
|---|-------|-----------------|------|
| 2.4.1 | External user posts message | Message appears in channel | [ ] |
| 2.4.2 | Host user replies | Message appears for external user | [ ] |
| 2.4.3 | File upload in channel | File shared successfully | [ ] |
| 2.4.4 | Start Teams meeting in channel | Meeting starts successfully | [ ] |
| 2.4.5 | External user joins meeting | Joins using own credentials | [ ] |

## 2.5 Verification - No Guest Account

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 2.5.1 | External user NOT in host directory | No guest account created | [ ] |
| 2.5.2 | External user uses home credentials | Authenticates at home IdP only | [ ] |
| 2.5.3 | User appears as "External" in channel | Shows email, not as guest | [ ] |

---

# Scenario 3: CIAM (Customer Identity) Testing

## 3.1 External Tenant Setup

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 3.1.1 | External tenant created | New tenant accessible | [ ] |
| 3.1.2 | Domain verified | Custom domain shows "Verified" | [ ] |
| 3.1.3 | Email one-time passcode enabled | IdP available in list | [ ] |
| 3.1.4 | Social IdPs configured (if used) | Google/Facebook available | [ ] |

## 3.2 User Flow Configuration

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 3.2.1 | User flow created | Sign-up/Sign-in flow exists | [ ] |
| 3.2.2 | Identity providers selected | Enabled IdPs checked | [ ] |
| 3.2.3 | User attributes configured | Required attributes set | [ ] |
| 3.2.4 | App assigned to user flow | Target app connected | [ ] |

## 3.3 Application Registration

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 3.3.1 | App registered | App appears in registrations | [ ] |
| 3.3.2 | Redirect URIs configured | URI matches app config | [ ] |
| 3.3.3 | Client ID documented | App ID recorded | [ ] |
| 3.3.4 | Tenant ID documented | External tenant ID recorded | [ ] |

## 3.4 Self-Service Registration

| # | Test Step | Expected Result | Pass |
|---|-----------|-----------------|------|
| 3.4.1 | Access user flow URL | Sign-in page loads | [ ] |
| 3.4.2 | Click "Sign up now" | Registration form appears | [ ] |
| 3.4.3 | Enter required attributes | Form accepts input | [ ] |
| 3.4.4 | Submit registration | Account created | [ ] |
| 3.4.5 | Receive confirmation | Success message shown | [ ] |
| 3.4.6 | User appears in directory | User in external tenant | [ ] |

## 3.5 Sign-In Flow

| # | Test Step | Expected Result | Pass |
|---|-----------|-----------------|------|
| 3.5.1 | Return to user flow URL | Sign-in page loads | [ ] |
| 3.5.2 | Enter registered email | Redirected to IdP | [ ] |
| 3.5.3 | Authenticate successfully | Redirected back | [ ] |
| 3.5.4 | Access application | App loads successfully | [ ] |
| 3.5.5 | Token contains correct claims | ID token has expected claims | [ ] |

## 3.6 Social Provider (if configured)

| # | Test Step | Expected Result | Pass |
|---|-----------|-----------------|------|
| 3.6.1 | Select Google/Facebook | Redirected to provider | [ ] |
| 3.6.2 | Authenticate with social account | Returns to app | [ ] |
| 3.6.3 | New user account created | User in directory | [ ] |
| 3.6.4 | Return sign-in works | No re-authentication needed | [ ] |

## 3.7 Branding & Customization

| # | Check | Expected Result | Pass |
|---|-------|-----------------|------|
| 3.7.1 | Company branding uploaded | Logo/background visible | [ ] |
| 3.7.2 | Custom colors applied | Colors match branding | [ ] |
| 3.7.3 | Help link configured (if set) | Links work correctly | [ ] |

---

# Summary

## Test Results Summary

| Scenario | Total Tests | Passed | Failed | Status |
|----------|-------------|--------|--------|--------|
| B2B Collaboration | 17 | ___ | ___ | [ ] |
| B2B Direct Connect | 13 | ___ | ___ | [ ] |
| CIAM | 22 | ___ | ___ | ___ |
| **TOTAL** | **52** | ___ | ___ | ___ |

---

## Issues Log

| # | Date | Scenario | Test # | Issue Description | Resolution | Resolved |
|---|------|----------|--------|-------------------|------------|----------|
| 1 | | | | | | [ ] |
| 2 | | | | | | [ ] |
| 3 | | | | | | [ ] |
| 4 | | | | | | [ ] |
| 5 | | | | | | [ ] |

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Test Lead | | | |
| Security Review | | | |
| Business Owner | | | |
| IT Admin | | | |

---

## Notes

_Use this section to document any observations, workarounds, or additional findings during testing._
