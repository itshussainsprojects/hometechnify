const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Get all addresses for a user
const getAddresses = async (req, res) => {
    try {
        const userId = req.user.id; // Correctly use the ID from the authenticated token

        const addresses = await prisma.address.findMany({
            where: { user_id: userId },
            orderBy: { created_at: 'desc' }
        });

        res.json(addresses);
    } catch (error) {
        console.error('Error fetching addresses:', error);
        res.status(500).json({ error: 'Failed to fetch addresses' });
    }
};

// Create a new address
const createAddress = async (req, res) => {
    try {
        const userId = req.user.id; // Securely get ID from token
        const { label, address, lat, lng } = req.body;

        if (!address) {
            return res.status(400).json({ error: 'Address is required' });
        }

        const newAddress = await prisma.address.create({
            data: {
                user_id: userId,
                label: label || 'Home',
                address,
                lat: lat ? parseFloat(lat) : null,
                lng: lng ? parseFloat(lng) : null,
            }
        });

        res.status(201).json(newAddress);
    } catch (error) {
        console.error('Error creating address:', error);
        res.status(500).json({ error: 'Failed to create address' });
    }
};

// Delete an address
const deleteAddress = async (req, res) => {
    try {
        const { id } = req.params;

        await prisma.address.delete({
            where: { id }
        });

        res.json({ message: 'Address deleted successfully' });
    } catch (error) {
        console.error('Error deleting address:', error);
        res.status(500).json({ error: 'Failed to delete address' });
    }
};

module.exports = {
    getAddresses,
    createAddress,
    deleteAddress
};
