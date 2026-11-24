const mongoose = require('mongoose');

const DutchSettlementSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    groupId: { type: String, required: true, index: true },
    payerId: { type: String, required: true, index: true },
    receiverId: { type: String, required: true, index: true },
    amount: { type: Number, required: true },
    dateTime: { type: Date, default: Date.now },
    method: { type: String, default: 'cash' },
    status: { type: String, default: 'completed' }, // 'pending', 'completed'
  },
  {
    timestamps: true,
    _id: false,
  }
);

DutchSettlementSchema.index({ groupId: 1 });

module.exports = mongoose.models.DutchSettlement || mongoose.model('DutchSettlement', DutchSettlementSchema);
