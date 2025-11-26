// backend/src/routes/reports.routes.js
const express = require('express');
const router = express.Router();

// Simple mock data
const reports = [
  { id: 1, severity: 'High', description: 'Critical vulnerability in web API' },
  { id: 2, severity: 'Medium', description: 'Deprecated dependency detected' },
  { id: 3, severity: 'Low', description: 'Non-critical configuration issue' },
];

// ✅ Allow all roles for demo
router.get('/', (req, res) => {
  res.json(reports);
});

module.exports = router;
