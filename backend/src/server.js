/**
 * 🛡️ ShieldOps Backend Server
 * ---------------------------------------
 * Handles authentication, reports API,
 * and health checks with static users.json
 */

const fs = require("fs");
const path = require("path");
const express = require("express");
const cors = require("cors");

const app = express();

// ✅ CORS setup — allow UI to reach backend via Ingress or NodePort
app.use(
  cors({
    origin: "*",
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allowedHeaders: [
      "DNT",
      "Keep-Alive",
      "User-Agent",
      "X-Requested-With",
      "If-Modified-Since",
      "Cache-Control",
      "Content-Type",
      "Range",
      "Authorization",
    ],
  })
);

// ✅ JSON parser middleware
app.use(express.json());

// ✅ Load static users.json (no DB)
const usersPath = path.join(__dirname, "../users.json");
const users = JSON.parse(fs.readFileSync(usersPath, "utf8"));

// ---------------------------------------
// 🔐 Authentication Route
// ---------------------------------------
app.post("/api/auth/login", (req, res) => {
  const { username, password } = req.body;
  const user = users.find(
    (u) => u.username === username && u.password === password
  );

  if (!user) {
    return res.status(401).json({ message: "Invalid credentials" });
  }

  // ✅ Return token and user info
  const token = `fake-jwt-${user.role}-${Date.now()}`;
  res.json({
    token,
    user: { username: user.username, role: user.role },
  });
});

// ---------------------------------------
// 🩺 Health Check
// ---------------------------------------
app.get("/api/health", (_, res) => res.json({ status: "ok" }));

// ---------------------------------------
// 📊 Reports Route (requires fake JWT)
// ---------------------------------------
app.use("/api/reports", (req, res, next) => {
  const auth = req.headers["authorization"];

  if (!auth || !auth.startsWith("Bearer fake-jwt-")) {
    return res.status(403).json({ message: "Forbidden" });
  }

  next();
});

// Dummy reports API
app.get("/api/reports", (_, res) => {
  res.json([
    { id: 1, title: "Incident: Suspicious Login", severity: "High" },
    { id: 2, title: "Vulnerability Scan - Passed", severity: "Low" },
    { id: 3, title: "Unauthorized SSH Attempt", severity: "Critical" },
  ]);
});

// ---------------------------------------
// 🚀 Start server
// ---------------------------------------
const PORT = process.env.PORT || 8081;
app.listen(PORT, () =>
  console.log(`✅ ShieldOps backend listening on port ${PORT}`)
);
