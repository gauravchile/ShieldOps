const express = require('express');
const fs = require('fs');
const router = express.Router();

router.post('/login', (req, res) => {
  const { username, password } = req.body;
  try {
    const users = JSON.parse(fs.readFileSync('./users.json', 'utf8'));
    const user = users.find(u => u.username === username && u.password === password);

    if (!user) return res.status(401).json({ message: 'Invalid credentials' });

    res.json({
      token: `fake-jwt-${user.role}-${Date.now()}`,
      role: user.role
    });
  } catch (err) {
    console.error('Auth error:', err);
    res.status(500).json({ message: 'Internal Server Error' });
  }
});

module.exports = router;
