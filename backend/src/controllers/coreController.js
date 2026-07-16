
const prisma = require('../utils/prisma');

// Internal parking category for providers who have not been assigned a trade
// yet. It is a bookkeeping bucket, not something a customer can book, so it is
// hidden from the public category list (the admin panel still sees it).
const INTERNAL_CATEGORIES = ['Uncategorized'];

// ─── CATEGORIES ───────────────────────────────
const getCategories = async (req, res) => {
    try {
        // The admin panel needs to see every category (to reassign providers);
        // customers must only ever see bookable ones.
        const isAdmin = req.user?.role === 'ADMIN';

        const categories = await prisma.category.findMany({
            where: isAdmin ? {} : { name: { notIn: INTERNAL_CATEGORIES } },
            include: { _count: { select: { services: true } } },
            orderBy: { name: 'asc' },
        });
        res.json({ success: true, data: categories });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const createCategory = async (req, res) => {
    try {
        const { name, iconUrl } = req.body;
        if (!name) return res.status(400).json({ success: false, message: 'Name is required' });
        // Icon can arrive as an uploaded file (multipart) or a plain URL.
        const category = await prisma.category.create({
            data: { name, icon_url: req.file?.path || iconUrl || null },
        });
        res.status(201).json({ success: true, data: category });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const updateCategory = async (req, res) => {
    try {
        const { id } = req.params;
        const { name, iconUrl } = req.body;
        const icon = req.file?.path || iconUrl;
        const category = await prisma.category.update({
            where: { id },
            data: {
                ...(name && { name }),
                ...(icon !== undefined && { icon_url: icon || null }),
            },
        });
        res.json({ success: true, data: category });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const deleteCategory = async (req, res) => {
    try {
        const { id } = req.params;
        await prisma.category.delete({ where: { id } });
        res.json({ success: true, message: 'Category deleted' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─── SERVICES ───────────────────────────────
const getServices = async (req, res) => {
    try {
        const { categoryId } = req.query;
        const where = categoryId ? { category_id: categoryId } : {};
        const services = await prisma.service.findMany({
            where,
            include: { category: true },
            orderBy: { name: 'asc' },
        });
        res.json({ success: true, data: services });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const createService = async (req, res) => {
    try {
        const { categoryId, name, price, description, minPrice, maxPrice, iconUrl } = req.body;
        if (!categoryId || !name) return res.status(400).json({ success: false, message: 'categoryId and name are required' });

        const min = minPrice !== undefined && minPrice !== null && minPrice !== '' ? parseFloat(minPrice) : null;
        const max = maxPrice !== undefined && maxPrice !== null && maxPrice !== '' ? parseFloat(maxPrice) : null;
        if (min != null && max != null && min > max) {
            return res.status(400).json({ success: false, message: 'Minimum price cannot be greater than maximum price' });
        }

        // Nothing on this platform costs a negative amount, and a service priced
        // below zero would flow straight into the commission maths.
        const p = parseFloat(price || 0);
        if (isNaN(p) || p < 0) {
            return res.status(400).json({ success: false, message: 'Price cannot be negative' });
        }
        if ((min != null && min < 0) || (max != null && max < 0)) {
            return res.status(400).json({ success: false, message: 'The bid range cannot be negative' });
        }

        // Icon can arrive either as an uploaded file (multipart) or a plain URL.
        const icon = req.file?.path || iconUrl || null;

        const service = await prisma.service.create({
            data: {
                category_id: categoryId,
                name,
                price: p,
                description,
                icon_url: icon,
                min_price: min,
                max_price: max,
            },
            include: { category: true },
        });
        res.status(201).json({ success: true, data: service });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const updateService = async (req, res) => {
    try {
        const { id } = req.params;
        const { name, price, description, categoryId, minPrice, maxPrice, iconUrl } = req.body;

        const icon = req.file?.path || iconUrl;

        const parseBound = (v) => (v === '' || v === null ? null : parseFloat(v));
        const min = minPrice !== undefined ? parseBound(minPrice) : undefined;
        const max = maxPrice !== undefined ? parseBound(maxPrice) : undefined;

        // Same guards as create — an edit must not be able to slip past them.
        if (price !== undefined) {
            const p = parseFloat(price);
            if (isNaN(p) || p < 0) {
                return res.status(400).json({ success: false, message: 'Price cannot be negative' });
            }
        }
        if ((min != null && min < 0) || (max != null && max < 0)) {
            return res.status(400).json({ success: false, message: 'The bid range cannot be negative' });
        }
        if (min != null && max != null && min > max) {
            return res.status(400).json({ success: false, message: 'Minimum price cannot be greater than maximum price' });
        }

        const data = {
            ...(name && { name }),
            ...(price !== undefined && { price: parseFloat(price) }),
            ...(description !== undefined && { description }),
            ...(categoryId && { category_id: categoryId }),
            ...(icon !== undefined && { icon_url: icon || null }),
            ...(min !== undefined && { min_price: min }),
            ...(max !== undefined && { max_price: max }),
        };

        const service = await prisma.service.update({
            where: { id },
            data,
            include: { category: true },
        });
        res.json({ success: true, data: service });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

const deleteService = async (req, res) => {
    try {
        const { id } = req.params;
        await prisma.service.delete({ where: { id } });
        res.json({ success: true, message: 'Service deleted' });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

// ─── PUBLIC PROMOS ───────────────────────────────
const getActivePromos = async (req, res) => {
    try {
        const promos = await prisma.promo.findMany({
            where: { is_active: true },
            orderBy: { created_at: 'desc' },
        });
        res.json({ success: true, data: promos });
    } catch (err) {
        res.status(500).json({ success: false, message: err.message });
    }
};

module.exports = {
    getCategories,
    createCategory,
    updateCategory,
    deleteCategory,
    getServices,
    createService,
    updateService,
    deleteService,
    getActivePromos,
};
