const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const pool = require('./db');

async function authenticate(username, password) {
  const result = await pool.query('SELECT id, username, role, password_hash FROM users WHERE username=$1', [username]);
  const user = result.rows[0];
  if (!user) return null;

  const ok = await bcrypt.compare(password, user.password_hash);
  if (!ok) return null;

  return { id: user.id, username: user.username, role: user.role };
}

const signToken = (payload, secret, expiresIn) => jwt.sign(payload, secret, { expiresIn });

module.exports = { signToken, authenticate };
