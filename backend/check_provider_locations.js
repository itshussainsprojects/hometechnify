const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function checkLocations() {
    try {
        const providers = await prisma.user.findMany({
            where: { role: 'PROVIDER' },
            include: {
                provider_profile: true
            }
        });

        console.log(`Found ${providers.length} providers.`);

        providers.forEach(p => {
            console.log(`Provider: ${p.name} (${p.email})`);
            if (p.provider_profile) {
                console.log(`  - CategoryID: ${p.provider_profile.service_category_id}`);
                console.log(`  - Location: ${p.provider_profile.current_lat}, ${p.provider_profile.current_lng}`);
                console.log(`  - Is Online: ${p.provider_profile.is_online}`);
            } else {
                console.log(`  - No Profile`);
            }
        });

    } catch (error) {
        console.error(error);
    } finally {
        await prisma.$disconnect();
    }
}

checkLocations();
