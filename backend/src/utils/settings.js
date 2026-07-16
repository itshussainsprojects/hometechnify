const prisma = require('./prisma');

// Admin-configurable numeric settings (AppSetting key-value store).
// Read live at the point of use so an admin change instantly applies to
// ALL providers/customers — no restart, no per-provider update needed.
const getNumberSetting = async (key, def) => {
    try {
        const row = await prisma.appSetting.findUnique({ where: { key } });
        const v = row ? parseFloat(row.value) : def;
        return isNaN(v) ? def : v;
    } catch (_) {
        return def; // settings lookup must never break the calling flow
    }
};

// Defaults live here so every caller agrees on them.
const COMMISSION_PERCENT_DEFAULT = 12;  // % of job value charged to provider
const PROVIDER_RADIUS_KM_DEFAULT = 20;  // inDrive-style nearby search radius

const getCommissionPercent = () => getNumberSetting('commission_percent', COMMISSION_PERCENT_DEFAULT);
const getProviderRadiusKm = () => getNumberSetting('provider_radius_km', PROVIDER_RADIUS_KM_DEFAULT);

module.exports = { getNumberSetting, getCommissionPercent, getProviderRadiusKm };
