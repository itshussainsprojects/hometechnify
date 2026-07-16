const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function makeAdmin(email) {
    try {
        const user = await prisma.user.updateMany({
            where: { email: email.trim().toLowerCase() },
            data: { role: 'ADMIN' },
        });

        if (user.count > 0) {
            console.log(`✅ Success: ${email} is now an ADMIN. You can now login to the Admin Panel.`);
        } else {
            console.log(`❌ Error: User with email ${email} not found in the database. Please sign up in the app first.`);
        }
    } catch (e) {
        console.error('Error:', e.message);
    } finally {
        prisma.$disconnect();
    }
}

const email = process.argv[2];
if (!email) {
    console.log("Usage: node makeAdmin.js <user_email>");
    console.log("Example: node makeAdmin.js admin@example.com");
} else {
    makeAdmin(email);
}
