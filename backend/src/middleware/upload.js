const multer = require('multer');
const path = require('path');
const { profilesDir } = require('../config/storage');

// Max file size: 5MB
const MAX_FILE_SIZE = 5 * 1024 * 1024;

// Allowed MIME types
const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

// Storage configuration
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, profilesDir);
  },
  filename: (req, file, cb) => {
    // Derive sanitized user ID from authenticated user or fallback
    const userId = (req.user && (req.user.id || req.user._id))
      ? String(req.user.id || req.user._id).replace(/[^a-zA-Z0-9_-]/g, '')
      : 'user';
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    const timestamp = Date.now();
    cb(null, `profile_${userId}_${timestamp}${ext}`);
  },
});

// File filter for image types
const fileFilter = (req, file, cb) => {
  if (ALLOWED_MIME_TYPES.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type. Only JPEG, PNG, and WEBP images are allowed.'), false);
  }
};

const profileUpload = multer({
  storage,
  limits: {
    fileSize: MAX_FILE_SIZE,
  },
  fileFilter,
});

module.exports = {
  profileUpload,
  MAX_FILE_SIZE,
};
