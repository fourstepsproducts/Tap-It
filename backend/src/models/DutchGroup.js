const mongoose = require('mongoose');

const DutchGroupSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    name: { type: String, required: true },
    type: { type: String, default: 'trip' },
    members: { type: [String], default: [] }, // Array of user IDs
    createdBy: { type: String, required: true, index: true },
    currency: { type: String, default: 'INR' },
    inviteCode: { type: String, default: null, index: true },
    icon: { type: String, default: null },
  },
  {
    timestamps: true,
    _id: false,
  }
);

DutchGroupSchema.index({ members: 1 });
DutchGroupSchema.index({ createdBy: 1 });

module.exports = mongoose.models.DutchGroup || mongoose.model('DutchGroup', DutchGroupSchema);
