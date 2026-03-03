import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
import '../models/goal.dart';
import '../config/appwrite_config.dart';
import '../services/appwrite_service.dart';

class GoalProvider extends ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();
  bool _isInitialized = false;
  bool _isLoading = false;
  List<Goal> _goals = [];

  List<Goal> get goals => _goals;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  // For the MVP banner, we'll just show the principal active goal (e.g., first one not completed)
  Goal? get primaryGoal {
    if (_goals.isEmpty) return null;
    try {
      return _goals.firstWhere((g) => !g.isCompleted);
    } catch (e) {
      return _goals.first; // Fallback to first if all completed
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    await fetchGoals();
    _isInitialized = true;
  }

  Future<String?> _getUserId() async {
    final user = await _appwriteService.getCurrentUser();
    return user?['userId'] ?? user?['\$id'];
  }

  Future<void> fetchGoals() async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = await _getUserId();
      if (userId == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final result = await _appwriteService.databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.goalsCollectionId,
        queries: [
          Query.equal('userId', [userId]),
        ],
      );

      _goals = result.documents.map((doc) => Goal.fromJson(doc.data)).toList();
    } catch (e) {
      debugPrint('Error fetching goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addGoal(Goal goal) async {
    try {
      final userId = await _getUserId();
      if (userId == null) throw Exception('User not logged in');

      // Calculate completion info before adding
      bool isCompleted = goal.savedAmount >= goal.targetAmount;
      final finalGoal = goal.copyWith(
        isCompleted: isCompleted,
        completedAt: isCompleted ? DateTime.now() : null,
      );

      // Add to Appwrite
      await _appwriteService.databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.goalsCollectionId,
        documentId: ID.unique(), // Appwrite ID auto-generation
        data: finalGoal.toJson(userId: userId),
        permissions: [
          Permission.read(Role.user(userId)),
          Permission.write(Role.user(userId)),
          Permission.update(Role.user(userId)),
          Permission.delete(Role.user(userId)),
        ],
      );

      // Refresh list
      await fetchGoals();
    } catch (e) {
      debugPrint('Error adding goal: $e');
      rethrow;
    }
  }

  Future<void> updateGoal(Goal goal) async {
    try {
      final userId = await _getUserId();
      if (userId == null) throw Exception('User not logged in');

      // Check completion status
      bool isCompleted = goal.savedAmount >= goal.targetAmount;
      DateTime? completedAt = goal.completedAt;

      // If newly completed
      if (isCompleted && !goal.isCompleted) {
        completedAt = DateTime.now();
      } else if (!isCompleted) {
        // If no longer completed
        completedAt = null;
      }

      final updatedGoal = goal.copyWith(
        isCompleted: isCompleted,
        completedAt: completedAt,
      );

      // Update in Appwrite
      await _appwriteService.databases.updateDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.goalsCollectionId,
        documentId: updatedGoal.id,
        data: updatedGoal.toJson(userId: userId),
      );

      // Refresh list
      await fetchGoals();
    } catch (e) {
      debugPrint('Error updating goal: $e');
      rethrow;
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      // Delete in Appwrite
      await _appwriteService.databases.deleteDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.goalsCollectionId,
        documentId: id,
      );

      // Refresh list
      await fetchGoals();
    } catch (e) {
      debugPrint('Error deleting goal: $e');
      rethrow;
    }
  }

  Future<void> addFundToGoal(String goalId, double amount) async {
    try {
      final goal = _goals.firstWhere((g) => g.id == goalId);

      double newSavedAmount = goal.savedAmount + amount;

      final updatedGoal = goal.copyWith(savedAmount: newSavedAmount);

      await updateGoal(updatedGoal);
    } catch (e) {
      debugPrint('Error adding funds to goal: $e');
      rethrow;
    }
  }
}
