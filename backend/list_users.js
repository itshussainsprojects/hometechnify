const { PrismaClient } = require('@prisma/client');
const p = new PrismaClient();

p.user.findMany().then(users => {
    users.forEach(u => {
        console.log('---');
        console.log('ID:', u.id);
        console.log('Email:', u.email);
        console.log('Firebase:', u.firebaseUid);
        console.log('Image:', u.profileImage ? u.profileImage.substring(0, 60) + '...' : 'NULL');
    });
    p.$disconnect();
}).catch(e => {
    console.error(e);
    p.$disconnect();
});
