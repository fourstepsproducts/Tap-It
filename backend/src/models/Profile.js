const mongoose = require('mongoose');

const ProfileSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    userId: { type: String, required: true, index: true }, // Foreign key to User._id
    name: { type: String, default: '' },
    email: { type: String, default: '' },
    phone: { type: String, default: '' },
    photoUrl: { type: String, default: null },
    banks: { type: [String], default: [] },
    primaryPaymentMethods: { type: mongoose.Schema.Types.Mixed, default: {} }, // Preserves JSON string, Map, Object, or null
    customPaymentMethods: { type: mongoose.Schema.Types.Mixed, default: [] }, // Preserves JSON string, Array, Object, or null
  },
  {
    timestamps: true,
    _id: false,
  }
);

// Indexes for fast lookup by user and phone/name search (contact matching)
ProfileSchema.index({ userId: 1 });
ProfileSchema.index({ phone: 1 });
ProfileSchema.index({ name: 1 });

module.exports = mongoose.models.Profile || mongoose.model('Profile', ProfileSchema);
