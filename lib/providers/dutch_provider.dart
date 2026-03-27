import 'dart:convert';
import 'package:flutter/material.dart';

import '../services/dutch_service.dart';
import '../services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/widget_service.dart';

class DutchProvider extends ChangeNotifier {
  final DutchService _service = DutchService();

  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = false;
  String? _error;
  bool _isInit = true; // Flag for first build

  bool _hasMoreGroups = true;
  String? _lastGroupId;
  bool get hasMoreGroups => _hasMoreGroups;

  // Join Group
  Future<bool> joinGroup(String inviteCode) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (_currentUserId == null) {
        final user = await AppwriteService().account.get();
        _currentUserId = user.$id;
      }

      await AppwriteService().joinGroup(inviteCode, _currentUserId!);
      await fetchGroups(); // Refresh list to show new group
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update Group
  Future<bool> updateGroup(String groupId, String name, String type) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AppwriteService().updateGroup(
        groupId: groupId,
        name: name,
        type: type,
      );

      // Update local list
      final index = _groups.indexWhere((g) => g['id'] == groupId);
      if (index != -1) {
        _groups[index]['name'] = name;
        _groups[index]['type'] = type;
        // Keep other fields same
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete Group
  Future<bool> deleteGroup(String groupId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AppwriteService().deleteGroup(groupId);

      // Update local list
      _groups.removeWhere((g) => g['id'] == groupId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Current Group State
  String? _currentGroupId;
  String? _currentUserId;
  List<Map<String, dynamic>> _currentGroupExpenses = [];
  List<Map<String, dynamic>> _currentGroupMemberProfiles = [];

  List<Map<String, dynamic>> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserId => _currentUserId;
  String? get currentGroupId => _currentGroupId;

  List<Map<String, dynamic>> get currentGroupExpenses => _currentGroupExpenses;
  List<Map<String, dynamic>> get currentGroupMemberProfiles =>
      _currentGroupMemberProfiles;

  // Settlements
  List<Map<String, dynamic>> _currentGroupSettlements = [];
  Map<String, double> _groupBalances = {}; // userId -> amount (+ owed, - owes)
  final Map<String, Map<String, dynamic>> _optimisticSettlements =
      {}; // key -> settlement

  List<Map<String, dynamic>> get currentGroupSettlements =>
      _currentGroupSettlements;
  Map<String, double> get groupBalances => _groupBalances;

  /// Returns a map of detailed statistics for each member in the current group.
  /// Result: { userId: { 'consumed': double, 'paid': double, 'netPaid': double, 'balance': double } }
  Map<String, Map<String, double>> getMemberStats() {
    final Map<String, Map<String, double>> stats = {};

    // Initialize for all group members
    for (var profile in _currentGroupMemberProfiles) {
      final uid = _safeId(profile['userId']);
      if (uid.isEmpty) continue;
      stats[uid] = {
        'consumed': 0.0,
        'paid': 0.0,
        'netPaid': 0.0,
        'balance': _groupBalances[uid] ?? 0.0,
      };
    }

    // Process expenses to calculate consumed share and total paid
    for (var expense in _currentGroupExpenses) {
      if (expense['status'] != 'completed' && expense['status'] != 'pending') {
        continue;
      }

      final payerId = _safeId(expense['payerId']);
      final amount = (expense['amount'] as num).toDouble();
      final splitType = expense['splitType'] ?? 'equal';
      final splitDataRaw = expense['splitData'];

      // Add to payer's total paid
      if (stats.containsKey(payerId)) {
        stats[payerId]!['paid'] = (stats[payerId]!['paid'] ?? 0) + amount;
        stats[payerId]!['netPaid'] = (stats[payerId]!['netPaid'] ?? 0) + amount;
      }

      // Add to beneficiaries' consumed share
      try {
        if (splitType == 'equal') {
          final List beneficiaries = jsonDecode(splitDataRaw);
          final perPerson = amount / beneficiaries.length;
          for (var uidNode in beneficiaries) {
            final uid = _safeId(uidNode);
            if (stats.containsKey(uid)) {
              stats[uid]!['consumed'] =
                  (stats[uid]!['consumed'] ?? 0) + perPerson;
            }
          }
        } else if (splitType == 'exact') {
          final Map beneficiaries = jsonDecode(splitDataRaw);
          beneficiaries.forEach((uidNode, val) {
            final uid = _safeId(uidNode);
            if (stats.containsKey(uid)) {
              stats[uid]!['consumed'] =
                  (stats[uid]!['consumed'] ?? 0) + (val as num).toDouble();
            }
          });
        }
      } catch (e) {
        // ignore: empty_catches
      }
    }

    // Process settlements to adjust netPaid
    for (var settlement in _currentGroupSettlements) {
      if (settlement['status'] != 'completed') continue;

      final pId = _safeId(settlement['payerId']);
      final rId = _safeId(settlement['receiverId']);
      final amount = (settlement['amount'] as num).toDouble();

      if (stats.containsKey(pId)) {
        stats[pId]!['netPaid'] = (stats[pId]!['netPaid'] ?? 0) + amount;
      }
      if (stats.containsKey(rId)) {
        stats[rId]!['netPaid'] = (stats[rId]!['netPaid'] ?? 0) - amount;
      }
    }

    return stats;
  }

  // Global Settlements for Notifications
  List<Map<String, dynamic>> get incomingSettlementRequests {
    if (_currentUserId == null) return [];
    return _globalSettlements
        .where(
          (s) =>
              _safeId(s['receiverId']) == _currentUserId &&
              s['status'] == 'pending',
        )
        .toList();
  }

  List<Map<String, dynamic>> get outgoingSettlementRequests {
    if (_currentUserId == null) return [];
    return _globalSettlements
        .where(
          (s) =>
              _safeId(s['payerId']) == _currentUserId &&
              s['status'] == 'pending',
        )
        .toList();
  }

  // Helper to extract ID string regardless of whether it's a String or Map
  String _safeId(dynamic val) {
    if (val == null) return '';
    if (val is String) return val;
    if (val is Map) {
      return val['\$id'] ?? val['id'] ?? '';
    }
    return val.toString();
  }

  /// Get the count of pending items (expenses + settlements) for a specific group
  int getPendingCount(String groupId) {
    final pendingExpenses = _globalExpenses
        .where(
          (e) => _safeId(e['groupId']) == groupId && e['status'] == 'pending',
        )
        .length;

    final pendingSettlements = _globalSettlements
        .where(
          (s) => _safeId(s['groupId']) == groupId && s['status'] == 'pending',
        )
        .length;

    return pendingExpenses + pendingSettlements;
  }

  Future<void> syncWidget({String? currency}) async {
    try {
      String symbol = currency ?? '₹';
      if (currency == null) {
        final prefs = await SharedPreferences.getInstance();
        symbol = prefs.getString('currency_symbol') ?? '₹';
      }

      final yourShare = getGlobalUserShare();
      
      int globalPendingCount = 0;
      for (var e in _globalExpenses) {
        if (e['status'] == 'pending') globalPendingCount++;
      }
      for (var s in _globalSettlements) {
        if (s['status'] == 'pending' && _safeId(s['receiverId']) == _currentUserId) {
          globalPendingCount++;
        }
      }

      final top3 = _groups.take(3).map((g) {
        return {
          'title': g['name'] as String? ?? 'Group',
          'id': g['id'] as String? ?? '',
        };
      }).toList();

      await WidgetService.updateSplitWidgetData(
        yourShare: yourShare,
        groupCount: _groups.length,
        pendingCount: globalPendingCount,
        currency: symbol,
        topGroups: top3,
      );
    } catch (e) {
      // ignore
    }
  }

  // Calculate Total Owed/Owe globally (across all groups) - Future implementation

  Future<void> fetchGroups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _groups = await _service.getMyGroups(limit: 25);
      if (_groups.isNotEmpty) {
        _lastGroupId = _safeId(_groups.last);
        _hasMoreGroups = _groups.length >= 25;
      } else {
        _hasMoreGroups = false;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      syncWidget();
      notifyListeners();
    }
  }

  Future<void> loadMoreGroups() async {
    if (!_hasMoreGroups || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      final newData = await _service.getMyGroups(
        lastId: _lastGroupId,
        limit: 25,
      );
      if (newData.isNotEmpty) {
        _groups.addAll(newData);
        _lastGroupId = _safeId(newData.last);
        _hasMoreGroups = newData.length >= 25;
      } else {
        _hasMoreGroups = false;
      }
    } catch (e) {
      // ignore: empty_catches
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // GLOBAL DATA
  List<Map<String, dynamic>> _globalExpenses = [];
  List<Map<String, dynamic>> _globalSettlements = [];
  Map<String, double> _globalBalances = {};
  List<Map<String, dynamic>> _globalMemberProfiles = [];

  bool _hasMoreExpenses = true;
  String? _lastExpenseId;
  bool _hasMoreSettlements = true;
  String? _lastSettlementId;

  List<Map<String, dynamic>> get globalExpenses => _globalExpenses;
  List<Map<String, dynamic>> get globalSettlements => _globalSettlements;
  Map<String, double> get globalBalances => _globalBalances;
  List<Map<String, dynamic>> get globalMemberProfiles => _globalMemberProfiles;
  bool get hasMoreExpenses => _hasMoreExpenses;
  bool get hasMoreSettlements => _hasMoreSettlements;

  Future<void> fetchGlobalData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Get current user ID
      final account = AppwriteService().account;
      final user = await account.get();
      _currentUserId = user.$id;

      final results = await Future.wait([
        _service.getAllExpenses(),
        _service.getAllSettlements(),
      ]);
      _globalExpenses = results[0];
      final List<Map<String, dynamic>> allSettlements = results[1];

      if (_globalExpenses.isNotEmpty) {
        _lastExpenseId = _safeId(_globalExpenses.last);
        _hasMoreExpenses = _globalExpenses.length >= 25;
      } else {
        _globalExpenses = [];
        _hasMoreExpenses = false;
      }

      if (allSettlements.isNotEmpty) {
        _lastSettlementId = _safeId(allSettlements.last);
        _hasMoreSettlements = allSettlements.length >= 25;
      } else {
        _hasMoreSettlements = false;
      }

      _mergeSettlements(allSettlements: allSettlements);

      // If server returned nothing, ensure local state is cleared
      if (_globalExpenses.isEmpty && allSettlements.isEmpty) {
        _globalSettlements = [];
        _globalBalances = {};
      }

      _calculateGlobalBalances();

      // Fetch profiles for all users in global balances
      await _fetchGlobalMemberProfiles();
    } catch (e) {
      if (e is! AppwriteException || e.code != 401) {
        // ignore: empty_catches
      }
    } finally {
      _isLoading = false;
      syncWidget();
      if (_isInit) {
        Future.microtask(() => notifyListeners());
        _isInit = false;
      } else {
        notifyListeners();
      }
    }
  }

  void _calculateGlobalBalances() {
    _globalBalances = {};
    // Reuse logic or refactor to generic method
    _calculateBalancesFor(_globalExpenses, _globalSettlements, _globalBalances);
  }

  Future<void> _fetchGlobalMemberProfiles() async {
    try {
      // Get all unique user IDs from global balances
      final Set<String> userIds = _globalBalances.keys.toSet();

      if (userIds.isNotEmpty) {
        _globalMemberProfiles = await AppwriteService().getProfilesByIds(
          userIds.toList(),
        );
      } else {
        _globalMemberProfiles = [];
      }
    } catch (e) {
      _globalMemberProfiles = [];
    }
  }

  // Refactored Helper
  void _calculateBalancesFor(
    List<Map<String, dynamic>> expenses,
    List<Map<String, dynamic>> settlements,
    Map<String, double> balancesMap,
  ) {
    // 1. Process Expenses
    for (var expense in expenses) {
      // Include both completed and pending expenses in balance
      if (expense['status'] != 'completed' && expense['status'] != 'pending') {
        continue;
      }

      final payerId = expense['payerId'];
      final amount = (expense['amount'] as num).toDouble();
      final splitType = expense['splitType'] ?? 'equal';
      final splitDataRaw = expense['splitData'];

      // Add to payer's total (they are owed this amount initially)
      balancesMap[payerId] = (balancesMap[payerId] ?? 0) + amount;

      // Subtract from beneficiaries
      if (splitType == 'equal') {
        // splitData is a JSON list of userIds
        try {
          final List beneficiaries = jsonDecode(splitDataRaw);
          final perPerson = amount / beneficiaries.length;
          for (var uid in beneficiaries) {
            balancesMap[uid] = (balancesMap[uid] ?? 0) - perPerson;
          }
        } catch (e) {
          // ignore: empty_catches
        }
      } else if (splitType == 'exact') {
        // splitData is a JSON map of {userId: amount}
        try {
          final Map beneficiaries = jsonDecode(splitDataRaw);
          beneficiaries.forEach((uid, val) {
            balancesMap[uid] =
                (balancesMap[uid] ?? 0) - (val as num).toDouble();
          });
        } catch (e) {
          // ignore: empty_catches
        }
      }
    }

    // 2. Process Settlements
    for (var settlement in settlements) {
      // Only count completed settlements
      if (settlement['status'] != 'completed') continue;

      final payerId = settlement['payerId'];
      final receiverId = settlement['receiverId'];
      final amount = (settlement['amount'] as num).toDouble();

      balancesMap[payerId] = (balancesMap[payerId] ?? 0) + amount;
      balancesMap[receiverId] = (balancesMap[receiverId] ?? 0) - amount;
    }
  }

  Future<bool> createGroup({
    required String name,
    required String type,
    required List<String> members,
    required String createdBy,
    required String icon,
    String currency = '₹',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newGroup = await _service.createGroup(
        name: name,
        type: type,
        members: members,
        createdBy: createdBy,
        currency: currency,
        icon: icon,
      );
      if (newGroup != null) {
        _groups.insert(0, newGroup);
        return true;
      }
      _error = "Failed to create group (Service returned null)";
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectGroup(String groupId) async {
    _currentGroupId = groupId;
    _currentGroupExpenses = [];
    _currentGroupSettlements = [];
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch current user ID if not already set
      if (_currentUserId == null) {
        final user = await AppwriteService().account.get();
        _currentUserId = user.$id;
      }

      final results = await Future.wait([
        _service.getGroupExpenses(groupId),
        _service.getGroupSettlements(groupId),
      ]);

      _currentGroupExpenses = results[0];
      if (_currentGroupExpenses.isNotEmpty) {
        _lastGroupExpenseId = _safeId(_currentGroupExpenses.last);
        _hasMoreGroupExpenses = _currentGroupExpenses.length >= 25;
      } else {
        _hasMoreGroupExpenses = false;
      }

      _currentGroupSettlements = results[1];
      if (_currentGroupSettlements.isNotEmpty) {
        _lastGroupSettlementId = _safeId(_currentGroupSettlements.last);
        _hasMoreGroupSettlements = _currentGroupSettlements.length >= 25;
      } else {
        _hasMoreGroupSettlements = false;
      }

      // Fetch profiles for members
      Map<String, dynamic>? group;
      try {
        group = _groups.firstWhere((g) => g['id'] == groupId);
      } catch (_) {
        // Fetch group directly from service for resilience
        group = await _service.getGroupById(groupId);
        // If still not found and groups list is empty, refresh all groups
        if (group == null && _groups.isEmpty) {
          await fetchGroups();
          try {
            group = _groups.firstWhere((g) => g['id'] == groupId);
          } catch (_) {}
        }
      }

      if (group != null) {
        final List<String> memberIds = List<String>.from(
          group['members'] ?? [],
        );
        if (memberIds.isNotEmpty) {
          _currentGroupMemberProfiles = await AppwriteService()
              .getProfilesByIds(memberIds);
        }
      }

      _calculateBalances();

      // Auto-check if any pending expenses should be marked as completed
      _checkPendingExpensesForCompletion();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- PAGINATION METHODS ---

  Future<void> loadMoreGlobalExpenses() async {
    if (_isLoading || !_hasMoreExpenses) return;
    _isLoading = true;
    notifyListeners();
    try {
      final newData = await _service.getAllExpenses(lastId: _lastExpenseId);
      if (newData.isNotEmpty) {
        _globalExpenses.addAll(newData);
        _lastExpenseId = _safeId(newData.last);
        _hasMoreExpenses = newData.length >= 25;
        _calculateGlobalBalances();
      } else {
        _hasMoreExpenses = false;
      }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreGlobalSettlements() async {
    if (_isLoading || !_hasMoreSettlements) return;
    _isLoading = true;
    notifyListeners();
    try {
      final newData = await _service.getAllSettlements(
        lastId: _lastSettlementId,
      );
      if (newData.isNotEmpty) {
        _globalSettlements.addAll(newData);
        _lastSettlementId = _safeId(newData.last);
        _hasMoreSettlements = newData.length >= 25;
        _mergeSettlements();
        _calculateGlobalBalances();
      } else {
        _hasMoreSettlements = false;
      }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _hasMoreGroupExpenses = true;
  String? _lastGroupExpenseId;
  bool _hasMoreGroupSettlements = true;
  String? _lastGroupSettlementId;

  bool get hasMoreGroupExpenses => _hasMoreGroupExpenses;
  bool get hasMoreGroupSettlements => _hasMoreGroupSettlements;

  Future<void> loadMoreGroupExpenses() async {
    if (_currentGroupId == null || _isLoading || !_hasMoreGroupExpenses) return;
    _isLoading = true;
    notifyListeners();
    try {
      final newData = await _service.getGroupExpenses(
        _currentGroupId!,
        lastId: _lastGroupExpenseId,
      );
      if (newData.isNotEmpty) {
        _currentGroupExpenses.addAll(newData);
        _lastGroupExpenseId = _safeId(newData.last);
        _hasMoreGroupExpenses = newData.length >= 25;
      } else {
        _hasMoreGroupExpenses = false;
      }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreGroupSettlements() async {
    if (_currentGroupId == null || _isLoading || !_hasMoreGroupSettlements) {
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final newData = await _service.getGroupSettlements(
        _currentGroupId!,
        lastId: _lastGroupSettlementId,
      );
      if (newData.isNotEmpty) {
        _currentGroupSettlements.addAll(newData);
        _lastGroupSettlementId = _safeId(newData.last);
        _hasMoreGroupSettlements = newData.length >= 25;
      } else {
        _hasMoreGroupSettlements = false;
      }
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _checkPendingExpensesForCompletion() {
    // Check all pending expenses to see if they should be auto-completed
    for (var expense in _currentGroupExpenses) {
      if (expense['status'] == 'pending') {
        final expenseId = _safeId(expense['id']);
        if (expenseId.isNotEmpty) {
          _checkAndCompleteExpense(expenseId);
        }
      }
    }
  }

  void _calculateBalances() {
    _groupBalances = {};
    _calculateBalancesFor(
      _currentGroupExpenses,
      _currentGroupSettlements,
      _groupBalances,
    );
  }

  /// Calculate the current user's actual share (money out of pocket)
  /// This shows: Total amount paid in expenses - Total settlements received
  double getUserShare() {
    if (_currentUserId == null) return 0.0;

    double totalPaid = 0.0;
    double settlementsReceived = 0.0;

    // Calculate total amount the user paid for expenses
    for (var expense in _currentGroupExpenses) {
      if (expense['status'] != 'completed' && expense['status'] != 'pending') {
        continue;
      }
      final payerId = _safeId(expense['payerId']);
      if (payerId == _currentUserId) {
        totalPaid += (expense['amount'] as num).toDouble();
      }
    }

    // Calculate total settlements received (completed only)
    for (var settlement in _currentGroupSettlements) {
      if (settlement['status'] != 'completed') continue;
      final receiverId = _safeId(settlement['receiverId']);
      final payerId = _safeId(settlement['payerId']);

      if (receiverId == _currentUserId) {
        settlementsReceived += (settlement['amount'] as num).toDouble();
      }
      // Also account for settlements the user PAID (increases out-of-pocket)
      if (payerId == _currentUserId) {
        totalPaid += (settlement['amount'] as num).toDouble();
      }
    }

    return totalPaid - settlementsReceived;
  }

  /// Calculate the user's share across ALL groups with optional date filtering
  /// This shows: Total amount paid in all expenses - Total settlements received + Settlements paid
  /// If startDate is provided, only includes expenses/settlements after that date
  double getGlobalUserShare({DateTime? startDate}) {
    if (_currentUserId == null) return 0.0;

    double totalPaid = 0.0;
    double settlementsReceived = 0.0;
    double settlementsPaid = 0.0;

    // Calculate total amount the user paid for expenses across all groups
    for (var expense in _globalExpenses) {
      if (expense['status'] != 'completed' && expense['status'] != 'pending') {
        continue;
      }

      // Apply date filter if specified
      if (startDate != null) {
        // Use $createdAt field from Appwrite
        final createdAtStr = expense['\$createdAt'] as String?;
        if (createdAtStr != null) {
          final expenseDate = DateTime.tryParse(createdAtStr);
          if (expenseDate == null || expenseDate.isBefore(startDate)) {
            continue;
          }
        }
      }

      final payerId = expense['payerId'];
      if (payerId == _currentUserId) {
        totalPaid += (expense['amount'] as num).toDouble();
      }
    }

    // Calculate settlements (completed only) across all groups
    for (var settlement in _globalSettlements) {
      if (settlement['status'] != 'completed') continue;

      // Apply date filter if specified
      if (startDate != null) {
        // Use $createdAt field from Appwrite
        final createdAtStr = settlement['\$createdAt'] as String?;
        if (createdAtStr != null) {
          final settlementDate = DateTime.tryParse(createdAtStr);
          if (settlementDate == null || settlementDate.isBefore(startDate)) {
            continue;
          }
        }
      }

      final receiverId = _safeId(settlement['receiverId']);
      final payerId = _safeId(settlement['payerId']);

      // Money received (reduces our out-of-pocket)
      if (receiverId == _currentUserId) {
        settlementsReceived += (settlement['amount'] as num).toDouble();
      }

      // Money paid out (increases our out-of-pocket)
      if (payerId == _currentUserId) {
        settlementsPaid += (settlement['amount'] as num).toDouble();
      }
    }

    return totalPaid - settlementsReceived + settlementsPaid;
  }

  Future<void> addExpense({
    required String description,
    required double amount,
    required String category,
    required String paidBy,
    required String splitType,
    required String splitData, // JSON
    required List<String> groupMembers,
  }) async {
    if (_currentGroupId == null) return;

    // Optimistic Update (Optional, maybe skip for complexity initially)
    _isLoading = true;
    notifyListeners();

    try {
      final expense = await _service.addExpense(
        groupId: _currentGroupId!,
        description: description,
        amount: amount,
        category: category,
        paidBy: paidBy,
        splitType: splitType,
        splitData: splitData,
        groupMembers: groupMembers,
      );

      if (expense != null) {
        _currentGroupExpenses.insert(0, expense);
        _calculateBalances();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> settleDebt({
    required String payerId,
    required String receiverId,
    required double amount,
    required List<String> groupMembers,
    String? expenseId,
  }) async {
    if (_currentGroupId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _service.settleDebt(
        groupId: _currentGroupId!,
        payerId: payerId,
        receiverId: receiverId,
        amount: amount,
        groupMembers: groupMembers,
        expenseId: expenseId,
      );

      if (success) {
        String payerName = 'Someone';
        try {
          payerName =
              _currentGroupMemberProfiles.firstWhere(
                (p) => p['userId'] == payerId,
                orElse: () => {},
              )['name'] ??
              'Someone';
        } catch (_) {}

        // Create optimistic settlement (but no notifications yet)
        final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
        final tempDoc = {
          'id': tempId,
          'expenseId': expenseId,
          'payerId': payerId,
          'receiverId': receiverId,
          'amount': amount,
          'status': 'pending',
          'isOptimistic': true,
        };

        // Key to track this unique settlement attempt
        final syncKey =
            '${_safeId(expenseId)}_${_safeId(payerId)}_${_safeId(receiverId)}';
        _optimisticSettlements[syncKey] = tempDoc;

        // Merge immediately for UI feedback
        _mergeSettlements();
        _calculateBalances();
        notifyListeners();

        // Delay refetch to wait for DB indexing
        await Future.delayed(const Duration(seconds: 2));

        final settlements = await _service.getGroupSettlements(
          _currentGroupId!,
        );

        // Find the real settlement that matches our optimistic one
        Map<String, dynamic>? confirmedSettlement;
        for (var s in settlements) {
          // Use _safeId to ensure we match even if IDs are wrapped in objects
          final realExpId = _safeId(s['expenseId']);
          final optExpId = _safeId(expenseId);

          final sameExpense =
              realExpId == optExpId ||
              (realExpId.isEmpty && optExpId.isNotEmpty);
          final samePayer = _safeId(s['payerId']) == _safeId(payerId);
          final sameReceiver = _safeId(s['receiverId']) == _safeId(receiverId);

          if (samePayer && sameReceiver && sameExpense) {
            // Reconstruct key for removal
            final k =
                '${_safeId(optExpId)}_${_safeId(payerId)}_${_safeId(receiverId)}';

            // PATCH: If server missed the expenseId, backfill it from our local knowledge
            // This ensures UI links it correctly (Green Tick)
            if (realExpId.isEmpty && optExpId.isNotEmpty) {
              s['expenseId'] = optExpId;
            }
            confirmedSettlement = s;
            _optimisticSettlements.remove(k);
            break;
          }
        }

        // Send notifications ONLY after confirming the settlement exists in DB
        if (confirmedSettlement != null) {
          final realSettlementId = confirmedSettlement['id'];

          // Notify the Receiver
          await AppwriteService().createNotification(
            receiverId: receiverId,
            title: 'Payment Received',
            message:
                '$payerName has sent ₹${amount.toStringAsFixed(2)}. Please approve it.',
            type: 'settlement',
            settlementId: realSettlementId,
          );

          // Notify the Payer (Immediate confirmation)
          // Commented out to prevent duplicate notifications if backend sends one
          /*
          await AppwriteService().createNotification(
            receiverId: payerId,
            title: 'Payment Sent',
            message: 'You sent ₹${amount.toStringAsFixed(2)} to $receiverName.',
            type: 'settlement',
            settlementId: realSettlementId,
          );
          */
        }

        _mergeSettlements(newSettlements: settlements);
        _calculateBalances();

        // Check if any pending expenses should be completed now
        // (in case settlements were approved before this refresh)
        _checkPendingExpensesForCompletion();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _mergeSettlements({
    List<Map<String, dynamic>>? newSettlements,
    List<Map<String, dynamic>>? allSettlements,
  }) {
    if (newSettlements != null) {
      _currentGroupSettlements = newSettlements;
      // Mirror to global
      for (var s in newSettlements) {
        final gIdx = _globalSettlements.indexWhere(
          (gs) => _safeId(gs['id']) == _safeId(s['id']),
        );
        if (gIdx == -1) {
          _globalSettlements.add(s);
        } else {
          _globalSettlements[gIdx] = s;
        }
      }
    }

    if (allSettlements != null) {
      _globalSettlements = allSettlements;
    }

    // Cleanup: Remove optimistic settlements that are now confirmed in the global list
    _globalSettlements.removeWhere((gs) {
      // Only check optimistic ones
      if (!_safeId(gs['id']).startsWith('temp_')) return false;

      final matchStart = _globalSettlements.any((s) {
        if (_safeId(s['id']).startsWith('temp_')) return false;

        final realExpId = _safeId(s['expenseId']);
        final optExpId = _safeId(gs['expenseId']);

        // Relaxed expense check: Allow match if Real is empty but Optimistic has one
        final sameExpense =
            realExpId == optExpId || (realExpId.isEmpty && optExpId.isNotEmpty);

        final samePayer = _safeId(s['payerId']) == _safeId(gs['payerId']);
        final sameReceiver =
            _safeId(s['receiverId']) == _safeId(gs['receiverId']);

        final amt1 = (s['amount'] as num).toDouble().toStringAsFixed(2);
        final amt2 = (gs['amount'] as num).toDouble().toStringAsFixed(2);
        final sameAmount = amt1 == amt2;

        if (sameExpense && samePayer && sameReceiver && sameAmount) {
          // PATCH: Backfill missing expenseId so UI works
          if (realExpId.isEmpty && optExpId.isNotEmpty) {
            s['expenseId'] = optExpId;
          }
          return true;
        }

        return false;
      });

      return matchStart;
    });

    // Re-inject remaining optimistic settlements into global
    for (var opt in _optimisticSettlements.values) {
      final exists = _globalSettlements.any(
        (s) =>
            _safeId(s['id']) ==
                _safeId(opt['id']) || // THIS EXACT temp is already there
            (!_safeId(s['id']).startsWith('temp_') &&
                (_safeId(s['expenseId']) == _safeId(opt['expenseId'])) &&
                _safeId(s['payerId']) == _safeId(opt['payerId']) &&
                _safeId(s['receiverId']) == _safeId(opt['receiverId']) &&
                (s['amount'] as num).toDouble().toStringAsFixed(2) ==
                    (opt['amount'] as num).toDouble().toStringAsFixed(2)),
      );
      if (!exists) {
        _globalSettlements.insert(0, opt);
      }
    }

    // Also ensure current group settlements reflect the optimistic ones if we are in a group
    if (_currentGroupId != null) {
      for (var opt in _optimisticSettlements.values) {
        // Only if it belongs to this group
        if (opt['groupId'] == _currentGroupId || opt['isOptimistic'] == true) {
          final alreadyPresentInGroup = _currentGroupSettlements.any(
            (s) =>
                _safeId(s['id']) ==
                    _safeId(opt['id']) || // THIS EXACT temp is already there
                (!_safeId(s['id']).startsWith('temp_') &&
                    (_safeId(s['expenseId']) == _safeId(opt['expenseId'])) &&
                    _safeId(s['payerId']) == _safeId(opt['payerId']) &&
                    _safeId(s['receiverId']) == _safeId(opt['receiverId'])),
          );
          if (!alreadyPresentInGroup) {
            _currentGroupSettlements.insert(0, opt);
          }
        }
      }

      // Remove matching temps from group list too
      _currentGroupSettlements.removeWhere((gs) {
        if (!_safeId(gs['id']).startsWith('temp_')) return false;
        return _currentGroupSettlements.any(
          (s) =>
              !_safeId(s['id']).startsWith('temp_') &&
              (_safeId(s['expenseId']) == _safeId(gs['expenseId'])) &&
              _safeId(s['payerId']) == _safeId(gs['payerId']) &&
              _safeId(s['receiverId']) == _safeId(gs['receiverId']),
        );
      });
    }
  }

  Future<void> approveExpense(String expenseId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _service.updateExpenseStatus(
        expenseId,
        'completed',
      );
      if (success) {
        // Update local state
        final index = _currentGroupExpenses.indexWhere(
          (e) => e['id'] == expenseId,
        );
        if (index != -1) {
          _currentGroupExpenses[index]['status'] = 'completed';
          _calculateBalances();
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> rejectExpense(String expenseId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _service.updateExpenseStatus(expenseId, 'rejected');
      if (success) {
        final index = _currentGroupExpenses.indexWhere(
          (e) => e['id'] == expenseId,
        );
        if (index != -1) {
          _currentGroupExpenses[index]['status'] = 'rejected';
          _calculateBalances();
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> approveSettlement(String settlementId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _service.updateSettlementStatus(
        settlementId,
        'completed',
      );
      if (success) {
        // Update Group list
        final gIndex = _currentGroupSettlements.indexWhere(
          (s) => _safeId(s['id']) == _safeId(settlementId),
        );
        if (gIndex != -1) {
          _currentGroupSettlements[gIndex]['status'] = 'completed';
        }

        // Update Global list
        final globalIndex = _globalSettlements.indexWhere(
          (s) => _safeId(s['id']) == _safeId(settlementId),
        );
        if (globalIndex != -1) {
          _globalSettlements[globalIndex]['status'] = 'completed';
        }

        // Trigger balance recalculation and UI update
        _calculateBalances();
        _calculateGlobalBalances();
        notifyListeners();

        // Check if related expense is now fully settled
        final settlement = gIndex != -1
            ? _currentGroupSettlements[gIndex]
            : (globalIndex != -1 ? _globalSettlements[globalIndex] : null);

        var expenseId = _safeId(settlement?['expenseId']);

        // FALLBACK: If expenseId is missing, try to find the expense by matching settlement details
        if (expenseId.isEmpty && settlement != null) {
          final sPayer = _safeId(settlement['payerId']);
          final sReceiver = _safeId(settlement['receiverId']);
          final sAmount = (settlement['amount'] as num?)?.toDouble() ?? 0.0;

          // Find expense where this person owes the receiver
          for (var exp in _currentGroupExpenses) {
            final expPayerId = _safeId(exp['payerId']);
            if (expPayerId != sReceiver) {
              continue; // Settlement receiver must be expense payer
            }

            final splitType = exp['splitType'];
            final splitDataRaw = exp['splitData'];

            try {
              if (splitType == 'equal') {
                final List ids = jsonDecode(splitDataRaw);
                if (!ids.contains(sPayer)) continue;
                final amount = (exp['amount'] as num).toDouble();
                final perPerson = amount / ids.length;
                if (perPerson.toStringAsFixed(2) ==
                    sAmount.toStringAsFixed(2)) {
                  expenseId = _safeId(exp['id']);

                  break;
                }
              } else if (splitType == 'exact') {
                final Map data = jsonDecode(splitDataRaw);
                final share = data[sPayer];
                if (share != null &&
                    (share as num).toDouble().toStringAsFixed(2) ==
                        sAmount.toStringAsFixed(2)) {
                  expenseId = _safeId(exp['id']);

                  break;
                }
              }
            } catch (e) {
              // ignore: empty_catches
            }
          }
        }

        if (expenseId.isNotEmpty) {
          _checkAndCompleteExpense(expenseId);
        } else {}
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _checkAndCompleteExpense(String expenseId) async {
    final expenseIndex = _currentGroupExpenses.indexWhere(
      (e) => e['id'] == expenseId,
    );
    if (expenseIndex == -1) return;

    final expense = _currentGroupExpenses[expenseIndex];
    if (expense['status'] == 'completed') return;

    final payerId = expense['payerId'];
    final splitType = expense['splitType'];
    final splitDataRaw = expense['splitData'];

    try {
      List<String> expectedPayers = [];
      if (splitType == 'equal') {
        final List ids = jsonDecode(splitDataRaw);
        expectedPayers = ids
            .where((id) => id != payerId)
            .map((id) => id.toString())
            .toList();
      } else if (splitType == 'exact') {
        final Map data = jsonDecode(splitDataRaw);
        data.forEach((id, val) {
          if (id != payerId && (val as num) > 0) {
            expectedPayers.add(id.toString());
          }
        });
      }

      // Check if EVERY expected payer has a 'completed' settlement for this expense
      // Parse splitData to get each person's share for amount-based fallback
      Map<String, double> shareAmounts = {};
      if (splitType == 'equal') {
        final List ids = jsonDecode(splitDataRaw);
        final amount = (expense['amount'] as num).toDouble();
        final perPerson = amount / ids.length;
        for (var id in ids) {
          shareAmounts[id.toString()] = perPerson;
        }
      } else if (splitType == 'exact') {
        final Map data = jsonDecode(splitDataRaw);
        data.forEach((id, val) {
          shareAmounts[id.toString()] = (val as num).toDouble();
        });
      }

      bool allPaid = true;

      for (var epId in expectedPayers) {
        final expectedAmount = shareAmounts[epId] ?? 0.0;

        final settled = _currentGroupSettlements.any((s) {
          if (s['status'] != 'completed') return false;

          final sPayer = _safeId(s['payerId']);
          final sReceiver = _safeId(s['receiverId']);
          final sExpId = _safeId(s['expenseId']);

          // Check if people match
          if (sPayer != _safeId(epId) || sReceiver != _safeId(payerId)) {
            return false;
          }

          // Strict expenseId match
          if (sExpId.isNotEmpty && sExpId == _safeId(expenseId)) {
            return true;
          }

          // Amount-based fallback if expenseId is missing
          if (sExpId.isEmpty && expectedAmount > 0) {
            final sAmount = (s['amount'] as num).toDouble().toStringAsFixed(2);
            final targetAmount = expectedAmount.toStringAsFixed(2);
            if (sAmount == targetAmount) {
              return true;
            }
          }

          return false;
        });

        if (!settled) {
          allPaid = false;
          break;
        }
      }

      if (allPaid && expectedPayers.isNotEmpty) {
        final success = await _service.updateExpenseStatus(
          expenseId,
          'completed',
        );

        if (success) {
          // Update current group expenses
          _currentGroupExpenses[expenseIndex]['status'] = 'completed';

          // Also update global expenses list
          final globalIndex = _globalExpenses.indexWhere(
            (e) => _safeId(e['id']) == _safeId(expenseId),
          );
          if (globalIndex != -1) {
            _globalExpenses[globalIndex]['status'] = 'completed';
          }

          notifyListeners();
        } else {}
      } else {}
    } catch (e) {
      // ignore: empty_catches
    }
  }

  Future<void> rejectSettlement(String settlementId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final success = await _service.updateSettlementStatus(
        settlementId,
        'rejected',
      );
      if (success) {
        final index = _currentGroupSettlements.indexWhere(
          (s) => s['id']?.toString() == settlementId.toString(),
        );
        if (index != -1) {
          _currentGroupSettlements[index]['status'] = 'rejected';
          _calculateBalances();
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetSplit({DateTime? startDate, DateTime? endDate}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Server-side deletion
      await _service.deleteAllDutchData(startDate: startDate, endDate: endDate);

      // 2. Clear local data
      if (startDate == null && endDate == null) {
        _globalExpenses = [];
        _globalSettlements = [];
        _globalBalances = {};
        _groups = [];
        _currentGroupId = null;
        _currentGroupExpenses = [];
        _currentGroupSettlements = [];
        _groupBalances = {};
      } else {
        // Partial reset: Remove matching items from local global lists PROACTIVELY
        final startThreshold = startDate ?? DateTime(1970);
        final endThreshold = endDate ?? DateTime(2100);

        _globalExpenses.removeWhere((e) {
          final dtStr = e['dateTime'] ?? e['\$createdAt'];
          if (dtStr == null) return false;
          final dt = DateTime.parse(dtStr);
          return dt.isAfter(
                startThreshold.subtract(const Duration(seconds: 1)),
              ) &&
              dt.isBefore(endThreshold.add(const Duration(seconds: 1)));
        });

        _globalSettlements.removeWhere((s) {
          final dtStr = s['dateTime'] ?? s['\$createdAt'];
          if (dtStr == null) return false;
          final dt = DateTime.parse(dtStr);
          return dt.isAfter(
                startThreshold.subtract(const Duration(seconds: 1)),
              ) &&
              dt.isBefore(endThreshold.add(const Duration(seconds: 1)));
        });

        // Prune Groups
        _groups.removeWhere((g) {
          final dtStr = g['\$createdAt'];
          if (dtStr == null) return false;
          final dt = DateTime.parse(dtStr);
          return dt.isAfter(
                startThreshold.subtract(const Duration(seconds: 1)),
              ) &&
              dt.isBefore(endThreshold.add(const Duration(seconds: 1)));
        });

        // If current group was deleted or created within range, reset view
        if (_currentGroupId != null) {
          final currentGroupStillExists = _groups.any(
            (g) => _safeId(g['id']) == _currentGroupId,
          );
          if (!currentGroupStillExists) {
            _currentGroupId = null;
            _currentGroupExpenses = [];
            _currentGroupSettlements = [];
            _groupBalances = {};
          } else {
            // Refresh current group's data to reflect deleted expenses/settlements
            await fetchGroups(); // To get actual group list sync
            await fetchGlobalData();
            if (_currentGroupId != null) {
              await selectGroup(_currentGroupId!);
            }
          }
        } else {
          await fetchGlobalData();
          await fetchGroups();
        }
      }

      notifyListeners();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
