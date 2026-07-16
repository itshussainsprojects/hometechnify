const prisma = require('./src/utils/prisma');

async function main() {
    try {
        const categories = await prisma.category.findMany();
        console.log('Categories:', categories);
    } catch (e) {
        console.error(e);
    } finally {
        await prisma.$disconnect();
    }
}

main();
