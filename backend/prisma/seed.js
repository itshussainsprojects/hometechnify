const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
    console.log('Start seeding ...');

    // 1. Create Categories
    const acCategory = await prisma.category.upsert({
        where: { name: 'AC Repair' },
        update: {},
        create: {
            name: 'AC Repair',
            icon_url: 'assets/icons/ac.png', // Placeholder or URL
        },
    });

    const plumbingCategory = await prisma.category.upsert({
        where: { name: 'Plumbing' },
        update: {},
        create: {
            name: 'Plumbing',
            icon_url: 'assets/icons/plumbing.png',
        },
    });

    const cleaningCategory = await prisma.category.upsert({
        where: { name: 'Cleaning' },
        update: {},
        create: {
            name: 'Cleaning',
            icon_url: 'assets/icons/cleaning.png',
        },
    });

    const electricalCategory = await prisma.category.upsert({
        where: { name: 'Electrical' },
        update: {},
        create: {
            name: 'Electrical',
            icon_url: 'assets/icons/electrician.png',
        },
    });

    // 2. Create Services
    await prisma.service.createMany({
        data: [
            {
                name: 'AC Service',
                price: 50.0,
                description: 'General service and cleaning of AC unit',
                category_id: acCategory.id,
            },
            {
                name: 'Gas Refill',
                price: 30.0,
                description: 'Freon gas refill for split units',
                category_id: acCategory.id,
            },
            {
                name: 'Pipe Leakage Repair',
                price: 40.0,
                description: 'Fixing water leakage in bathroom or kitchen',
                category_id: plumbingCategory.id,
            },
            {
                name: 'Tap Replacement',
                price: 15.0,
                description: 'Replacing old or broken taps',
                category_id: plumbingCategory.id,
            },
            {
                name: 'Deep Home Cleaning',
                price: 100.0,
                description: 'Full house deep cleaning service',
                category_id: cleaningCategory.id,
            },
            {
                name: 'Switch Replacement',
                price: 10.0,
                description: 'Replace broken electrical switches',
                category_id: electricalCategory.id,
            },
            {
                name: 'Wiring Repair',
                price: 50.0,
                description: 'Fix electrical wiring issues',
                category_id: electricalCategory.id,
            }
        ],
        skipDuplicates: true, // dependent on unique constraints, but helpful if re-running without upsert logic on services
    });

    console.log('Seeding finished.');
}

main()
    .then(async () => {
        await prisma.$disconnect();
    })
    .catch(async (e) => {
        console.error(e);
        await prisma.$disconnect();
        process.exit(1);
    });
