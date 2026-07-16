const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
    const users = await prisma.user.findMany({
        select: {
            id: true,
            email: true,
            role: true,
            name: true,
        }
    });
    console.log("Current Users in Database:");
    console.table(users);
}

main()
    .catch(console.error)
    .finally(() => prisma.$disconnect());
