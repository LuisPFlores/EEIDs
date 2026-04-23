const express = require('express');
const { Strategy: SamlStrategy } = require('@node-saml/passport-saml');

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
      wantAssertionsSigned: true,
      signatureAlgorithm: 'sha256',
      digestAlgorithm: 'sha256',
    },
    (profile, done) => {
      if (!profile) {
        return done(new Error('No SAML profile returned by IdP'));
      }

      const attributes = { ...profile };

      const email =
        attributes.email ||
        attributes.mail ||
        attributes['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'] ||
        attributes.nameID;

      const displayName =
        attributes.displayName ||
        attributes.name ||
        attributes.cn ||
        `${attributes.givenName || ''} ${attributes.sn || attributes.surname || ''}`.trim() ||
        attributes.nameID;

      const user = {
        nameID: attributes.nameID,
        nameIDFormat: attributes.nameIDFormat,
        sessionIndex: attributes.sessionIndex,
        issuer: attributes.issuer || idpIssuer,
        email,
        displayName,
        givenName: attributes.givenName || attributes.given_name,
        surname: attributes.sn || attributes.surname || attributes.family_name,
        attributes,
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
