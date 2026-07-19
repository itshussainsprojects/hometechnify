const nodemailer = require('nodemailer');

// Gmail SMTP via an App Password. This requires 2-Step Verification to be
// enabled on the sending account — a regular Gmail password is rejected by
// Google's SMTP servers for third-party apps.
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_APP_PASSWORD,
    },
});

/// Sends an email and never throws — an email hiccup must not break whatever
/// admin/user action triggered it (matches sendNotification's own contract).
const sendEmail = async (to, subject, html) => {
    if (!process.env.EMAIL_USER || !process.env.EMAIL_APP_PASSWORD) {
        console.log('Email skipped: EMAIL_USER/EMAIL_APP_PASSWORD not configured.');
        return false;
    }
    if (!to) {
        console.log('Email skipped: recipient has no email address.');
        return false;
    }

    try {
        await transporter.sendMail({
            from: `"HomeTechnify" <${process.env.EMAIL_USER}>`,
            to,
            subject,
            html,
        });
        console.log(`Email sent to ${to}: ${subject}`);
        return true;
    } catch (error) {
        console.error('Email send failed:', error.message);
        return false;
    }
};

const sendProviderVerifiedEmail = async (to, name) => {
    return sendEmail(
        to,
        'You\'re verified on HomeTechnify!',
        `
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
          <h2 style="color: #0B72D8;">Congratulations${name ? `, ${name}` : ''}!</h2>
          <p>Your documents have been reviewed and approved by the HomeTechnify team.</p>
          <p>You can now go <strong>Available</strong> in the app and start receiving job requests.</p>
          <p style="color: #667085; font-size: 13px; margin-top: 32px;">— The HomeTechnify Team</p>
        </div>
        `
    );
};

const sendProviderRevokedEmail = async (to, name) => {
    return sendEmail(
        to,
        'Your HomeTechnify verification was revoked',
        `
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto;">
          <h2 style="color: #E24C4C;">Verification Revoked</h2>
          <p>Hi${name ? ` ${name}` : ''},</p>
          <p>Your provider verification has been revoked. Please contact HomeTechnify support for details.</p>
          <p style="color: #667085; font-size: 13px; margin-top: 32px;">— The HomeTechnify Team</p>
        </div>
        `
    );
};

module.exports = {
    sendEmail,
    sendProviderVerifiedEmail,
    sendProviderRevokedEmail,
};
