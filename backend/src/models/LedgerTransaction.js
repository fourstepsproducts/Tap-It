const mongoose = require('mongoose');

const LedgerTransactionSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    creatorId: { type: String, default: '' },
    senderId: { type: String, default: '', index: true },
    receiverId: { type: String, default: '', index: true },
    senderName: { type: String, default: '' },
    receiverName: { type: String, default: '' },
    senderPhone: { type: String, default: '' },
    receiverPhone: { type: String, default: '' },
    amount: { type: Number, required: true },
    description: { type: String, default: '' },
    date: { type: String, default: null },
    dateTime: { type: Date, default: Date.now },
    status: { type: String, default: 'pending' }, // 'pending', 'approved', 'declined', etc.
  },
  {
    timestamps: true,
    _id: false,
  }
);

// Indexes for ledger participant queries
LedgerTransactionSchema.index({ senderId: 1 });
LedgerTransactionSchema.index({ receiverId: 1 });
LedgerTransactionSchema.index({ creatorId: 1 });
LedgerTransactionSchema.index({ dateTime: -1 });

module.exports = mongoose.models.LedgerTransaction || mongoose.model('LedgerTransaction', LedgerTransactionSchema);
