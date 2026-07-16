const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function setPassword() {
    try {
        const user = await admin.auth().getUserByEmail('officialegenie@gmail.com');
        await admin.auth().updateUser(user.uid, {
            password: '03225750871@'
        });
        console.log('✅ Success: Password has been set for officialegenie@gmail.com');
        console.log('You should now be able to login with Email & Password!');
    } catch (err) {
        console.log('Error updating user password:', err.message);
    } finally {
        process.exit(0);
    }
}

setPassword();
