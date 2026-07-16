const admin = require('firebase-admin');

// Ensure you have valid Firebase Admin credentials initialized.
// Provide the path to your service account key file.
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
}

async function updatePassword(email, newPassword) {
    try {
        console.log(`Setting password for ${email}...`);
        
        // Find user by email
        const userRecord = await admin.auth().getUserByEmail(email);
        
        // Update password
        await admin.auth().updateUser(userRecord.uid, {
            password: newPassword,
        });

        console.log(`✅ Success: Password for ${email} has been updated to "${newPassword}".`);
        console.log(`You can now login to the Admin Panel with email: ${email} and password: ${newPassword}`);
    } catch (error) {
        console.error('❌ Error updating password:', error.message);
        if (error.code === 'auth/user-not-found') {
            console.log('💡 Note: The user might not exist in Firebase Auth yet. Please make sure they signed up via the app first.');
        }
    } finally {
        process.exit(0);
    }
}

const email = process.argv[2];
const password = process.argv[3];

if (!email || !password) {
    console.log("Usage: node updatePassword.js <email> <new_password>");
    console.log("Example: node updatePassword.js officialegenie@gmail.com 123456");
    process.exit(1);
} else {
    // Firebase requires passwords to be at least 6 characters.
    if (password.length < 6) {
        console.log("⚠️ Warning: Firebase requires passwords to be at least 6 characters long.");
        console.log(`Setting password to ${password} anyway (Firebase might reject it). Let's try...`);
    }
    updatePassword(email, password);
}
