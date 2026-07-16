const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
    try {
        console.log('Attempting to connect to DB...');
        await prisma.$connect();
        console.log('Connection successful!');

        const count = await prisma.category.count();
        console.log(`Found ${count} categories.`);

    } catch (e) {
        console.error('DB Connection Failed:', e);
    } finally {
        await prisma.$disconnect();
    }
}

main();
