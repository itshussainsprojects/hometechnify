const express = require('express');
const router = express.Router();
const jobController = require('../controllers/jobController');
const authMiddleware = require('../middleware/authMiddleware');
const upload = require('../middleware/uploadMiddleware');

// Protected Routes
router.use(authMiddleware);

// Create Job (with multiple files support - max 5)
router.post('/', upload.array('media', 5), jobController.createJob);

// Get My Jobs (as Customer)
router.get('/my-jobs', jobController.getMyJobs);

// Get Nearby Jobs (as Provider)
router.get('/nearby', jobController.getNearbyJobs); // Should probably filter by role in future

// Accept Job (as Provider)
router.post('/:id/accept', jobController.acceptJob);

// Update Job
router.put('/:id', upload.array('media', 5), jobController.updateJob);

// Delete Job
router.delete('/:id', jobController.deleteJob);

module.exports = router;
