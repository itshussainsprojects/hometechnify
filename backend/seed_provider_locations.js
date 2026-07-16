const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function seedLocations() {
    try {
        const providers = await prisma.user.findMany({
            where: { role: 'PROVIDER' },
            include: { provider_profile: true }
        });

        console.log(`Updating ${providers.length} providers...`);

        // Taxila/Rawalpindi Center (User's location)
        const baseLat = 33.7463;
        const baseLng = 72.7867;

        for (let i = 0; i < providers.length; i++) {
            const p = providers[i];
            // Offset slightly for each provider (spread radius approx 2km)
            const lat = baseLat + (Math.random() * 0.02 - 0.01);
            const lng = baseLng + (Math.random() * 0.02 - 0.01);

            if (p.provider_profile) {
                await prisma.providerProfile.update({
                    where: { id: p.provider_profile.id },
                    data: {
                        current_lat: lat,
                        current_lng: lng,
                        is_online: true
                    }
                });
                console.log(`Updated ${p.name} location to ${lat}, ${lng}`);
            }
        }

        console.log("Done seeding locations.");

    } catch (error) {
        console.error(error);
    } finally {
        await prisma.$disconnect();
    }
}

seedLocations();
