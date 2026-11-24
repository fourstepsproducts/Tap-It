const path = require('path');
const fs = require('fs');

// Persistent storage path:
// In production VPS, set process.env.UPLOAD_STORAGE_PATH='/var/data/tapit/uploads'
// Otherwise defaults to backend/uploads
const baseUploadDir = process.env.UPLOAD_STORAGE_PATH
  ? path.resolve(process.env.UPLOAD_STORAGE_PATH)
  : path.join(__dirname, '../../uploads');

const profilesDir = path.join(baseUploadDir, 'profiles');

// Ensure directory exists
if (!fs.existsSync(profilesDir)) {
  fs.mkdirSync(profilesDir, { recursive: true });
}

module.exports = {
  baseUploadDir,
  profilesDir,
};
