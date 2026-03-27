import 'package:flutter/foundation.dart' hide Category;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../services/appwrite_service.dart';
import '../services/sound_service.dart';
import '../services/widget_service.dart';

class TransactionProvider extends ChangeNotifier {
  final AppwriteService _appwriteService = AppwriteService();

  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  List<Item> _items = []; // Items for selected category
  List<Item> _quickItems = []; // Frequent items

  bool _isLoading = false;
  bool _hasMore = true;
  String? _lastId;

  List<Transaction> get transactions => _transactions;
  bool get hasMore => _hasMore;
  String? get lastId => _lastId;
  List<Category> get categories => _categories;
  List<Item> get items =>
      _quickItems; // Return quickItems which has all items with frequency
  List<Item> get quickItems => _quickItems;
  List<Item> get categoryItems => _items; // Exposed for Category Detail View
  bool get isLoading => _isLoading;

  late Box<Transaction> _transactionBox;
  late Box<Category> _categoryBox;
  late Box<Item> _itemBox; // For quick items specifically or all items?
  // Storing 'quick items' in a separate box might be cleaner, e.g., 'items_box'.

  bool _isHiveInitialized = false;

  String? pendingSubTab;

  double get totalBalance {
    double total = 0;
    for (var transaction in _transactions) {
      if (transaction.isExpense) {
        total -= transaction.amount;
      } else {
        total += transaction.amount;
      }
    }
    return total;
  }

  // --- Widget Sync ---
  Future<void> syncWidget({String? currency}) async {
    try {
      String symbol = currency ?? '₹';
      if (currency == null) {
        final prefs = await SharedPreferences.getInstance();
        symbol = prefs.getString('currency_symbol') ?? '₹';
      }
      await WidgetService.updateWidgetData(
        balance: totalBalance,
        income: totalIncome,
        expenses: totalExpenses,
        currency: symbol,
        quickItems: _quickItems,
      );
    } catch (e) {
      // Widget sync is non-critical, never block app functionality
    }
  }

  double get totalIncome {
    return _transactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalExpenses {
    return _transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Future<void> _initHive() async {
    if (_isHiveInitialized) return;
    _transactionBox = await Hive.openBox<Transaction>('transactions');
    _categoryBox = await Hive.openBox<Category>('categories');
    _itemBox = await Hive.openBox<Item>('items');
    _isHiveInitialized = true;
  }

  Future<void> fetchData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _initHive();

      // 1. Load from Cache immediately
      _transactions = _transactionBox.values.toList();
      _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

      _categories = _categoryBox.values.toList();
      _quickItems = _itemBox.values.where((i) => i.frequency != null).toList();
      _quickItems.sort((a, b) => a.order.compareTo(b.order));

      notifyListeners(); // Show cached data (potentially empty on fresh install)

      // 2. Ensure we have a user before network fetch
      final user = await _appwriteService.getCurrentUser();
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 3. Fetch from Network
      // Transactions
      final transactionData = await _appwriteService.getTransactions();

      final networkTransactions = transactionData
          .map((data) => Transaction.fromJson(data))
          .toList();

      if (networkTransactions.isNotEmpty) {
        // Merge: Keep network transactions, BUT also keep any local "temp" ones that aren't synced yet
        final tempTransactions = _transactions.where((tx) {
          final id = tx.id;
          return id.startsWith('temp_') || RegExp(r'^\d+$').hasMatch(id);
        }).toList();

        // Avoid duplicates
        _transactions = networkTransactions;
        for (var temp in tempTransactions) {
          // Robust check: match if title, amount and time (within 60s) are same
          final alreadyInNetwork = networkTransactions.any(
            (t) =>
                t.title == temp.title &&
                (t.amount - temp.amount).abs() < 0.01 &&
                t.dateTime.difference(temp.dateTime).inSeconds.abs() < 60,
          );

          if (!alreadyInNetwork) {
            _transactions.insert(0, temp);
          }
        }

        _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

        // CRITICAL: Update pagination state
        if (networkTransactions.isNotEmpty) {
          _lastId = networkTransactions.last.id;
          _hasMore = networkTransactions.length >= 25;
        }

        // Update Cache
        await _transactionBox.clear();
        await _transactionBox.putAll({for (var t in _transactions) t.id: t});
      } else {
        _hasMore = false;
        if (_transactions.isEmpty) {
          _transactions = [];
        }
      }

      // Categories
      await _loadCategories();

      // Quick Items
      await _loadQuickItems();
      syncWidget();
    } catch (e) {
      // ignore: empty_catches
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categoryData = await _appwriteService.getCategories();

      final networkCategories = categoryData
          .map((data) => Category.fromJson(data))
          .toList();

      _categories = networkCategories;
      // Update Cache
      await _categoryBox.clear();
      if (_categories.isNotEmpty) {
        await _categoryBox.putAll({for (var c in _categories) c.id: c});
      }
    } catch (e) {}
  }

  Future<void> _loadQuickItems() async {
    try {
      final quickItemData = await _appwriteService.getQuickItems();

      final networkItems = quickItemData.map((data) {
        final item = Item.fromJson(data);
        // Preserve local order preference if exists
        final cachedItem = _itemBox.get(item.id);
        int localOrder = (cachedItem != null && cachedItem.order != 9999)
            ? cachedItem.order
            : 9999;

        // Create new item with preserved local order
        return Item(
          id: item.id,
          userId: item.userId,
          title: item.title,
          amount: item.amount,
          isExpense: item.isExpense,
          categoryId: item.categoryId,
          usageCount: item.usageCount,
          frequency: item.frequency,
          icon: item.icon,
          dueDay: item.dueDay,
          isVariable: item.isVariable,
          order: localOrder,
        );
      }).toList();

      _quickItems = networkItems;
      _quickItems.sort((a, b) => a.order.compareTo(b.order));

      // Update Cache
      await _itemBox.clear();
      if (_quickItems.isNotEmpty) {
        await _itemBox.putAll({for (var i in _quickItems) i.id: i});
      }
      syncWidget();
    } catch (e) {
      // ignore: empty_catches
    }
  }

  Future<void> updateItemsOrder(List<Item> reorderedSubset) async {
    // 1. Get current 'order' values of these items (sorted) to know which 'slots' are available
    final currentOrders = reorderedSubset.map((item) {
      final existing = _quickItems.firstWhere(
        (q) => q.id == item.id,
        orElse: () => item,
      );
      return existing.order;
    }).toList()..sort();

    // If all orders are default 9999, we need to generate new distinct orders.
    // Use current index in global list as fallback?
    if (currentOrders.every((o) => o == 9999)) {
      // Fallback: Assign 0..N based on new sequence, but this might overlap hidden items.
      // Ideally we should fix data integrity first.
      // For now, let's just accept the loop index + generic offset?
      // Or use timestamp? No.
      // Let's just use 0, 1, 2... for these.
      for (int i = 0; i < currentOrders.length; i++) {
        currentOrders[i] = i;
      }
    }

    // 2. Assign new orders
    for (int i = 0; i < reorderedSubset.length; i++) {
      int newOrder = currentOrders[i];

      final item = reorderedSubset[i];
      final updatedItem = Item(
        id: item.id,
        userId: item.userId,
        title: item.title,
        amount: item.amount,
        isExpense: item.isExpense,
        categoryId: item.categoryId,
        usageCount: item.usageCount,
        frequency: item.frequency,
        icon: item.icon,
        dueDay: item.dueDay,
        isVariable: item.isVariable,
        order: newOrder,
      );

      // Update global list
      final index = _quickItems.indexWhere((q) => q.id == item.id);
      if (index != -1) {
        _quickItems[index] = updatedItem;
      }

      // Update local cache
      if (_isHiveInitialized) {
        await _itemBox.put(updatedItem.id, updatedItem);
      }
    }

    // 3. Sort global list again
    _quickItems.sort((a, b) => a.order.compareTo(b.order));
    notifyListeners();
  }

  Future<void> fetchItemsEx(String categoryId) async {
    try {
      final itemData = await _appwriteService.getItems(categoryId);
      _items = itemData.map((data) => Item.fromJson(data)).toList();
      notifyListeners();
    } catch (e) {
      // ignore: empty_catches
    }
  }

  Future<bool> addTransaction(
    String title,
    double amount,
    bool isExpense, {
    String? categoryId,
    String? itemId,
    String? paymentMethod,
  }) async {
    SoundService().play(isExpense ? 'expense.mp3' : 'income.mp3');

    // Optimistic Update
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final newTransaction = Transaction(
      id: tempId,
      title: title,
      amount: amount,
      isExpense: isExpense,
      dateTime: DateTime.now(),
      categoryId: categoryId,
      itemId: itemId,
      paymentMethod: paymentMethod,
    );

    _transactions.insert(0, newTransaction);
    notifyListeners();

    // Cache immediately (so it survives restart if offline)
    // We use tempId, need to cleanup later
    if (_isHiveInitialized) {
      await _transactionBox.put(tempId, newTransaction);
    }

    try {
      // API Call
      final txJson = newTransaction.toJson();
      debugPrint('📤 Sending transaction to DB: $txJson');
      final result = await _appwriteService.createTransaction(txJson);
      debugPrint('📥 DB response: ${result != null ? "SUCCESS" : "NULL (FAILED)"}');

      if (result != null) {
        final realTx = Transaction.fromJson(result);

        // Remove temp and replace with real, BUT check if real already exists (added by fetchData)
        final tempIndex = _transactions.indexWhere((t) => t.id == tempId);
        final realIndex = _transactions.indexWhere((t) => t.id == realTx.id);

        if (tempIndex != -1) {
          if (realIndex != -1) {
            // Already there (maybe from a concurrent fetchData), just remove temp
            _transactions.removeAt(tempIndex);
          } else {
            // Normal case: replace temp with real
            _transactions[tempIndex] = realTx;
          }
          notifyListeners();
        }

        // Update Cache
        if (_isHiveInitialized) {
          await _transactionBox.delete(tempId);
          await _transactionBox.put(realTx.id, realTx);
        }

        // Refresh meta data
        _loadQuickItems();
        await _loadCategories();
        syncWidget();
        notifyListeners();
        return true;
      } else {
        // This path usually means server returned null explicitly, which is rare for 'success'.
        // Usually it throws.
        return false;
      }
    } catch (e) {
      // Offline or Error
      // Keep the optimistic update in memory/cache?
      // If we want Offline-First, we keep it.
      // But we need a syncer.
      // For now, we will KEEP it in UI and Cache.
      // Ideally we mark it as 'unsynced' but our model doesn't support it yet.
      // User sees it. Next restart, 'fetchData' runs.
      // 'fetchData' loads from cache (tempId exists).
      // Then fetches from Server (tempId NOT there).
      // Server list overwrites Cache.
      // RESULT: Transaction Disappears on next sync if upload failed.
      // This is "Online-First with Cache".
      // To fix: 'fetchData' needs to merge?
      // Merging is complex without unique IDs/Sync status.
      // I will stick to this for now as MVP.
      return false; // Indicating "Not synced" to UI?
      // UI doesn't use the bool return much except for Dialog close.
    }
  }

  Future<bool> deleteTransaction(String id) async {
    SoundService().play('delete.mp3');

    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return false;

    // final removedItem = _transactions[index]; // Unused
    _transactions.removeAt(index);
    notifyListeners();

    if (_isHiveInitialized) {
      await _transactionBox.delete(id);
    }

    final success = await _appwriteService.deleteTransaction(id);

    if (!success) {
      // Failed to delete on server

      // We do NOT revert locally to avoid "zombie" items.
      // User can resync if needed.
      return false;
    } else {
      _loadQuickItems();
      await _loadCategories();
      syncWidget();
      notifyListeners();
      return true;
    }
  }

  Future<Item?> addItem(Map<String, dynamic> itemData) async {
    try {
      final result = await _appwriteService.createItem(itemData);
      if (result != null) {
        final newItem = Item.fromJson(result);
        _quickItems.insert(0, newItem);
        if (_isHiveInitialized) {
          _itemBox.put(newItem.id, newItem);
        }

        // If current category matches, add to items list too
        if (_categories.isNotEmpty &&
            itemData['categoryId'] == _items.firstOrNull?.categoryId) {
          _items.insert(0, newItem);
        }
        notifyListeners();
        return newItem;
      }
      return null;
    } catch (e) {
      return null; // Return null instead of rethrowing
    }
  }

  Future<String?> updateItem(String id, Map<String, dynamic> data) async {
    try {
      // 1. Find existing item to backup for revert
      final index = _quickItems.indexWhere((i) => i.id == id);
      if (index == -1) return 'Item not found';
      final oldItem = _quickItems[index];

      // 2. Create optimistic new item
      // We need to merge 'data' with 'oldItem' fields
      final newItem = Item(
        id: oldItem.id,
        userId: oldItem.userId,
        title: data['title'] ?? oldItem.title,
        amount: (data['amount'] ?? oldItem.amount).toDouble(),
        isExpense: data['isExpense'] ?? oldItem.isExpense,
        categoryId: data['categoryId'] ?? oldItem.categoryId,
        usageCount: oldItem.usageCount,
        frequency: data['frequency'] ?? oldItem.frequency,
        icon: data['icon'] ?? oldItem.icon,
        dueDay: data['dueDay'] ?? oldItem.dueDay,
        isVariable:
            data['isVariable'] ??
            oldItem.isVariable, // Ensure isVariable copied
      );

      // 3. Update local state immediately
      _quickItems[index] = newItem;
      if (_isHiveInitialized) {
        _itemBox.put(id, newItem);
      }

      // Also update category-specific list if present
      final catIndex = _items.indexWhere((i) => i.id == id);
      if (catIndex != -1) {
        _items[catIndex] = newItem;
      }

      notifyListeners();

      // 4. Perform API call
      final error = await _appwriteService.updateItem(id, data);

      if (error != null) {
        // Revert is fine for UPDATE, but for DELETE we want it gone.
        // Keeping revert for update as it helps avoid state desync for editable fields.
        _quickItems[index] = oldItem;
        if (_isHiveInitialized) {
          _itemBox.put(id, oldItem);
        }
        if (catIndex != -1) {
          _items[catIndex] = oldItem;
        }
        notifyListeners();
        return error;
      }
      // No need to call fetchData() if successful, unless we suspect side effects not covered here.
      // Optimistic update is sufficient for this use case.
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> deleteItem(String id) async {
    // Optimistic Delete
    _quickItems.removeWhere((i) => i.id == id);
    _items.removeWhere((i) => i.id == id);

    if (_isHiveInitialized) {
      _itemBox.delete(id);
    }
    notifyListeners();

    final success = await _appwriteService.deleteItem(id);
    if (!success) {}
  }

  Future<Category?> addCategory(String name, String type, String icon) async {
    try {
      final result = await _appwriteService.createCategory({
        'name': name,
        'type': type,
        'icon': icon,
      });
      if (result != null) {
        final newCat = Category.fromJson(result);
        _categories.add(newCat);
        if (_isHiveInitialized) {
          _categoryBox.put(newCat.id, newCat);
        }
        notifyListeners();
        return newCat;
      }
      return null;
    } catch (e) {
      // ignore: empty_catches
      return null;
    }
  }

  Future<void> updateCategory(
    String id,
    String name, {
    String? type,
    String? icon,
  }) async {
    final data = {'name': name};
    if (type != null) data['type'] = type;
    if (icon != null) data['icon'] = icon;

    final success = await _appwriteService.updateCategory(id, data);
    if (success) {
      final index = _categories.indexWhere((c) => c.id == id);
      if (index != -1) {
        final old = _categories[index];
        final newCat = Category(
          id: id,
          userId: old.userId,
          name: name,
          type: type ?? old.type,
          icon: icon ?? old.icon,
          usageCount: old.usageCount,
        );
        _categories[index] = newCat;
        if (_isHiveInitialized) {
          _categoryBox.put(id, newCat);
        }
        notifyListeners();
      }
    }
  }

  Future<void> deleteCategory(String id) async {
    // Optimistic Delete
    _categories.removeWhere((c) => c.id == id);
    _items = []; // Clear items as category is gone

    if (_isHiveInitialized) {
      _categoryBox.delete(id);
    }
    notifyListeners();

    final success = await _appwriteService.deleteCategory(id);
    if (!success) {}
  }

  // Helper method for syncing ledger to wallet
  void addSyncedTransaction(Transaction tx) {
    if (!_transactions.any((t) => t.id == tx.id)) {
      _transactions.insert(0, tx);
      _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      if (_isHiveInitialized) {
        _transactionBox.put(tx.id, tx);
      }
      notifyListeners();
    }
  }

  // --- Category Helpers ---

  int getCategoryUsageCount(String categoryId) {
    return _transactions.where((t) => t.categoryId == categoryId).length;
  }

  bool hasTransactionsForCategory(String categoryId) {
    return _transactions.any((t) => t.categoryId == categoryId);
  }

  bool isCategoryNameDuplicate(String name, String type) {
    final lowerName = name.trim().toLowerCase();
    return _categories.any(
      (c) => c.type == type && c.name.trim().toLowerCase() == lowerName,
    );
  }

  Future<void> loadMoreTransactions() async {
    if (!_hasMore || _isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final newData = await _appwriteService.getTransactions(
        lastId: _lastId,
        limit: 25,
      );

      if (newData.isNotEmpty) {
        final newTransactions = newData
            .map((data) => Transaction.fromJson(data))
            .toList();

        // Append ONLY new ones to avoid duplicates
        for (var tx in newTransactions) {
          if (!_transactions.any((t) => t.id == tx.id)) {
            _transactions.add(tx);
          }
        }
        _transactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        _lastId = newTransactions.isNotEmpty
            ? newTransactions.last.id
            : _lastId;
        _hasMore = newData.length >= 25;

        // Note: We don't necessarily clear the box here, but let's cache what we have
        // However, persistent data should probably just be the 'top' items or we use a separate strategy.
        // For now, let's keep the cache updated with the expanded list up to a reasonable point.
        if (_transactions.length <= 100 && _isHiveInitialized) {
          await _transactionBox.putAll({
            for (var t in newTransactions) t.id: t,
          });
        }
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

  Future<void> resetSpend({DateTime? startDate, DateTime? endDate}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _initHive();

      // 1. Server-side deletion
      await _appwriteService.deleteAllTransactions(
        startDate: startDate,
        endDate: endDate,
      );

      // 2. Clear local data
      if (startDate == null && endDate == null) {
        if (_isHiveInitialized) {
          await _transactionBox.clear();
          await _categoryBox.clear();
          await _itemBox.clear();
        }
        _transactions = [];
        _categories = [];
        _quickItems = [];
        _items = [];
      } else {
        // Partial reset: Remove matching items from local list and Hive PROACTIVELY
        final toRemove = _transactions.where((t) {
          if (startDate != null && t.dateTime.isBefore(startDate)) return false;
          if (endDate != null && t.dateTime.isAfter(endDate)) return false;
          return true;
        }).toList();

        for (var t in toRemove) {
          _transactions.remove(t);
          if (_isHiveInitialized) {
            await _transactionBox.delete(t.id);
          }
        }

        // Refetch to sync any other changes
        await fetchData();
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
