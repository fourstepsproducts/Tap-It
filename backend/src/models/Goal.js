const mongoose = require('mongoose');

const GoalSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true }, // Appwrite document $id
    userId: { type: String, required: true, index: true },
    title: { type: String, required: true },
    targetAmount: { type: Number, required: true },
    savedAmount: { type: Number, default: 0 },
    icon: { type: String, default: '🎯' }, // UTF-8 encoded Unicode emoji
    targetDate: { type: Date, default: null },
    isCompleted: { type: Boolean, default: false },
    completedAt: { type: Date, default: null },
  },
  {
    timestamps: true,
    _id: false,
  }
);

GoalSchema.index({ userId: 1, isCompleted: 1 });

module.exports = mongoose.models.Goal || mongoose.model('Goal', GoalSchema);
