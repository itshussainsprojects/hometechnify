const express = require('express');
const router = express.Router();
const upload = require('../middleware/uploadMiddleware');
const { uploadFile } = require('../controllers/uploadController');
const authMiddleware = require('../middleware/authMiddleware');

// Route: POST /api/upload
// Auth required, expecting form-data with key 'file'
router.post('/', authMiddleware, upload.single('file'), uploadFile);

module.exports = router;
