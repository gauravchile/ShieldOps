const pool = require('./db');
const bcrypt = require('bcryptjs');

(async () => {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(50) UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      role VARCHAR(20) NOT NULL
    );
  `);

  const users = [
    { username: 'admin', role: 'admin' },
    { username: 'analyst', role: 'analyst' },
    { username: 'viewer', role: 'viewer' },
  ];

  for (const u of users) {
    const hash = await bcrypt.hash('shieldops', 10);
    await pool.query(
      `INSERT INTO users (username, password_hash, role)
       VALUES ($1, $2, $3)
       ON CONFLICT (username) DO NOTHING;`,
      [u.username, hash, u.role]
    );
  }

  console.log('✅ Users seeded');
  process.exit(0);
})();
