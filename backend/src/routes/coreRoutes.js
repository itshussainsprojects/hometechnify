
const express = require('express');
const {
    getCategories,
    createCategory,
    updateCategory,
    deleteCategory,
    getServices,
    createService,
    updateService,
    deleteService,
    getActivePromos,
} = require('../controllers/coreController');
const authMiddleware = require('../middleware/authMiddleware');
const requireAdmin = require('../middleware/requireAdmin');
const optionalAuth = require('../middleware/optionalAuth');
const upload = require('../middleware/uploadMiddleware');

const router = express.Router();

// Admin can upload an icon image as `icon`, or just send an iconUrl string.
// upload.single() is a no-op for plain JSON bodies, so both forms work.
const iconUpload = upload.single('icon');

// Categories (public read, admin-only write).
// optionalAuth so the admin panel additionally sees internal categories like
// "Uncategorized"; customers get only bookable ones.
router.get('/categories', optionalAuth, getCategories);
router.post('/categories', authMiddleware, requireAdmin, iconUpload, createCategory);
router.put('/categories/:id', authMiddleware, requireAdmin, iconUpload, updateCategory);
router.delete('/categories/:id', authMiddleware, requireAdmin, deleteCategory);

// Services (public read, admin-only write)
router.get('/services', getServices);
router.post('/services', authMiddleware, requireAdmin, iconUpload, createService);
router.put('/services/:id', authMiddleware, requireAdmin, iconUpload, updateService);
router.delete('/services/:id', authMiddleware, requireAdmin, deleteService);

// Promos (public read — used by home screen)
router.get('/promos', getActivePromos);

module.exports = router;
