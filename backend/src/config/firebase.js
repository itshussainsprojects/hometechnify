
const admin = require('firebase-admin');
const path = require('path');

try {
    // Local dev reads the key file directly (never committed to git). A
    // hosted server has no such file, so it reads the same JSON from an env
    // var instead — set FIREBASE_SERVICE_ACCOUNT_JSON to the file's raw
    // contents in Railway's variables.
    const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_JSON
        ? JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON)
        : require(path.join(__dirname, '../../serviceAccountKey.json'));

    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });

    console.log('Firebase Admin Initialized');
} catch (error) {
    console.error('Error initializing Firebase Admin:', error);
}

module.exports = admin;
