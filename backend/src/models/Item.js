const mongoose = require('mongoose');

const ItemSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    userId: { type: String, required: true, index: true },
    categoryId: { type: String, required: true, index: true },
    title: { type: String, required: true },
    amount: { type: Number, default: 0 },
    isExpense: { type: Boolean, default: true },
    usageCount: { type: Number, default: 0 },
    frequency: { type: String, default: 'monthly' },
    icon: { type: String, default: null },
    dueDay: { type: Number, default: null },
    reminderEnabled: { type: Boolean, default: false },
    isVariable: { type: Boolean, default: false },
    order: { type: Number, default: 9999 },
  },
  {
    timestamps: true,
    _id: false,
  }
);

ItemSchema.index({ userId: 1, categoryId: 1 });

module.exports = mongoose.models.Item || mongoose.model('Item', ItemSchema);
