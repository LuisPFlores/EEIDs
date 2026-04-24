const express = require('express');
const { Strategy: SamlStrategy } = require('@node-saml/passport-saml');

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

function parseMetadataValue(xml, regex) {
  const match = xml.match(regex);
  return match?.[1] || null;
}

async function resolveIdpFromMetadata(url) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Unable to fetch metadata (${response.status} ${response.statusText})`);
  }

  const xml = await response.text();

  const issuer = parseMetadataValue(xml, /<(?:\w+:)?EntityDescriptor[^>]*entityID="([^"]+)"/i);

  const redirectSso = parseMetadataValue(
    xml,
    /<(?:\w+:)?SingleSignOnService[^>]*Binding="urn:oasis:names:tc:SAML:2\.0:bindings:HTTP-Redirect"[^>]*Location="([^"]+)"/i
  );

  const postSso = parseMetadataValue(
    xml,
    /<(?:\w+:)?SingleSignOnService[^>]*Binding="urn:oasis:names:tc:SAML:2\.0:bindings:HTTP-POST"[^>]*Location="([^"]+)"/i
  );

  const entryPoint = redirectSso || postSso;
  const certRaw = parseMetadataValue(xml, /<(?:\w+:)?X509Certificate>([^<]+)<\/(?:\w+:)?X509Certificate>/i);
  const cert = normalizeCert(certRaw);

  if (!issuer || !entryPoint || !cert) {
    throw new Error('Metadata parsing failed: missing issuer, entry point, or signing certificate');
  }

  return { issuer, entryPoint, cert };
}

async function createSamlAuthModule(passport) {
  const {
    SAML_SP_ENTITY_ID,
    SAML_CALLBACK_URL,
    SAML_IDP_ENTRY_POINT,
    SAML_IDP_ISSUER,
    SAML_IDP_CERT,
    SAML_IDP_METADATA_URL,
  } = process.env;

  if (!SAML_SP_ENTITY_ID || !SAML_CALLBACK_URL) {
    throw new Error('Missing required env vars: SAML_SP_ENTITY_ID and SAML_CALLBACK_URL');
  }

  let idpIssuer = SAML_IDP_ISSUER;
  let idpEntryPoint = SAML_IDP_ENTRY_POINT;
  let idpCert = normalizeCert(SAML_IDP_CERT);

  const hasExplicitIdpConfig = Boolean(idpIssuer && idpEntryPoint && idpCert);

  if (!hasExplicitIdpConfig) {
    if (!SAML_IDP_METADATA_URL) {
      throw new Error(
        'Missing IdP config. Provide explicit values (SAML_IDP_ISSUER, SAML_IDP_ENTRY_POINT, SAML_IDP_CERT) or SAML_IDP_METADATA_URL'
      );
    }

    const resolved = await resolveIdpFromMetadata(SAML_IDP_METADATA_URL);
    idpIssuer = resolved.issuer;
    idpEntryPoint = resolved.entryPoint;
    idpCert = resolved.cert;
  }

  const strategy = new SamlStrategy(
    {
      issuer: SAML_SP_ENTITY_ID,
      callbackUrl: SAML_CALLBACK_URL,
      entryPoint: idpEntryPoint,
      idpCert,
      idpIssuer,
      disableRequestedAuthnContext: true,
      // Entra may sign either the SAML Response, the Assertion, or both.
      // Requiring only assertion signatures can fail valid Entra responses.
      wantAssertionsSigned: false,
      wantAuthnResponseSigned: false,
      signatureAlgorithm: 'sha256',
      digestAlgorithm: 'sha256',
    },
    (profile, done) => {
      if (!profile) {
        return done(new Error('No SAML profile returned by IdP'));
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
        sessionIndex: attributes.sessionIndex,
        issuer: attributes.issuer || idpIssuer,
        attributes,
        rawClaims: attributes,
      };

      return done(null, user);
    }
  );

  passport.use('saml', strategy);
  passport.serializeUser((user, done) => done(null, user));
  passport.deserializeUser((user, done) => done(null, user));

  const router = express.Router();

  router.get('/login', (req, res, next) => {
    passport.authenticate('saml')(req, res, next);
  });

  // SAML 2.0 ACS endpoint. IdP posts signed SAMLResponse here.
  router.post(
    '/callback',
    passport.authenticate('saml', { failureRedirect: '/auth/error', failureMessage: true }),
    (req, res) => {
      res.redirect('/profile');
    }
  );

  router.get('/logout', (req, res, next) => {
    req.logout((err) => {
      if (err) return next(err);
      req.session.destroy(() => {
        res.redirect('/');
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
        <title>SAML Authentication Error</title>
        <style>
          body { font-family: 'Segoe UI', sans-serif; max-width: 760px; margin: 60px auto; padding: 20px; color: #1f2937; }
          .box { background: #fef2f2; border: 1px solid #fecaca; border-radius: 10px; padding: 16px; margin-top: 16px; }
          code { background: #f3f4f6; padding: 2px 6px; border-radius: 4px; }
          a { color: #0078d4; }
        </style>
      </head>
      <body>
        <h2>SAML Sign-in Failed</h2>
        ${messages.length ? `<div class="box"><strong>Message:</strong><br/>${messages.join('<br/>')}</div>` : ''}
        <p>Verify these settings:</p>
        <ul>
          <li><code>SAML_SP_ENTITY_ID</code> matches the SP entity configured in your IdP</li>
          <li><code>SAML_CALLBACK_URL</code> is configured as ACS/Reply URL in your IdP</li>
          <li>IdP signing certificate in <code>SAML_IDP_CERT</code> is current</li>
          <li>If metadata mode is used, <code>SAML_IDP_METADATA_URL</code> is reachable</li>
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

  function getServiceProviderMetadata() {
    return strategy.generateServiceProviderMetadata();
  }

  return {
    router,
    requireAuth,
    getServiceProviderMetadata,
  };
}

module.exports = {
  createSamlAuthModule,
};
