const express = require('express');
const { Strategy: WsFedStrategy } = require('passport-wsfed-saml2');

const CLAIMS = {
  OID: 'http://schemas.microsoft.com/identity/claims/objectidentifier',
  EMAIL: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress',
  UPN: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/upn',
  DISPLAYNAME: 'http://schemas.microsoft.com/identity/claims/displayname',
  NAME: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name',
  NAMEID: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier',
  GIVENNAME: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname',
  SURNAME: 'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname',
  TENANTID: 'http://schemas.microsoft.com/identity/claims/tenantid',
  AUTHMETHOD: 'http://schemas.microsoft.com/claims/authnmethodsreferences',
  AUTHMETHOD_ALT: 'http://schemas.microsoft.com/ws/2008/06/identity/claims/authenticationmethod',
};

function firstNonEmpty(...values) {
  for (const value of values) {
    if (Array.isArray(value)) {
      for (const item of value) {
        if (item !== undefined && item !== null && String(item).trim()) {
          return String(item).trim();
        }
      }
      continue;
    }

    if (value && typeof value === 'object') {
      const candidate = value._ || value.value || value.text;
      if (candidate !== undefined && candidate !== null && String(candidate).trim()) {
        return String(candidate).trim();
      }
      continue;
    }

    if (value !== undefined && value !== null && String(value).trim()) {
      return String(value).trim();
    }
  }

  return undefined;
}

function normalizeCert(certValue) {
  if (!certValue) return null;
  const trimmed = certValue.trim();

  if (trimmed.includes('BEGIN CERTIFICATE')) {
    return trimmed;
  }

  const cleaned = trimmed.replace(/\s+/g, '');
  const wrapped = cleaned.match(/.{1,64}/g)?.join('\n') || cleaned;
  return `-----BEGIN CERTIFICATE-----\n${wrapped}\n-----END CERTIFICATE-----`;
}

function createWsFedAuthModule(passport) {
  const {
    WSFED_REALM,
    WSFED_REPLY_URL,
    WSFED_IDP_URL,
    WSFED_IDP_ISSUER,
    WSFED_IDP_CERT,
    TENANT_ID,
  } = process.env;

  if (!WSFED_REALM || !WSFED_REPLY_URL) {
    throw new Error('Missing required env vars: WSFED_REALM and WSFED_REPLY_URL');
  }

  if (!WSFED_IDP_URL) {
    throw new Error('Missing required env var: WSFED_IDP_URL');
  }

  // passport-wsfed-saml2 validates the embedded cert in the token against known thumbprints
  const thumbprints = [
    '9311B4B7464588CF5A903EA961A8BBF2314D10D9',
    'CDC26ADD7B90E97C60C934B40B87F28883329351',
    '718A2F74F6161BA5A2E26F6EA6488916FD3E2BF9',
    '5EDFA8EE10DBA6EA40CFE64F9BA1F1085592DDC2',
    '4C1B205A86AB156BFD4DCA31216CBBA06E6828D0',
    '3162BD0BC46F6DF638A4FA4E146EB1E5A344E595',
  ];

  const strategyOptions = {
    realm: WSFED_REALM,
    identityProviderUrl: WSFED_IDP_URL,
    wreply: WSFED_REPLY_URL,
    thumbprints,
  };

  const strategy = new WsFedStrategy(
    strategyOptions,
    (profile, done) => {
      if (!profile) {
        return done(new Error('No WS-Fed profile returned by IdP'));
      }

      const attributes = { ...profile };

      const givenName = firstNonEmpty(
        attributes[CLAIMS.GIVENNAME],
        attributes.givenName,
        attributes.given_name
      );
      const familyName = firstNonEmpty(
        attributes[CLAIMS.SURNAME],
        attributes.sn,
        attributes.surname,
        attributes.family_name
      );
      const composedName = [givenName, familyName].filter(Boolean).join(' ').trim();
      const nameID = firstNonEmpty(
        attributes.nameID,
        attributes.nameId,
        attributes[CLAIMS.NAMEID],
        attributes[CLAIMS.NAME]
      );
      const email = firstNonEmpty(
        attributes[CLAIMS.EMAIL],
        attributes.email,
        attributes.mail,
        attributes[CLAIMS.UPN],
        nameID
      );
      const displayName = firstNonEmpty(
        attributes[CLAIMS.DISPLAYNAME],
        attributes.displayName,
        attributes.name,
        attributes.cn,
        composedName,
        nameID,
        email && email.split('@')[0]
      );
      const upn = firstNonEmpty(
        attributes[CLAIMS.UPN],
        attributes.upn,
        nameID,
        attributes[CLAIMS.NAME]
      );

      const user = {
        oid: firstNonEmpty(attributes[CLAIMS.OID], attributes.oid),
        email,
        upn,
        name: displayName,
        displayName,
        givenName,
        familyName,
        surname: familyName,
        tenantId: firstNonEmpty(attributes[CLAIMS.TENANTID], attributes.tid, attributes.tenantId),
        authMethod: firstNonEmpty(attributes[CLAIMS.AUTHMETHOD], attributes[CLAIMS.AUTHMETHOD_ALT], attributes.authmethod),
        nameID,
        nameIDFormat: attributes.nameIDFormat,
        issuer: attributes.issuer || WSFED_IDP_ISSUER,
        attributes,
        rawClaims: attributes,
      };

      return done(null, user);
    }
  );

  passport.use('wsfed-saml2', strategy);
  passport.serializeUser((user, done) => done(null, user));
  passport.deserializeUser((user, done) => done(null, user));

  const router = express.Router();

  // WS-Fed sign-in — redirects to Entra's WS-Fed passive endpoint
  router.get('/login', (req, res, next) => {
    passport.authenticate('wsfed-saml2')(req, res, next);
  });

  // WS-Fed callback — Entra POSTs wresult (signed SAML token) here
  router.post(
    '/callback',
    passport.authenticate('wsfed-saml2', { failureRedirect: '/auth/error', failureMessage: true }),
    (req, res) => {
      res.redirect('/profile');
    }
  );

  // Logout — destroy local session & redirect to Entra WS-Fed sign-out
  router.get('/logout', (req, res, next) => {
    const wreply = encodeURIComponent(WSFED_REALM + '/');
    const logoutUrl = `${WSFED_IDP_URL}?wa=wsignout1.0&wreply=${wreply}`;

    req.logout((err) => {
      if (err) return next(err);
      req.session.destroy(() => {
        res.redirect(logoutUrl);
      });
    });
  });

  router.get('/error', (req, res) => {
    const messages = req.session?.messages || [];
    res.status(401).send(`
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <title>WS-Federation Authentication Error</title>
        <style>
          body { font-family: 'Segoe UI', sans-serif; max-width: 760px; margin: 60px auto; padding: 20px; color: #1f2937; }
          .box { background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px; padding: 16px; margin-top: 16px; }
          code { background: #f3f4f6; padding: 2px 6px; border-radius: 4px; }
          a { color: #0078d4; }
        </style>
      </head>
      <body>
        <h2>WS-Federation Sign-in Failed</h2>
        ${messages.length ? `<div class="box"><strong>Message:</strong><br/>${messages.join('<br/>')}</div>` : ''}
        <p>Verify these settings:</p>
        <ul>
          <li><code>WSFED_REALM</code> matches the Identifier URI in the Entra app registration</li>
          <li><code>WSFED_REPLY_URL</code> is configured as Reply URL in the Entra app registration</li>
          <li>IdP signing certificate in <code>WSFED_IDP_CERT</code> is current</li>
          <li><code>WSFED_IDP_URL</code> points to your tenant's /wsfed endpoint</li>
        </ul>
        <a href="/">Return home</a>
      </body>
      </html>
    `);
  });

  function requireAuth(req, res, next) {
    if (req.isAuthenticated && req.isAuthenticated()) return next();
    return res.redirect('/auth/login');
  }

  return {
    router,
    requireAuth,
  };
}

module.exports = {
  createWsFedAuthModule,
};
