import 'package:hive/hive.dart';

part 'goal.g.dart';

@HiveType(
  typeId: 7,
) // Ensure typeId is unique across your Hive models (already have 6)
class Goal {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final double targetAmount;

  @HiveField(3)
  final double savedAmount;

  @HiveField(4)
  final String icon;

  @HiveField(5)
  final DateTime? targetDate;

  @HiveField(6)
  final bool isCompleted;

  @HiveField(7)
  final DateTime? createdAt;

  @HiveField(8)
  final DateTime? completedAt;

  Goal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0.0,
    this.icon = '🎯',
    this.targetDate,
    this.isCompleted = false,
    this.createdAt,
    this.completedAt,
  });

  // Create a copy of the goal with updated fields
  Goal copyWith({
    String? title,
    double? targetAmount,
    double? savedAmount,
    String? icon,
    DateTime? targetDate,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Goal(
      id: id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      icon: icon ?? this.icon,
      targetDate: targetDate ?? this.targetDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['\$id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      targetAmount: (json['targetAmount'] ?? 0).toDouble(),
      savedAmount: (json['savedAmount'] ?? 0).toDouble(),
      icon: json['icon'] ?? '🎯',
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'])
          : null,
      isCompleted: json['isCompleted'] ?? false,
      createdAt: json['\$createdAt'] != null
          ? DateTime.parse(json['\$createdAt'])
          : json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson({required String userId}) {
    return {
      'userId': userId,
      'title': title,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'icon': icon,
      'targetDate': targetDate?.toIso8601String(),
      'isCompleted': isCompleted,
      if (completedAt != null) 'completedAt': completedAt?.toIso8601String(),
    };
  }
}
