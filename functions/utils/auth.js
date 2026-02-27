const admin = require("../config/admin");

async function verifyFirebaseIdToken(req) {
  const h = req.headers.authorization || "";
  const m = h.match(/^Bearer (.+)$/);
  if (!m) throw new Error("Missing Bearer token");
  return admin.auth().verifyIdToken(m[1]);
}

module.exports = { verifyFirebaseIdToken };