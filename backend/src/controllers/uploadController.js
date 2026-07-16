const uploadFile = (req, res) => {
    if (!req.file) {
        return res.status(400).json({ success: false, message: 'No file uploaded' });
    }

    // Construct public URL
    // Assuming server is accessed via IP in local network
    // The strict way is to use env var for BASE_URL, but for now we can infer relative path
    // or return the path relative to /assets

    const filename = req.file.filename;
    // Use the path provided by the storage engine (Supabase Public URL)
    const fileUrl = req.file.path;

    res.status(200).json({
        success: true,
        message: 'File uploaded successfully',
        data: {
            url: fileUrl,
            filename: filename,
            mimetype: req.file.mimetype
        }
    });
};

module.exports = { uploadFile };
