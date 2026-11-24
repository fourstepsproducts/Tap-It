const mongoose = require('mongoose');

const DutchExpenseSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    groupId: { type: String, required: true, index: true },
    payerId: { type: String, required: true, index: true },
    description: { type: String, required: true },
    amount: { type: Number, required: true },
    dateTime: { type: Date, default: Date.now },
    category: { type: String, default: 'General' },
    splitType: { type: String, default: 'equal' }, // 'equal', 'exact', 'percentage'
    splitData: { type: mongoose.Schema.Types.Mixed, default: {} },
    receiptFileId: { type: String, default: null },
    createdBy: { type: String, default: '' },
    status: { type: String, default: 'active' },
  },
  {
    timestamps: true,
    _id: false,
  }
);

DutchExpenseSchema.index({ groupId: 1, dateTime: -1 });

module.exports = mongoose.models.DutchExpense || mongoose.model('DutchExpense', DutchExpenseSchema);
