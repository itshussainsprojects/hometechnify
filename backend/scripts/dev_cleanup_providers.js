// DEV cleanup - run once: node scripts/dev_cleanup_providers.js
// 1. Deletes the synthetic "Provider A"/"Provider B" test accounts.
// 2. Sets EVERY provider's is_online to false, so the only providers
//    customers see are the ones who really flip their toggle ON.
const prisma = require('../src/utils/prisma');

(async () => {
    // 1. Remove synthetic test accounts (no real data attached).
    const fakes = await prisma.user.findMany({
        where: { role: 'PROVIDER', name: { in: ['Provider A', 'Provider B'] } },
        select: { id: true, name: true },
    });
    for (const f of fakes) {
        try {
            await prisma.$transaction([
                prisma.notification.deleteMany({ where: { user_id: f.id } }),
                prisma.transaction.deleteMany({ where: { user_id: f.id } }),
                prisma.providerProfile.deleteMany({ where: { user_id: f.id } }),
                prisma.booking.deleteMany({ where: { provider_id: f.id } }),
                prisma.user.delete({ where: { id: f.id } }),
            ]);
            console.log(`deleted fake provider: ${f.name} (${f.id})`);
        } catch (e) {
            console.log(`could not delete ${f.name}: ${e.message}`);
        }
    }

    // 2. Everyone offline - availability now reflects ONLY the toggle.
    const r = await prisma.providerProfile.updateMany({
        data: { is_online: false },
    });
    console.log(`set is_online=false for ${r.count} provider profiles`);

    await prisma.$disconnect();
})();
