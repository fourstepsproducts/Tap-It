import 'package:home_widget/home_widget.dart';
import '../models/item.dart';

class WidgetService {
  static const String _androidWidgetName = 'MoneyWidgetProvider';

  static Future<void> updateWidgetData({
    required double balance,
    required double income,
    required double expenses,
    required String currency,
    required List<Item> quickItems,
  }) async {
    try {
      // Save Balance & Summary
      await HomeWidget.saveWidgetData<String>('balance', '$currency${balance.toStringAsFixed(2)}');
      await HomeWidget.saveWidgetData<String>('income', '$currency${income.toStringAsFixed(2)}');
      await HomeWidget.saveWidgetData<String>('expenses', '$currency${expenses.toStringAsFixed(2)}');
      await HomeWidget.saveWidgetData<String>('currency', currency);

      // Filter items
      final dailyItems = quickItems.where((i) => i.frequency == 'daily').toList();
      final monthlyItems = quickItems.where((i) => i.frequency == 'monthly').toList();
      final flexiItems = quickItems.where((i) => i.isVariable == true || i.frequency == 'variable').toList();

      // Save Daily (Top 6)
      await _saveCategoryItems('daily', dailyItems);
      // Save Monthly (Top 6)
      await _saveCategoryItems('monthly', monthlyItems);
      // Save Flexi (Top 6)
      await _saveCategoryItems('flexi', flexiItems);

      // Update the widget
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error updating widget: $e');
    }
  }

  static Future<void> _saveCategoryItems(String prefix, List<Item> items) async {
    for (int i = 0; i < 6; i++) {
      if (i < items.length) {
        final item = items[i];
        await HomeWidget.saveWidgetData<String>('${prefix}_${i + 1}_title', item.title);
        await HomeWidget.saveWidgetData<String>('${prefix}_${i + 1}_id', item.id);
      } else {
        await HomeWidget.saveWidgetData<String>('${prefix}_${i + 1}_title', null);
        await HomeWidget.saveWidgetData<String>('${prefix}_${i + 1}_id', null);
      }
    }
  }
}
