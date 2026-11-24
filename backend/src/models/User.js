const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite user ID ($id / _uid)
    name: { type: String, default: '' },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    phone: { type: String, default: '' },
    status: { type: Boolean, default: true },
    password: { type: String, required: true, select: false }, // Preserves original Argon2id hash string
    hash: { type: String, default: 'argon2', select: false }, // Matches original Appwrite column name
    hashOptions: { type: mongoose.Schema.Types.Mixed, default: null, select: false },
    emailVerification: { type: Boolean, default: false },
    phoneVerification: { type: Boolean, default: false },
  },
  {
    timestamps: true,
    _id: false, // Prevents auto-generating ObjectId; custom string _id is primary key
    toJSON: {
      transform: (doc, ret) => {
        delete ret.password;
        delete ret.hash;
        delete ret.hashOptions;
        return ret;
      },
    },
    toObject: {
      transform: (doc, ret) => {
        delete ret.password;
        delete ret.hash;
        delete ret.hashOptions;
        return ret;
      },
    },
  }
);

// Indexes
UserSchema.index({ email: 1 });

module.exports = mongoose.models.User || mongoose.model('User', UserSchema);
