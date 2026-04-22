require('dotenv').config();
const express = require('express');
const session = require('express-session');
const path = require('path');
const authRouter = require('./routes/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// Session middleware — in production use a persistent store (e.g. connect-redis)
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

// Auth routes: /auth/login, /auth/redirect, /auth/logout
app.use('/auth', authRouter);

// Public home page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'index.html'));
});

// Protected profile page
app.get('/profile', requireAuth, (req, res) => {
  res.sendFile(path.join(__dirname, 'views', 'profile.html'));
});

// Profile data API — returns logged-in account info as JSON
app.get('/api/me', requireAuth, (req, res) => {
  res.json(req.session.account);
});

function requireAuth(req, res, next) {
  if (!req.session.account) {
    return res.redirect('/auth/login');
  }
  next();
}

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
