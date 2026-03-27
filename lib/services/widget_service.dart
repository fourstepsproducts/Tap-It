import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/item.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.example.track_expense/widget');

  static void listenForWidgetInteraction(Function(int) onTabChange) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openTab') {
        final tab = call.arguments as int;
        onTabChange(tab);
      }
    });
  }

  static Future<void> updateWidgetData({
    required double balance,
    required double income,
    required double expenses,
    required String currency,
    required List<Item> quickItems,
  }) async {
    try {
      // Filter items by category
      final dailyItems = quickItems.where((i) => i.frequency == 'daily').toList();
      final monthlyItems = quickItems.where((i) => i.frequency == 'monthly').toList();
      final flexiItems = quickItems.where((i) => i.isVariable == true || i.frequency == 'variable').toList();

      // Build data map
      final Map<String, String?> data = {
        'balance': '$currency${balance.toStringAsFixed(2)}',
        'income': '$currency${income.toStringAsFixed(2)}',
        'expenses': '$currency${expenses.toStringAsFixed(2)}',
        'currency': currency,
      };

      // Add Daily items (up to 6)
      _addItemsToMap(data, 'daily', dailyItems);
      // Add Monthly items (up to 6)
      _addItemsToMap(data, 'monthly', monthlyItems);
      // Add Flexi items (up to 6)
      _addItemsToMap(data, 'flexi', flexiItems);

      // Send to native Android via MethodChannel
      await _channel.invokeMethod('updateWidget', data);
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  static void _addItemsToMap(Map<String, String?> data, String prefix, List<Item> items) {
    for (int i = 0; i < 6; i++) {
      if (i < items.length) {
        data['${prefix}_${i + 1}_title'] = items[i].title;
        data['${prefix}_${i + 1}_id'] = items[i].id;
      } else {
        data['${prefix}_${i + 1}_title'] = null;
        data['${prefix}_${i + 1}_id'] = null;
      }
    }
  }

  static Future<void> updateLedgerWidgetData({
    required double netBalance,
    required double youGet,
    required double youOwe,
    required String currency,
    required List<Map<String, String>> recentItems,
  }) async {
    try {
      final Map<String, String?> data = {
        'ledger_net_balance': '$currency${netBalance.toStringAsFixed(2)}',
        'ledger_you_get': '$currency${youGet.toStringAsFixed(2)}',
        'ledger_you_owe': '$currency${youOwe.toStringAsFixed(2)}',
      };

      for (int i = 0; i < 3; i++) {
        if (i < recentItems.length) {
          data['ledger_recent_${i + 1}_title'] = recentItems[i]['title'];
          data['ledger_recent_${i + 1}_id'] = recentItems[i]['id'];
        } else {
          data['ledger_recent_${i + 1}_title'] = null;
          data['ledger_recent_${i + 1}_id'] = null;
        }
      }

      await _channel.invokeMethod('updateWidget', data);
    } catch (e) {
      debugPrint('Error updating ledger widget: $e');
    }
  }

  static Future<void> updateInvestWidgetData({
    required double currentValue,
    required double investedAmount,
    required double pnl,
    required String currency,
    required List<Map<String, String>> portfolioItems,
  }) async {
    try {
      final String pnlPrefix = pnl >= 0 ? '+' : '';
      final Map<String, String?> data = {
        'invest_current_value': '$currency${currentValue.toStringAsFixed(2)}',
        'invest_invested': '$currency${investedAmount.toStringAsFixed(2)}',
        'invest_pnl': '$pnlPrefix$currency${pnl.abs().toStringAsFixed(2)}',
      };

      for (int i = 0; i < 3; i++) {
        if (i < portfolioItems.length) {
          data['invest_item_${i + 1}_title'] = portfolioItems[i]['title'];
          data['invest_item_${i + 1}_id'] = portfolioItems[i]['id'];
        } else {
          data['invest_item_${i + 1}_title'] = null;
          data['invest_item_${i + 1}_id'] = null;
        }
      }

      await _channel.invokeMethod('updateWidget', data);
    } catch (e) {
      debugPrint('Error updating invest widget: $e');
    }
  }

  static Future<void> updateSplitWidgetData({
    required double yourShare,
    required int groupCount,
    required int pendingCount,
    required String currency,
    required List<Map<String, String>> topGroups,
  }) async {
    try {
      final Map<String, String?> data = {
        'split_your_share': '$currency${yourShare.toStringAsFixed(2)}',
        'split_group_count': groupCount.toString(),
        'split_pending_count': pendingCount.toString(),
      };

      for (int i = 0; i < 3; i++) {
        if (i < topGroups.length) {
          data['split_group_${i + 1}_title'] = topGroups[i]['title'];
          data['split_group_${i + 1}_id'] = topGroups[i]['id'];
        } else {
          data['split_group_${i + 1}_title'] = null;
          data['split_group_${i + 1}_id'] = null;
        }
      }

      await _channel.invokeMethod('updateWidget', data);
    } catch (e) {
      debugPrint('Error updating split widget: $e');
    }
  }
}
