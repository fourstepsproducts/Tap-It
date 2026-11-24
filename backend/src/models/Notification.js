const mongoose = require('mongoose');

const NotificationSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    userId: { type: String, required: true, index: true },
    title: { type: String, required: true },
    message: { type: String, required: true },
    type: { type: String, default: 'general' },
    isRead: { type: Boolean, default: false },
    settlementId: { type: String, default: null },
    scheduledDate: { type: Date, default: null },
  },
  {
    timestamps: true,
    _id: false,
  }
);

NotificationSchema.index({ userId: 1, isRead: 1 });

module.exports = mongoose.models.Notification || mongoose.model('Notification', NotificationSchema);
