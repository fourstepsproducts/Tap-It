const fs = require('fs');
const path = require('path');
const { profilesDir } = require('../config/storage');
const User = require('../models/User');

/**
 * Builds public full URL for an image filename.
 */
const getPublicPhotoUrl = (req, filename) => {
  const baseUrl = process.env.BASE_URL || `${req.protocol}://${req.get('host')}`;
  return `${baseUrl}/uploads/profiles/${filename}`;
};

/**
 * Safely removes a file from the profiles storage directory.
 * Ensures the target file resides strictly within profilesDir to prevent path traversal.
 */
const safeDeleteFile = (filenameOrPath) => {
  try {
    if (!filenameOrPath) return;

    // Extract bare filename to prevent directory traversal
    const safeFilename = path.basename(filenameOrPath);
    const resolvedPath = path.resolve(profilesDir, safeFilename);

    // Verify the resolved path stays strictly inside profilesDir
    const normalizedProfilesDir = path.resolve(profilesDir);
    if (!resolvedPath.startsWith(normalizedProfilesDir + path.sep)) {
      console.error('Security alert: Attempted file deletion outside profiles directory:', resolvedPath);
      return;
    }

    if (fs.existsSync(resolvedPath)) {
      fs.unlinkSync(resolvedPath);
    }
  } catch (error) {
    console.error('Failed to safely delete image file:', error);
  }
};

/**
 * Extracts filename from a stored photoUrl.
 */
const getFilenameFromUrl = (photoUrl) => {
  if (!photoUrl) return null;
  const parts = photoUrl.split('/');
  const filename = parts[parts.length - 1];
  return path.basename(filename);
};

/**
 * Upload or replace profile photo.
 * Step 1: File is already validated and written to disk by Multer middleware.
 * Step 2: Query user's current record in MongoDB.
 * Step 3: Update photoUrl in database.
 * Step 4: ONLY after DB update succeeds, safely delete previous photo file.
 * If DB update fails, clean up the newly uploaded file to avoid orphaned data.
 */
const uploadProfilePhoto = async (req, res) => {
  if (!req.file) {
    return res.status(400).json({
      success: false,
      message: 'No image file uploaded or invalid file format.',
    });
  }

  const userId = req.user.id || req.user._id;
  const newFilePath = req.file.path;
  const newFilename = req.file.filename;
  const newPhotoUrl = getPublicPhotoUrl(req, newFilename);

  let oldFilename = null;

  try {
    // 1. Fetch current user from MongoDB
    const user = await User.findById(userId);
    if (user && user.photoUrl) {
      oldFilename = getFilenameFromUrl(user.photoUrl);
    }

    // 2. Update user profile with new photoUrl
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { $set: { photoUrl: newPhotoUrl } },
      { new: true, upsert: true }
    );

    // 3. Only after DB update succeeds, delete the previous image
    if (oldFilename && oldFilename !== newFilename) {
      safeDeleteFile(oldFilename);
    }

    return res.status(200).json({
      success: true,
      message: 'Profile photo uploaded successfully',
      data: {
        photoUrl: updatedUser.photoUrl,
        filename: newFilename,
        size: req.file.size,
        mimeType: req.file.mimetype,
      },
    });
  } catch (error) {
    // Failure safety: clean up the newly uploaded file if database write fails
    safeDeleteFile(newFilePath);
    console.error('Error saving profile photo to database:', error);

    return res.status(500).json({
      success: false,
      message: 'Failed to update profile photo in database.',
      error: error.message,
    });
  }
};

/**
 * Delete profile photo.
 * Safely removes file from disk and nullifies photoUrl in DB.
 */
const deleteProfilePhoto = async (req, res) => {
  const userId = req.user.id || req.user._id;

  try {
    const user = await User.findById(userId);
    if (!user || !user.photoUrl) {
      return res.status(404).json({
        success: false,
        message: 'No profile photo found to delete.',
      });
    }

    const filename = getFilenameFromUrl(user.photoUrl);

    // 1. Update DB first
    user.photoUrl = null;
    await user.save();

    // 2. Delete file from storage
    if (filename) {
      safeDeleteFile(filename);
    }

    return res.status(200).json({
      success: true,
      message: 'Profile photo deleted successfully',
      data: {
        photoUrl: null,
      },
    });
  } catch (error) {
    console.error('Error deleting profile photo:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to delete profile photo.',
      error: error.message,
    });
  }
};

module.exports = {
  uploadProfilePhoto,
  deleteProfilePhoto,
};
