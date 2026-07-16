const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
    const users = await prisma.user.findMany({
        select: {
            id: true,
            firebaseUid: true,
            name: true,
            email: true,
            profileImage: true,
        }
    });

    console.log("=== All Users in Database ===");
    console.log("Total users:", users.length);
    console.log("");

    users.forEach((user, i) => {
        console.log(`--- User ${i + 1} ---`);
        console.log(`ID: ${user.id}`);
        console.log(`Firebase UID: ${user.firebaseUid}`);
        console.log(`Name: ${user.name}`);
        console.log(`Email: ${user.email}`);
        console.log(`ProfileImage: ${user.profileImage || 'NULL'}`);
        console.log("");
    });
}

main()
    .catch(console.error)
    .finally(() => prisma.$disconnect());
