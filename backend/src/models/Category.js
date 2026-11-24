const mongoose = require('mongoose');

const CategorySchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    userId: { type: String, required: true, index: true },
    name: { type: String, required: true },
    icon: { type: String, default: 'category' },
    type: { type: String, default: 'expense' }, // 'expense' or 'income'
    usageCount: { type: Number, default: 0 },
    budgetLimit: { type: Number, default: 0 },
  },
  {
    timestamps: true,
    _id: false,
  }
);

CategorySchema.index({ userId: 1, type: 1 });

module.exports = mongoose.models.Category || mongoose.model('Category', CategorySchema);
