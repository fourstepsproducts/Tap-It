const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const { profileUpload } = require('../middleware/upload');
const {
  uploadProfilePhoto,
  deleteProfilePhoto,
} = require('../controllers/uploadController');

// Multer error handling wrapper
const handleUpload = (req, res, next) => {
  profileUpload.single('image')(req, res, (err) => {
    if (err) {
      return res.status(400).json({
        success: false,
        message: err.message || 'File upload error.',
      });
    }
    next();
  });
};

/**
 * @route   POST /api/upload/profile
 * @desc    Upload or replace user profile photo
 * @access  Private
 */
router.post('/profile', authMiddleware, handleUpload, uploadProfilePhoto);

/**
 * @route   DELETE /api/upload/profile
 * @desc    Delete user profile photo
 * @access  Private
 */
router.delete('/profile', authMiddleware, deleteProfilePhoto);

module.exports = router;
