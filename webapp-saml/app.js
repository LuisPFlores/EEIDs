require('dotenv').config();
const express = require('express');
const session = require('express-session');
const passport = require('passport');
const path = require('path');
const { createSamlAuthModule } = require('./routes/auth-saml');

const app = express();
const PORT = process.env.PORT || 3002;

async function start() {
  const authModule = await createSamlAuthModule(passport);

  // SAML response is posted as form-urlencoded payload (SAMLResponse)
  app.use(express.urlencoded({ extended: false }));

  app.use(session({
    secret: process.env.SESSION_SECRET || 'change-this-secret',
    resave: false,
    saveUninitialized: false,
    cookie: {
      secure: process.env.NODE_ENV === 'production',
      httpOnly: true,
      maxAge: 1000 * 60 * 60,
    },
  }));

  app.use(passport.initialize());
  app.use(passport.session());

  app.use(express.static(path.join(__dirname, 'views')));
  app.use('/auth', authModule.router);

  app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'views', 'index.html'));
  });

  app.get('/profile', authModule.requireAuth, (req, res) => {
    res.sendFile(path.join(__dirname, 'views', 'profile.html'));
  });

  app.get('/api/me', authModule.requireAuth, (req, res) => {
    res.json(req.user);
  });

  app.get('/metadata.xml', (req, res) => {
    const xml = authModule.getServiceProviderMetadata();
    res.type('application/xml').send(xml);
  });

  app.use((err, req, res, next) => {
    console.error('[SAML] Unhandled error:', err);
    res.status(500).send('Server Error: ' + (err.message || 'Unknown error'));
  });

  app.listen(PORT, () => {
    console.log('\n========================================');
    console.log('  SAML 2.0 Test App');
    console.log('========================================');
    console.log(`  App:       http://localhost:${PORT}`);
    console.log(`  Login:     http://localhost:${PORT}/auth/login`);
    console.log(`  Callback:  http://localhost:${PORT}/auth/callback`);
    console.log(`  Profile:   http://localhost:${PORT}/profile`);
    console.log(`  Metadata:  http://localhost:${PORT}/metadata.xml`);
    console.log('========================================\n');
  });
}

start().catch((err) => {
  console.error('[SAML] Startup failed:', err.message || err);
  process.exit(1);
});
