import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/item.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('com.example.track_expense/widget');

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
}
