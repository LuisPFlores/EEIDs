const express = require('express');
const msal = require('@azure/msal-node');
const axios = require('axios');
const router = express.Router();

// ---------------------------------------------------------------------------
// MSAL configuration — values come from environment variables (.env locally,
// App Settings in Azure Web Apps for production)
// ---------------------------------------------------------------------------
const {
  TENANT_NAME,     // CIAM tenant subdomain (e.g. "titacorp")
  TENANT_ID,       // Entra External ID tenant ID (GUID)
  CLIENT_ID,       // App registration client ID
  CLIENT_SECRET,   // App registration client secret
  REDIRECT_URI,    // Must match the redirect URI registered in Entra
  RECAPTCHA_SECRET,  // Google reCAPTCHA secret key
} = process.env;

const authority = `https://${TENANT_NAME}.ciamlogin.com/${TENANT_ID}`;

const msalConfig = {
  auth: {
    clientId: CLIENT_ID,
    authority,
    clientSecret: CLIENT_SECRET,
    knownAuthorities: [`${TENANT_NAME}.ciamlogin.com`],
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
// POST /auth/verify-captcha — validate reCAPTCHA before allowing sign-up
// ---------------------------------------------------------------------------
router.post('/verify-captcha', async (req, res) => {
  const captchaToken = req.body['g-recaptcha-response'];

  if (!captchaToken) {
    return res.status(400).json({ success: false, message: 'Please complete the CAPTCHA.' });
  }

  try {
    const verifyResponse = await axios.post(
      'https://www.google.com/recaptcha/api/siteverify',
      null,
      { params: { secret: RECAPTCHA_SECRET, response: captchaToken } }
    );

    if (verifyResponse.data.success) {
      // CAPTCHA valid — generate the Entra sign-up URL and redirect
      const authUrl = await pca.getAuthCodeUrl({
        scopes: SCOPES,
        redirectUri: REDIRECT_URI,
        responseMode: msal.ResponseMode.QUERY,
      });
      return res.json({ success: true, redirectUrl: authUrl });
    }

    return res.status(403).json({ success: false, message: 'CAPTCHA verification failed. Please try again.' });
  } catch (err) {
    console.error('[CAPTCHA] Verification error:', err.message);
    return res.status(500).json({ success: false, message: 'Verification service error. Please try again.' });
  }
});

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
// GET /auth/logout — clear session and redirect to Entra global sign-out
// ---------------------------------------------------------------------------
router.get('/logout', (req, res, next) => {
  req.session.destroy((err) => {
    if (err) return next(err);
    const postLogoutUri = encodeURIComponent(`${REDIRECT_URI.replace('/auth/redirect', '')}/`);
    res.redirect(
      `${authority}/oauth2/v2.0/logout?post_logout_redirect_uri=${postLogoutUri}`
    );
  });
});

module.exports = router;
