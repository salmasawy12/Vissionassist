const express = require("express");
const admin = require("firebase-admin");
const cors = require("cors");
const app = express();

app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(require("./serviceAccountKey.json")),
});

const db = admin.firestore();

// Look up UID for a given fingerprintId in Firestore
async function getUidForFingerprint(fingerprintId) {
  const doc = await db.collection("fingerprints").doc(fingerprintId).get();
  if (!doc.exists) return null;
  return doc.data().uid;
}

// Endpoint: POST /getCustomToken
app.post("/getCustomToken", async (req, res) => {
  const { fingerprintId } = req.body;
  if (!fingerprintId)
    return res.status(400).json({ error: "Missing fingerprintId" });

  const uid = await getUidForFingerprint(fingerprintId);
  if (!uid) return res.status(404).json({ error: "No user for fingerprint" });

  try {
    const token = await admin.auth().createCustomToken(uid);
    res.json({ token });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Test endpoint for network connectivity
app.get("/test", (req, res) => res.send("Backend is reachable!"));

// Change port to 4000 to avoid conflicts
const PORT = process.env.PORT || 4000;
app.listen(PORT, "0.0.0.0", () =>
  console.log(`Server running on port ${PORT}`)
);
