const prisma = require('./prisma');

/// Smart Bidding — enforce the price floor/ceiling the admin set on a service.
///
/// This lived inside bookingController and was therefore applied to bookings and
/// counter-offers only. The provider's FIRST quote goes through jobController's
/// acceptJob, which never called it — so the one screen where a provider actually
/// names their price was the one place the fence did not exist. A provider could
/// quote Rs. 1 or Rs. 100,000 on a service the admin had bounded to Rs. 500–1,500.
///
/// Returns { ok, message }.
const validateBidPrice = async (serviceId, amount) => {
    if (!serviceId || amount == null) return { ok: true };

    const service = await prisma.service.findUnique({
        where: { id: serviceId },
        select: { name: true, min_price: true, max_price: true },
    });
    if (!service) return { ok: true };

    const amt = parseFloat(amount);
    if (Number.isNaN(amt)) {
        return { ok: false, message: 'Price must be a number' };
    }
    if (amt <= 0) {
        return { ok: false, message: 'Price must be greater than zero' };
    }
    if (service.min_price != null && amt < service.min_price) {
        return { ok: false, message: `Minimum price for ${service.name} is Rs. ${service.min_price}` };
    }
    if (service.max_price != null && amt > service.max_price) {
        return { ok: false, message: `Maximum price for ${service.name} is Rs. ${service.max_price}` };
    }
    return { ok: true };
};

module.exports = { validateBidPrice };
