const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const SupabaseStorage = require('../utils/supabaseStorage');

// Configure storage (Supabase)
const storage = SupabaseStorage({
    bucket: 'job-attachments'
});

// File filter (Images only)
const fileFilter = (req, file, cb) => {
    if (file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/') || file.mimetype.startsWith('audio/')) {
        cb(null, true);
    } else {
        cb(new Error('Only image, video, and audio files are allowed!'), false);
    }
};

const upload = multer({
    storage: storage,
    fileFilter: fileFilter,
    limits: {
        fileSize: 100 * 1024 * 1024 // 100MB limit for video files
    }
});

module.exports = upload;
