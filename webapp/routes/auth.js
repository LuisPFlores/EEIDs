const express = require('express');
const msal = require('@azure/msal-node');
const router = express.Router();

// ---------------------------------------------------------------------------
// MSAL configuration — values come from environment variables (.env locally,
// App Settings in Azure Web Apps for production)
// ---------------------------------------------------------------------------
const {
  TENANT_ID,       // External CIAM tenant ID (GUID)
  CLIENT_ID,       // App registration client ID
  CLIENT_SECRET,   // App registration client secret
  REDIRECT_URI,    // Must match the redirect URI registered in Entra
  USER_FLOW,       // Name of the CIAM user flow, e.g. "B2C_1_SignUpSignIn"
} = process.env;

const authorityBase = `https://${TENANT_ID}.ciamlogin.com/${TENANT_ID}`;
const authority = `${authorityBase}/${USER_FLOW}`;

const msalConfig = {
  auth: {
    clientId: CLIENT_ID,
    authority,
    clientSecret: CLIENT_SECRET,
    knownAuthorities: [`${TENANT_ID}.ciamlogin.com`],
  },
  system: {
    loggerOptions: {
      loggerCallback(level, message) {
        if (level <= msal.LogLevel.Warning) console.warn('[MSAL]', message);
      },
      piiLoggingEnabled: false,
      logLevel: msal.LogLevel.Warning,
    }
  }
};

const pca = new msal.ConfidentialClientApplication(msalConfig);

const SCOPES = ['openid', 'profile', 'email', 'offline_access'];

// ---------------------------------------------------------------------------
// GET /auth/login — redirect user to Entra CIAM sign-in page
// ---------------------------------------------------------------------------
router.get('/login', async (req, res, next) => {
  try {
    const authUrl = await pca.getAuthCodeUrl({
      scopes: SCOPES,
      redirectUri: REDIRECT_URI,
      responseMode: msal.ResponseMode.QUERY,
    });
    res.redirect(authUrl);
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// GET /auth/redirect — Entra posts the auth code here after sign-in
// ---------------------------------------------------------------------------
router.get('/redirect', async (req, res, next) => {
  if (req.query.error) {
    return res.status(400).send(`Auth error: ${req.query.error_description || req.query.error}`);
  }

  try {
    const tokenResponse = await pca.acquireTokenByCode({
      code: req.query.code,
      scopes: SCOPES,
      redirectUri: REDIRECT_URI,
    });

    // Store only the claims we need in session (avoid storing full token)
    req.session.account = {
      homeAccountId: tokenResponse.account.homeAccountId,
      username: tokenResponse.account.username,
      name: tokenResponse.idTokenClaims?.name || tokenResponse.account.name,
      email: tokenResponse.idTokenClaims?.email || tokenResponse.account.username,
      oid: tokenResponse.idTokenClaims?.oid,
    };

    res.redirect('/profile');
  } catch (err) {
    next(err);
  }
});

// ---------------------------------------------------------------------------
// GET /auth/logout — clear session and redirect to CIAM global sign-out
// ---------------------------------------------------------------------------
router.get('/logout', (req, res, next) => {
  req.session.destroy((err) => {
    if (err) return next(err);
    const postLogoutUri = encodeURIComponent(`${REDIRECT_URI.replace('/auth/redirect', '')}/`);
    res.redirect(
      `${authorityBase}/${USER_FLOW}/oauth2/v2.0/logout?post_logout_redirect_uri=${postLogoutUri}`
    );
  });
});

module.exports = router;
