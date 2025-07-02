const admin = require("firebase-admin");

// Test Firebase connection
async function testFirebaseConnection() {
  try {
    console.log("Testing Firebase connection...");

    // Load service account
    const serviceAccount = require("./serviceAccountKey.json");
    console.log("Service account loaded successfully");
    console.log("Project ID:", serviceAccount.project_id);

    // Initialize Firebase Admin SDK
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id,
    });

    console.log("Firebase Admin SDK initialized");

    // Test Firestore connection
    const db = admin.firestore();
    console.log("Firestore instance created");

    // Try to read from a test collection
    const testQuery = await db.collection("test").limit(1).get();
    console.log("Firestore query successful");

    // Test Auth
    const auth = admin.auth();
    console.log("Firebase Auth initialized");

    console.log("✅ All Firebase services are working correctly!");
  } catch (error) {
    console.error("❌ Firebase connection failed:", error);
    console.error("Error details:", {
      code: error.code,
      message: error.message,
      stack: error.stack,
    });
  }
}

testFirebaseConnection();
