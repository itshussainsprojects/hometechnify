const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

async function checkUser() {
    try {
        const user = await admin.auth().getUserByEmail('officialegenie@gmail.com');
        console.log('User found in Firebase:');
        console.log('UID:', user.uid);
        console.log('Email:', user.email);
        console.log('Providers:', user.providerData.map(p => p.providerId));
    } catch (err) {
        console.log('Error fetching user:', err.message);
    }
}

checkUser();
