const mongoose = require('mongoose');

const InvestmentSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    userId: { type: String, required: true, index: true },
    name: { type: String, required: true },
    type: { type: String, default: 'Stocks' },
    investedAmount: { type: Number, default: 0 },
    currentAmount: { type: Number, default: 0 },
    quantity: { type: Number, default: 0 },
    lastUpdated: { type: Date, default: Date.now },
  },
  {
    timestamps: true,
    _id: false,
  }
);

InvestmentSchema.index({ userId: 1 });

module.exports = mongoose.models.Investment || mongoose.model('Investment', InvestmentSchema);
