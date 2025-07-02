const fs = require("fs");

// Read the service account key file
try {
  const serviceAccount = require("./serviceAccountKey.json");

  console.log("Service Account Configuration:");
  console.log("==============================");
  console.log(`Project ID: ${serviceAccount.project_id}`);
  console.log(`Client Email: ${serviceAccount.client_email}`);
  console.log(`Private Key ID: ${serviceAccount.private_key_id}`);
  console.log("");
  console.log("Environment Variables to set:");
  console.log("==============================");
  console.log(`FIREBASE_PROJECT_ID=${serviceAccount.project_id}`);
  console.log(`FIREBASE_CLIENT_EMAIL=${serviceAccount.client_email}`);
  console.log(`FIREBASE_PRIVATE_KEY_ID=${serviceAccount.private_key_id}`);
  console.log(`FIREBASE_CLIENT_ID=${serviceAccount.client_id}`);
  console.log(
    `FIREBASE_CLIENT_X509_CERT_URL=${serviceAccount.client_x509_cert_url}`
  );
  console.log("");
  console.log("For the private key, use this (replace newlines with \\n):");
  console.log(
    `FIREBASE_PRIVATE_KEY="${serviceAccount.private_key.replace(/\n/g, "\\n")}"`
  );
  console.log("");
  console.log("To run the server with these environment variables:");
  console.log("export FIREBASE_PROJECT_ID=" + serviceAccount.project_id);
  console.log("export FIREBASE_CLIENT_EMAIL=" + serviceAccount.client_email);
  console.log(
    "export FIREBASE_PRIVATE_KEY_ID=" + serviceAccount.private_key_id
  );
  console.log("export FIREBASE_CLIENT_ID=" + serviceAccount.client_id);
  console.log(
    "export FIREBASE_CLIENT_X509_CERT_URL=" +
      serviceAccount.client_x509_cert_url
  );
  console.log(
    'export FIREBASE_PRIVATE_KEY="' +
      serviceAccount.private_key.replace(/\n/g, "\\n") +
      '"'
  );
  console.log("node index.js");
} catch (error) {
  console.error("Error reading service account file:", error.message);
  console.log("");
  console.log("Please make sure serviceAccountKey.json exists and is valid.");
}
