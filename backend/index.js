const express = require("express");
const admin = require("firebase-admin");
const cors = require("cors");
const app = express();

app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK with proper error handling
try {
  let serviceAccount;

  // Try to use environment variables first (for production)
  if (process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY) {
    serviceAccount = {
      type: "service_account",
      project_id: process.env.FIREBASE_PROJECT_ID,
      private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
      private_key: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
      client_email: process.env.FIREBASE_CLIENT_EMAIL,
      client_id: process.env.FIREBASE_CLIENT_ID,
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL,
      universe_domain: "googleapis.com",
    };
    console.log("Using environment variables for Firebase configuration");
  } else {
    // Fall back to service account file
    serviceAccount = require("./serviceAccountKey.json");
    console.log("Using service account file for Firebase configuration");
  }

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });

  console.log("Firebase Admin SDK initialized successfully");
  console.log("Project ID:", serviceAccount.project_id);
} catch (error) {
  console.error("Error initializing Firebase Admin SDK:", error);
  console.error("Please check your service account configuration");
  process.exit(1);
}

const db = admin.firestore();

// Look up UID for a given fingerprintId in Firestore
async function getUidForFingerprint(fingerprintId) {
  try {
    console.log(`Looking up fingerprint: ${fingerprintId}`);
    const doc = await db.collection("fingerprints").doc(fingerprintId).get();
    if (!doc.exists) {
      console.log(`No fingerprint found for ID: ${fingerprintId}`);
      return null;
    }
    const data = doc.data();
    console.log(`Found UID ${data.uid} for fingerprint ${fingerprintId}`);
    return data.uid;
  } catch (error) {
    console.error("Error getting UID for fingerprint:", error);
    throw error;
  }
}

// Endpoint: POST /getCustomToken
app.post("/getCustomToken", async (req, res) => {
  try {
    const { fingerprintId } = req.body;
    console.log(`Received request for fingerprint: ${fingerprintId}`);

    if (!fingerprintId) {
      console.log("Missing fingerprintId in request");
      return res.status(400).json({ error: "Missing fingerprintId" });
    }

    const uid = await getUidForFingerprint(fingerprintId);
    if (!uid) {
      console.log(`No user found for fingerprint: ${fingerprintId}`);
      return res.status(404).json({ error: "No user for fingerprint" });
    }

    const token = await admin.auth().createCustomToken(uid);
    console.log(`Created custom token for UID: ${uid}`);
    res.json({ token });
  } catch (err) {
    console.error("Error creating custom token:", err);
    res.status(500).json({ error: err.message });
  }
});

// Test endpoint for network connectivity
app.get("/test", (req, res) => {
  console.log("Test endpoint called");
  res.send("Backend is reachable!");
});

// Health check endpoint
app.get("/health", async (req, res) => {
  try {
    // Test Firestore connection
    await db.collection("test").limit(1).get();
    res.json({ status: "healthy", firestore: "connected" });
  } catch (error) {
    console.error("Health check failed:", error);
    res.status(500).json({ status: "unhealthy", error: error.message });
  }
});

// Change port to 4000 to avoid conflicts
const PORT = process.env.PORT || 4000;
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Health check available at: http://localhost:${PORT}/health`);
  console.log(`Test endpoint available at: http://localhost:${PORT}/test`);
});
