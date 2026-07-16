const supabase = require('../config/supabase');
const { v4: uuidv4 } = require('uuid');
const path = require('path');

class SupabaseStorage {
    constructor(opts) {
        this.bucket = opts.bucket || 'job-attachments';
    }

    _handleFile(req, file, cb) {
        const ext = path.extname(file.originalname);
        const filename = `${uuidv4()}${ext}`;

        // Collect stream data
        const chunks = [];
        file.stream.on('data', (chunk) => chunks.push(chunk));
        file.stream.on('end', async () => {
            const buffer = Buffer.concat(chunks);

            try {
                const { data, error } = await supabase.storage
                    .from(this.bucket)
                    .upload(filename, buffer, {
                        contentType: file.mimetype,
                        upsert: false
                    });

                if (error) {
                    return cb(error);
                }

                // Get Public URL
                const { data: { publicUrl } } = supabase.storage
                    .from(this.bucket)
                    .getPublicUrl(filename);

                cb(null, {
                    path: publicUrl, // Mock 'path' so controller saves URL
                    filename: filename,
                    destination: this.bucket
                });
            } catch (err) {
                cb(err);
            }
        });

        file.stream.on('error', (err) => cb(err));
    }

    _removeFile(req, file, cb) {
        supabase.storage
            .from(this.bucket)
            .remove([file.filename])
            .then(() => cb(null))
            .catch((err) => cb(err));
    }
}

module.exports = (opts) => new SupabaseStorage(opts);
