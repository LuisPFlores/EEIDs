require('dotenv').config();
const express = require('express');
const session = require('express-session');
const passport = require('passport');
const path = require('path');
const { createWsFedAuthModule } = require('./routes/auth-wsfed');

const app = express();
const PORT = process.env.PORT || 3001;

// WS-Fed token is posted as form-urlencoded payload (wresult)
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

const authModule = createWsFedAuthModule(passport);

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

app.use((err, req, res, next) => {
  console.error('[WS-Fed] Unhandled error:', err);
  res.status(500).send('Server Error: ' + (err.message || 'Unknown error'));
});

app.listen(PORT, () => {
  console.log('\n========================================');
  console.log('  WS-Federation Test App');
  console.log('========================================');
  console.log(`  App:       http://localhost:${PORT}`);
  console.log(`  Login:     http://localhost:${PORT}/auth/login`);
  console.log(`  Callback:  http://localhost:${PORT}/auth/callback`);
  console.log(`  Profile:   http://localhost:${PORT}/profile`);
  console.log('========================================\n');
});
