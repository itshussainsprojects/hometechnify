const express = require('express');
const { getAddresses, createAddress, deleteAddress } = require('../controllers/addressController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware); // Protect all address routes

router.get('/', getAddresses);
router.post('/', createAddress);
router.delete('/:id', deleteAddress);

module.exports = router;
