import 'package:flutter/foundation.dart' hide Category;

import 'package:hive_flutter/hive_flutter.dart';
import '../models/ledger_transaction.dart';
import '../services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'transaction_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/widget_service.dart';

class LedgerProvider extends ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();

  List<LedgerTransaction> _ledgerTransactions = [];
  List<LedgerTransaction> _incomingRequests = [];
  List<LedgerTransaction> _outgoingRequests = [];
  List<LedgerTransaction> _notes = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _lastId;

  List<LedgerTransaction> get ledgerTransactions => _ledgerTransactions;
  List<LedgerTransaction> get incomingRequests => _incomingRequests;
  List<LedgerTransaction> get outgoingRequests => _outgoingRequests;
  List<LedgerTransaction> get notes => _notes;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  late Box<LedgerTransaction> _ledgerBox;
  late Box<String> _hiddenPeopleBox;
  late Box<String> _softDeletedPeopleBox;
  bool _isHiveInitialized = false;
  List<String> _hiddenPeople = [];
  List<String> _softDeletedPeople = [];
  List<String> get hiddenPeople => _hiddenPeople;
  List<String> get softDeletedPeople => _softDeletedPeople;

  String? _currentUserId;
  String? get currentUserId => _currentUserId;
  final Map<String, String> _userPhotos = {};
  Map<String, String> get userPhotos => _userPhotos;

  /// Returns a list of unique users the current user has interacted with who are on the app
  List<Map<String, String>> get knownAppUsers {
    final Map<String, Map<String, String>> users = {};

    for (var tx in _ledgerTransactions) {
      if (_currentUserId == null) continue;

      // Check receiver
      if (tx.receiverId != null &&
          tx.receiverId!.isNotEmpty &&
          tx.receiverId != _currentUserId) {
        users[tx.receiverId!] = {
          'id': tx.receiverId!,
          'name': tx.receiverName,
          'phone': tx.receiverPhone ?? '',
        };
      }
      // Check sender
      if (tx.senderId.isNotEmpty && tx.senderId != _currentUserId) {
        users[tx.senderId] = {
          'id': tx.senderId,
          'name': tx.senderName,
          'phone': tx.senderPhone,
        };
      }
    }

    return users.values.toList();
  }

  Future<void> _initHive() async {
    if (_isHiveInitialized) return;
    _ledgerBox = await Hive.openBox<LedgerTransaction>('ledger');
    _hiddenPeopleBox = await Hive.openBox<String>('hidden_people');
    _softDeletedPeopleBox = await Hive.openBox<String>('soft_deleted_people');
    _hiddenPeople = _hiddenPeopleBox.values.toList();
    _softDeletedPeople = _softDeletedPeopleBox.values.toList();
    _isHiveInitialized = true;
  }

  Future<void> fetchLedgerTransactions({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    await _initHive();

    if (_currentUserId == null) {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        _currentUserId = user['userId'];
      } else {
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    try {
      final cached = _ledgerBox.values.toList();
      _processTransactions(cached);
      notifyListeners();

      final data = await _appwriteService.getLedgerTransactions(limit: 25);
      if (data != null && data.isNotEmpty) {
        final networkTx = data
            .map((e) => LedgerTransaction.fromJson(e))
            .toList();
        _processTransactions(networkTx);
        _hasMore = networkTx.length >= 25;
        if (networkTx.isNotEmpty) {
          _lastId = networkTx.last.id;
        }
        await _ledgerBox.clear();
        await _ledgerBox.putAll({for (var t in networkTx) t.id: t});
      } else {
        // SERVER IS EMPTY or Error: clear local state
        _ledgerTransactions = [];
        _incomingRequests = [];
        _outgoingRequests = [];
        _notes = [];
        _hasMore = false;
        await _ledgerBox.clear();
      }
    } catch (e) {
      if (e is! AppwriteException || e.code != 401) {
        // ignore: empty_catches
      }
    } finally {
      _isLoading = false;
      if (_ledgerTransactions.isNotEmpty ||
          _incomingRequests.isNotEmpty ||
          _outgoingRequests.isNotEmpty) {
        _fetchUserPhotos([
          ..._ledgerTransactions,
          ..._incomingRequests,
          ..._outgoingRequests,
        ]);
      }
      syncWidget();
      Future.microtask(() => notifyListeners());
    }
  }

  void _processTransactions(List<LedgerTransaction> all) {
    _ledgerTransactions = [];
    _incomingRequests = [];
    _outgoingRequests = [];
    _notes = [];

    all.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    for (var tx in all) {
      if (tx.status == 'confirmed') {
        _ledgerTransactions.add(tx);
      } else if (tx.status == 'notes') {
        _notes.add(tx);
      } else if (tx.status == 'pending') {
        if (_currentUserId != null && tx.receiverId == _currentUserId) {
          _incomingRequests.add(tx);
        } else if (tx.senderId == _currentUserId) {
          _outgoingRequests.add(tx);
        } else {
          _outgoingRequests.add(tx);
        }
      }
    }
  }

  Future<void> loadMoreLedgerTransactions() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _appwriteService.getLedgerTransactions(
        lastId: _lastId,
        limit: 25,
      );

      if (data != null && data.isNotEmpty) {
        final newTransactions = data
            .map((e) => LedgerTransaction.fromJson(e))
            .toList();

        // Add to existing lists based on status
        for (var tx in newTransactions) {
          if (tx.status == 'confirmed') {
            if (!_ledgerTransactions.any((t) => t.id == tx.id)) {
              _ledgerTransactions.add(tx);
            }
          } else if (tx.status == 'notes') {
            if (!_notes.any((t) => t.id == tx.id)) {
              _notes.add(tx);
            }
          } else if (tx.status == 'pending') {
            if (_currentUserId != null && tx.receiverId == _currentUserId) {
              if (!_incomingRequests.any((t) => t.id == tx.id)) {
                _incomingRequests.add(tx);
              }
            } else {
              if (!_outgoingRequests.any((t) => t.id == tx.id)) {
                _outgoingRequests.add(tx);
              }
            }
          }
        }

        // Re-sort
        _ledgerTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        _notes.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        _incomingRequests.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        _outgoingRequests.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        _lastId = newTransactions.last.id;
        _hasMore = data.length >= 25;

        _fetchUserPhotos(newTransactions);
        notifyListeners();
      } else {
        _hasMore = false;
      }
    } catch (e) {
      // ignore: empty_catches
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addLedgerTransaction(
    String name,
    String? phone,
    double amount,
    String description, {
    required bool isReceived,
    required String currentUserId,
    required String currentUserName,
    required String currentUserPhone,
    String? currentUserEmail,
    String? customStatus,
  }) async {
    _currentUserId = currentUserId;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    String status = customStatus ?? 'confirmed';
    if (customStatus == null &&
        phone != null &&
        phone.isNotEmpty &&
        !phone.startsWith('local:')) {
      status = 'pending';
    }

    // Standardize naming to avoid "Me giving to Me" messiness
    final displayOtherName =
        (name.trim().toLowerCase() == currentUserName.trim().toLowerCase() ||
            name.trim().toLowerCase() == 'me')
        ? 'Self'
        : name.trim();

    final String actualSenderName;
    final String? actualSenderPhone;
    final String? actualSenderId;
    final String actualReceiverName;
    final String? actualReceiverPhone;
    final String? actualReceiverId;

    if (isReceived) {
      // "You Got" - Other person is sender, you are receiver
      actualSenderName = displayOtherName;
      actualSenderPhone = phone;
      actualSenderId = null; // We don't know other person's ID unless linked
      actualReceiverName = currentUserName;
      actualReceiverPhone = currentUserPhone;
      actualReceiverId = currentUserId;
    } else {
      // "You Gave" - You are sender, other person is receiver
      actualSenderName = currentUserName;
      actualSenderPhone = currentUserPhone;
      actualSenderId = currentUserId;
      actualReceiverName = displayOtherName;
      actualReceiverPhone = phone;
      actualReceiverId = null;
    }

    final optimisticTx = LedgerTransaction(
      id: tempId,
      senderId: actualSenderId ?? '',
      senderName: actualSenderName,
      senderPhone: actualSenderPhone ?? '',
      receiverName: actualReceiverName,
      receiverPhone: actualReceiverPhone,
      receiverId: actualReceiverId,
      amount: amount.abs(),
      description: description,
      dateTime: now,
      status: status,
      creatorId: currentUserId,
    );

    // OPTIMISTIC UPDATE

    if (status == 'confirmed') {
      _ledgerTransactions.insert(0, optimisticTx);
    } else if (status == 'notes') {
      _notes.insert(0, optimisticTx);
    } else {
      // Pending
      _outgoingRequests.insert(0, optimisticTx);
    }

    // AUTO-UNHIDE/UNSOFT-DELETE
    await unhidePerson(actualSenderName);
    await unhidePerson(actualReceiverName);
    await unsoftDeletePerson(actualSenderName);
    await unsoftDeletePerson(actualReceiverName);

    notifyListeners();

    try {
      final result = await _appwriteService.createLedgerTransaction({
        'senderName': actualSenderName,
        'senderPhone': actualSenderPhone ?? '',
        'senderId': actualSenderId ?? '',
        'receiverName': actualReceiverName,
        'receiverPhone': actualReceiverPhone ?? '',
        'receiverId': actualReceiverId ?? '',
        'amount': amount.abs(),
        'description': description,
        'dateTime': now.toIso8601String(),
        'status': status,
      });

      if (result != null) {
        LedgerTransaction realTx;
        try {
          realTx = LedgerTransaction.fromJson(result);
        } catch (e) {
          _removeFromLocal(tempId, status);
          notifyListeners();
          return 'JSON Parse Failed: $e';
        }

        // Remove optimistic
        if (status == 'confirmed') {
          _ledgerTransactions.removeWhere((t) => t.id == tempId);
        } else if (status == 'notes') {
          _notes.removeWhere((t) => t.id == tempId);
        } else {
          _outgoingRequests.removeWhere((t) => t.id == tempId);
        }

        // Add real
        if (realTx.status == 'confirmed') {
          _ledgerTransactions.add(realTx);
          _ledgerTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        } else if (realTx.status == 'notes') {
          _notes.add(realTx);
          _notes.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        } else {
          // Pending
          _outgoingRequests.add(realTx);
          _outgoingRequests.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        }

        if (_isHiveInitialized) {
          _ledgerBox.put(realTx.id, realTx);
        }
        notifyListeners();
        return null;
      } else {
        _removeFromLocal(tempId, status);
        notifyListeners();
        return 'Failed to create transaction';
      }
    } catch (e) {
      _removeFromLocal(tempId, status);
      notifyListeners();
      return 'Error: $e';
    }
  }

  void _removeFromLocal(String id, String status) {
    if (status == 'confirmed') {
      _ledgerTransactions.removeWhere((t) => t.id == id);
    } else if (status == 'notes') {
      _notes.removeWhere((t) => t.id == id);
    } else {
      _outgoingRequests.removeWhere((t) => t.id == id);
    }
  }

  Future<bool> acceptLedgerTransaction(LedgerTransaction tx) async {
    // OPTIMISTIC UPDATE
    final index = _incomingRequests.indexWhere((t) => t.id == tx.id);
    if (index != -1) {
      final updatedTx = _incomingRequests[index].copyWith(status: 'confirmed');
      _incomingRequests.removeAt(index);
      _ledgerTransactions.add(updatedTx);
      _ledgerTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      notifyListeners();
    }

    try {
      final success = await _appwriteService.updateLedgerTransactionStatus(
        tx.id,
        'confirmed',
      );
      if (success) {
        // No need to fetch all if backend success confirms our optimistic change
        // But fetching ensures consistency in case of other changes
        // await fetchLedgerTransactions();
        return true;
      } else {
        // Revert if failed
        _ledgerTransactions.removeWhere((t) => t.id == tx.id);
        _incomingRequests.add(tx); // Add back original
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Revert if error
      _ledgerTransactions.removeWhere((t) => t.id == tx.id);
      _incomingRequests.add(tx);
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectLedgerTransaction(String id) async {
    // OPTIMISTIC UPDATE
    LedgerTransaction? removedTx;
    final inIndex = _incomingRequests.indexWhere((t) => t.id == id);
    if (inIndex != -1) {
      removedTx = _incomingRequests[inIndex];
      _incomingRequests.removeAt(inIndex);
    }
    // Also check outgoing? usually reject is for incoming.

    notifyListeners();

    try {
      final success = await _appwriteService.updateLedgerTransactionStatus(
        id,
        'rejected',
      );
      if (success) {
        return true;
      } else {
        if (removedTx != null) {
          _incomingRequests.add(removedTx);
          notifyListeners();
        }
        return false;
      }
    } catch (e) {
      if (removedTx != null) {
        _incomingRequests.add(removedTx);
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> deleteLedgerTransaction(String id) async {
    final success = await _appwriteService.deleteLedgerTransaction(id);
    if (success) {
      _ledgerTransactions.removeWhere((t) => t.id == id);
      _notes.removeWhere((t) => t.id == id);
      _outgoingRequests.removeWhere((t) => t.id == id);
      if (_isHiveInitialized) {
        _ledgerBox.delete(id);
      }
      syncWidget();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> hidePerson(String name) async {
    if (!_hiddenPeople.contains(name)) {
      _hiddenPeople.add(name);
      await _hiddenPeopleBox.add(name);
      notifyListeners();
    }
  }

  Future<void> unhidePerson(String name) async {
    if (_hiddenPeople.contains(name)) {
      _hiddenPeople.remove(name);
      final Map<dynamic, String> boxMap = _hiddenPeopleBox
          .toMap()
          .cast<dynamic, String>();
      dynamic keyToDelete;
      boxMap.forEach((key, value) {
        if (value == name) keyToDelete = key;
      });
      if (keyToDelete != null) await _hiddenPeopleBox.delete(keyToDelete);
      notifyListeners();
    }
  }

  Future<void> softDeletePerson(String name) async {
    if (!_softDeletedPeople.contains(name)) {
      _softDeletedPeople.add(name);
      await _softDeletedPeopleBox.add(name);
      notifyListeners();
    }
  }

  Future<void> unsoftDeletePerson(String name) async {
    if (_softDeletedPeople.contains(name)) {
      _softDeletedPeople.remove(name);
      final Map<dynamic, String> boxMap = _softDeletedPeopleBox
          .toMap()
          .cast<dynamic, String>();
      dynamic keyToDelete;
      boxMap.forEach((key, value) {
        if (value == name) keyToDelete = key;
      });
      if (keyToDelete != null) await _softDeletedPeopleBox.delete(keyToDelete);
      notifyListeners();
    }
  }

  Future<bool> updatePerson({
    required String oldName,
    required String oldPhone,
    required String newName,
    required String newPhone,
  }) async {
    final success = await _appwriteService.updateLedgerPerson(
      oldName: oldName,
      oldPhone: oldPhone,
      newName: newName,
      newPhone: newPhone,
    );
    if (success) {
      await fetchLedgerTransactions();
      return true;
    }
    return false;
  }

  Future<bool> deletePerson({
    required String name,
    required String phone,
  }) async {
    final success = await _appwriteService.deleteLedgerPerson(
      name: name,
      phone: phone,
    );
    if (success) {
      await fetchLedgerTransactions();
      return true;
    }
    return false;
  }

  Future<void> syncLedgerToWallet(
    TransactionProvider transactionProvider,
    String currentUserPhone,
    List<Category> categories,
  ) async {
    for (var ledgerTx in _ledgerTransactions) {
      if (ledgerTx.dateTime.isBefore(
        DateTime.now().subtract(const Duration(minutes: 5)),
      )) {
        continue;
      }
      final isSynced = transactionProvider.transactions.any(
        (t) => t.ledgerId == ledgerTx.id,
      );
      if (!isSynced) {
        final normUserContact = _normalizePhone(currentUserPhone);
        final normSender = _normalizePhone(ledgerTx.senderPhone);
        final normReceiver = _normalizePhone(ledgerTx.receiverPhone);
        final isSender = normSender == normUserContact;
        final isReceiver = normReceiver == normUserContact;
        if (!isSender && !isReceiver) continue;
        if (isSender && isReceiver) continue;

        String title;
        bool isExpense;
        String otherName;

        if (isSender) {
          isExpense = true;
          otherName = ledgerTx.receiverName;
          title = 'Lent to $otherName';
        } else {
          isExpense = false;
          otherName = ledgerTx.senderName;
          title = 'Borrowed from $otherName';
        }

        String? categoryId;
        try {
          final targetType = isExpense ? 'expense' : 'income';
          final category = categories.firstWhere(
            (c) => c.name.toLowerCase() == 'others' && c.type == targetType,
            orElse: () => categories.firstWhere(
              (c) => c.type == targetType,
              orElse: () => categories.first,
            ),
          );
          categoryId = category.id;
        } catch (_) {}

        if (categoryId != null) {
          try {
            final result = await _appwriteService.createTransaction({
              'title': title,
              'amount': ledgerTx.amount,
              'isExpense': isExpense,
              'dateTime': ledgerTx.dateTime.toIso8601String(),
              'categoryId': categoryId,
              'ledgerId': ledgerTx.id,
            });
            if (result != null) {
              transactionProvider.addSyncedTransaction(
                Transaction.fromJson(result),
              );
            }
          } catch (e) {
            // ignore: empty_catches
          }
        }
      }
    }
  }

  Future<void> syncWidget({String? currency}) async {
    try {
      String symbol = currency ?? '₹';
      if (currency == null) {
        final prefs = await SharedPreferences.getInstance();
        symbol = prefs.getString('currency_symbol') ?? '₹';
      }

      final all = [
        ..._ledgerTransactions,
        ..._notes,
        ..._outgoingRequests,
        ..._incomingRequests,
      ];

      double totalSent = 0;
      double totalReceived = 0;

      for (var t in all) {
        if (_currentUserId != null && t.senderId == _currentUserId) {
          totalSent += t.amount;
        } else if (_currentUserId != null && t.receiverId == _currentUserId) {
          totalReceived += t.amount;
        } else {
           // fallback logic
           totalReceived += t.amount; // Assume received if we can't tell (to match dashboard fallback for incoming)
        }
      }

      double netBalance = totalReceived - totalSent;

      // Extract recent 3
      final recentTx = List<LedgerTransaction>.from(all);
      recentTx.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final top3 = recentTx.take(3).map((t) {
        bool isSent = (_currentUserId != null && t.senderId == _currentUserId);
        return {
          'title': isSent ? 'Lent to ${t.receiverName}' : 'Borrowed from ${t.senderName}',
          'id': t.id,
        };
      }).toList();

      await WidgetService.updateLedgerWidgetData(
        netBalance: netBalance,
        youGet: totalSent,      // Money you sent is money you get back
        youOwe: totalReceived,  // Money you received is money you owe
        currency: symbol,
        recentItems: top3,
      );
    } catch (e) {
      // ignore widget error
    }
  }

  List<LedgerTransaction> getTransactionsForPerson(
    String personName,
    String? personPhone,
    String currentUserId,
    List<String> myIdentities,
  ) {
    // Combine all sources: Confirmed + Notes + Outgoing(Pending) + Incoming(Pending)
    final all = [
      ..._ledgerTransactions,
      ..._notes,
      ..._outgoingRequests,
      ..._incomingRequests,
    ];

    return all.where((t) {
      // 1. Check if ANY participant matches the target person (Name OR Phone)
      final isSender =
          t.senderName == personName ||
          _arePhonesEqual(t.senderPhone, personPhone);
      final isReceiver =
          t.receiverName == personName ||
          _arePhonesEqual(t.receiverPhone, personPhone);

      if (!isSender && !isReceiver) return false;

      // 2. Ensuring the OTHER participant is ME
      // If target is sender, I must be receiver.
      // If target is receiver, I must be sender.
      if (isSender) {
        return t.receiverId == currentUserId ||
            myIdentities.any((id) => _arePhonesEqual(t.receiverPhone, id));
      } else {
        return t.senderId == currentUserId ||
            myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id));
      }
    }).toList();
  }

  bool _arePhonesEqual(String? p1, String? p2) {
    if (p1 == null || p2 == null) return false;
    return _normalizePhone(p1) == _normalizePhone(p2);
  }

  String _normalizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  }

  Future<void> _fetchUserPhotos(List<LedgerTransaction> transactions) async {
    final Set<String> userIds = {};
    for (var tx in transactions) {
      if (tx.senderId.isNotEmpty && tx.senderId != _currentUserId) {
        userIds.add(tx.senderId);
      }
      if (tx.receiverId != null &&
          tx.receiverId!.isNotEmpty &&
          tx.receiverId != _currentUserId) {
        userIds.add(tx.receiverId!);
      }
    }

    // Filter out already fetched ones (optional, but good for performance)
    final List<String> toFetch = userIds
        .where((id) => !_userPhotos.containsKey(id))
        .toList();

    if (toFetch.isEmpty) return;

    try {
      final profiles = await _appwriteService.getProfilesByIds(toFetch);
      for (var profile in profiles) {
        final id = profile['userId'];
        final photo = profile['photoUrl'];
        if (id != null && photo != null && photo.isNotEmpty) {
          _userPhotos[id] = photo;
        }
      }
      notifyListeners();
    } catch (e) {
      // ignore: empty_catches
    }
  }

  Future<void> resetDue({DateTime? startDate, DateTime? endDate}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _initHive();

      // 1. Server-side deletion
      await _appwriteService.deleteAllLedgerTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      // 2. Clear local data
      if (startDate == null && endDate == null) {
        if (_isHiveInitialized) {
          await _ledgerBox.clear();
        }
        _ledgerTransactions = [];
        _incomingRequests = [];
        _outgoingRequests = [];
        _notes = [];
      } else {
        // Partial reset: Remove matching items from local list and Hive PROACTIVELY
        await fetchLedgerTransactions();
      }
      notifyListeners();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;

      notifyListeners();
      rethrow;
    }
  }
}
