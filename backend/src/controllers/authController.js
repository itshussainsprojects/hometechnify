
const prisma = require('../utils/prisma');

const syncUser = async (req, res) => {
    try {
        const { uid, email, phone_number, name, picture } = req.firebaseUser;
        const bodyName = req.body.name; // Allow client to send name
        const bodyPhone = req.body.phone; // Allow client to send phone if missing in token
        const fcmToken = req.body.fcmToken; // Capture FCM Token

        // Check if user exists
        let user = await prisma.user.findUnique({
            where: { firebaseUid: uid },
        });

        if (!user) {
            // Create new user.
            // SECURITY: never trust a client-supplied ADMIN role. Only CUSTOMER
            // or PROVIDER may be self-selected at signup; ADMIN is granted
            // exclusively via a trusted server script (see makeAdmin.js).
            const role = req.body.role === 'PROVIDER' ? 'PROVIDER' : 'CUSTOMER';

            // A provider needs a category row to exist at all, but this must NOT
            // guess at their trade.
            //
            // It used to take `category.findFirst()` — literally whatever category
            // happened to be first in the table — which meant every provider who
            // ever signed up was silently filed as a plumber. (There was a
            // hardcoded category UUID here as a fallback, too.) They then only ever
            // saw plumbing jobs, and any other category an admin created stayed
            // permanently empty.
            //
            // They now land in the "Uncategorized" parking bucket: no jobs match it,
            // the admin panel shows them as NO TRADE SET, and onboarding immediately
            // overwrites it with the trade they actually picked.
            let categoryId = null;
            if (role === 'PROVIDER') {
                const parking = await prisma.category.findFirst({ where: { name: 'Uncategorized' } })
                    ?? await prisma.category.create({ data: { name: 'Uncategorized' } });
                categoryId = parking.id;
            }

            // For new users, use provided name or fallback
            const userName = bodyName || name || 'New User';
            const userEmail = email || `no-email-${uid}@temp.com`;

            user = await prisma.user.create({
                data: {
                    firebaseUid: uid,
                    email: userEmail,
                    name: userName,
                    phone: bodyPhone || phone_number,
                    profileImage: picture,
                    fcmToken: fcmToken,
                    role: role,

                    provider_profile: role === 'PROVIDER' ? {
                        create: {
                            service_category_id: categoryId,
                            hourly_rate: 0.0,
                            experience: '0 years',
                            bio: userName, // Use name as initial bio
                        }
                    } : undefined
                },
            });

            console.log(`✅ Created new user: ${user.email} as ${role}`);
        } else {
            // ROLE SEPARATION: an account belongs to exactly one surface.
            // A provider must not sign in on the customer app, a customer must
            // not sign in on the provider app, and an admin must not sign in on
            // either — admins belong on the admin panel, which sends no role and
            // is gated separately by requireAdmin on every /admin route.
            const requestedRole = req.body.role;
            if (
                (requestedRole === 'CUSTOMER' || requestedRole === 'PROVIDER') &&
                user.role !== requestedRole
            ) {
                console.log(`⛔ Role mismatch: ${user.email} is ${user.role}, tried to use ${requestedRole} app`);
                const message = {
                    PROVIDER: 'This account is registered as a Service Provider. Please use the Provider app to sign in.',
                    CUSTOMER: 'This account is registered as a Customer. Please use the Customer app to sign in.',
                    ADMIN: 'This is an admin account. Please sign in from the Admin panel.',
                }[user.role] || 'This account cannot be used on this app.';

                return res.status(403).json({
                    success: false,
                    code: 'ROLE_MISMATCH',
                    accountRole: user.role,
                    message,
                });
            }

            // Update existing user - ONLY UPDATE IF WE HAVE BETTER DATA
            // Don't overwrite existing good data with null or defaults
            const updateData = {};

            // Only update name if current is a placeholder AND we have new value
            const isPlaceholderName = !user.name || user.name === 'New User' || user.name === 'Provider';
            if (isPlaceholderName && (bodyName || name)) {
                updateData.name = bodyName || name;
            }

            // Only update phone if missing
            if (!user.phone && (bodyPhone || phone_number)) {
                updateData.phone = bodyPhone || phone_number;
            }

            // Only update profileImage if user has none
            if (!user.profileImage && picture) {
                updateData.profileImage = picture;
            }

            // Always update FCM token if provided
            if (fcmToken) {
                updateData.fcmToken = fcmToken;
            }

            if (Object.keys(updateData).length > 0) {
                user = await prisma.user.update({
                    where: { id: user.id },
                    data: updateData,
                });
                console.log(`✅ Updated user: ${user.email}, changes: ${JSON.stringify(updateData)}`);
            } else {
                console.log(`ℹ️ No updates needed for user: ${user.email}`);
            }
        }

        // SELF-HEAL: a PROVIDER with no provider_profile is a dead account.
        // Everything a provider does hangs off that row — the availability toggle,
        // the wallet, the dashboard, job matching. Without it they can never go
        // Available, so they never get work and the app just looks broken to them.
        // A handful of accounts ended up in exactly that state. Rather than leave
        // them stranded, create the missing row on their next sign-in.
        if (user.role === 'PROVIDER') {
            const profile = await prisma.providerProfile.findUnique({
                where: { user_id: user.id },
                select: { id: true },
            });
            if (!profile) {
                const category = await prisma.category.findFirst({ where: { name: 'Uncategorized' } })
                    ?? await prisma.category.findFirst();
                if (category) {
                    await prisma.providerProfile.create({
                        data: {
                            user_id: user.id,
                            service_category_id: category.id,
                            hourly_rate: 0,
                            experience: '0 years',
                            bio: user.name || 'Provider',
                            // Never auto-verify. An admin must still approve them.
                            is_verified: false,
                            is_online: false,
                        },
                    });
                    console.log(`🩹 Created the missing provider_profile for ${user.email}`);
                } else {
                    console.error(`Cannot create provider_profile for ${user.email}: no categories exist`);
                }
            }
        }

        // The client calls /auth/me straight after this for the full profile.
        res.status(200).json({ success: true, user });

    } catch (error) {
        console.error('Sync Error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

const getMe = async (req, res) => {
    try {
        const { uid } = req.firebaseUser;
        console.log("=== GET ME REQUEST ===");
        console.log("Firebase UID:", uid);

        const user = await prisma.user.findUnique({
            where: { firebaseUid: uid },
            include: { provider_profile: true }
        });

        console.log("Found user:", user?.email);
        console.log("User name:", user?.name);
        console.log("User profileImage:", user?.profileImage);

        if (!user) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        // Compute status
        let status = 'active';
        if (user.role === 'PROVIDER') {
            // If no profile or not verified, it's pending
            if (!user.provider_profile || !user.provider_profile.is_verified) {
                status = 'pending_verification';
            }
        }

        res.status(200).json({ success: true, data: { ...user, status } });
    } catch (error) {
        console.error('Get Me Error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

const updateMe = async (req, res) => {
    try {
        const { uid } = req.firebaseUser;
        const { name, phone, profileImage, fcmToken } = req.body;

        console.log("=== UPDATE ME REQUEST ===");
        console.log("Body:", req.body);
        console.log("profileImage received:", profileImage);

        const user = await prisma.user.update({
            where: { firebaseUid: uid },
            data: {
                name: name || undefined,
                phone: phone || undefined,
                profileImage: profileImage || undefined,
                fcmToken: fcmToken || undefined,
            },
        });

        console.log("Updated user profileImage:", user.profileImage);

        res.status(200).json({ success: true, data: user });
    } catch (error) {
        console.error('Update Me Error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

const deleteUser = async (req, res) => {
    try {
        const { uid } = req.firebaseUser;
        console.log("=== DELETE USER REQUEST ===");
        console.log("Deleting user with Firebase UID:", uid);

        // Delete from Postgres
        const deletedUser = await prisma.user.delete({
            where: { firebaseUid: uid },
        });

        console.log("Deleted user from DB:", deletedUser.email);

        res.status(200).json({ success: true, message: 'User deleted successfully' });
    } catch (error) {
        console.error('Delete User Error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Lets the registration form warn a signing-up provider (or customer)
// BEFORE they fill in the rest of a multi-step form, rather than finding out
// only when Firebase Auth itself rejects the final submit with a generic
// "email already in use". Public/no-auth by design — there is no session
// yet at this point in the flow. Only existence + role is returned, never
// name/phone/other PII, to keep the email-enumeration surface minimal.
const checkEmail = async (req, res) => {
    try {
        const email = (req.query.email || '').trim().toLowerCase();
        if (!email) {
            return res.status(400).json({ success: false, message: 'email is required' });
        }

        const user = await prisma.user.findUnique({
            where: { email },
            select: { role: true },
        });

        res.status(200).json({
            success: true,
            data: { exists: !!user, role: user?.role || null },
        });
    } catch (error) {
        console.error('Check Email Error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

module.exports = { syncUser, getMe, updateMe, deleteUser, checkEmail };
