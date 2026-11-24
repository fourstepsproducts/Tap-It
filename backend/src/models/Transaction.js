const mongoose = require('mongoose');

const TransactionSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    userId: { type: String, required: true, index: true },
    title: { type: String, required: true },
    amount: { type: Number, required: true },
    isExpense: { type: Boolean, default: true },
    dateTime: { type: Date, default: Date.now },
    categoryId: { type: String, default: null, index: true },
    itemId: { type: String, default: null, index: true },
    ledgerId: { type: String, default: null },
    paymentMethod: { type: String, default: null },
  },
  {
    timestamps: true,
    _id: false,
  }
);

TransactionSchema.index({ userId: 1, dateTime: -1 });

module.exports = mongoose.models.Transaction || mongoose.model('Transaction', TransactionSchema);
