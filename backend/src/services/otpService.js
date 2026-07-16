const crypto = require('crypto');

/**
 * Generates a 6-digit numeric OTP
 */
const generateOtp = () => {
    return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * Sends OTP to the user's phone/email.
 * Currently simulates sending by logging to console (Free tier).
 * In production, replace with Twilio (SMS) or Nodemailer (Email).
 */
const sendOtp = async (contact, otp) => {
    console.log('=========================================');
    console.log(`[OTP SERVICE] Sending OTP to ${contact}: ${otp}`);
    console.log('=========================================');
    // Future: await emailService.send(contact, otp);
    return true;
};

module.exports = {
    generateOtp,
    sendOtp,
};
