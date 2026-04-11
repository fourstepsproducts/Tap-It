import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/user_provider.dart';
import '../models/item.dart';
import '../models/category.dart';
import '../providers/transaction_provider.dart';
import '../services/notification_service.dart';
import '../utils/formatters.dart';
import 'category_dialog.dart';

enum EntryMode { quick, flexi, oneTime }

class AddItemDialog extends StatefulWidget {
  final Category? category; // Pre-selected category
  final Item? editingItem; // Item to edit
  final Item?
  existingItem; // Item to add transaction from (One-Time mode equivalent)
  final bool isDaily; // Default frequency
  final bool initialIsVariable; // Default to variable mode

  const AddItemDialog({
    super.key,
    this.category,
    this.editingItem,
    this.existingItem,
    this.isDaily = true,
    this.initialIsVariable = false,
  });

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late bool _isDaily;
  late bool _isExpense;
  String? _selectedCategoryId;
  String _selectedIcon = 'star';
  int? _dueDay;
  String? _selectedPaymentMethod;
  EntryMode _mode = EntryMode.quick;

  bool _isSaving = false;

  // Suggestion State
  String? _suggestionMessage;

  final List<String> iconOptions = [
    'star',
    'shopping_cart',
    'restaurant',
    'commute',
    'home',
    'medical_services',
    'school',
    'fitness_center',
    'smoking_rooms',
    'liquor',
    'shopping_basket',
    'eco',
    'local_gas_station',
    'movie',
    'pets',
    'phone_android',
    'wifi',
    'electric_bolt',
    'coffee',
    'fastfood',
    'checkroom',
    'water_drop',
    'flight',
    'local_taxi',
    'medication',
    'local_laundry_service',
    'content_cut',
    'card_giftcard',
    'sports_esports',
    'child_care',
    'car_repair',
    'local_parking',
    'menu_book',
    'subscriptions',
    'music_note',
    'cleaning_services',
    'spa',
    'celebration',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.editingItem ?? widget.existingItem;

    _selectedPaymentMethod = 'Cash'; // Default

    _titleController = TextEditingController(text: item?.title);
    _amountController = TextEditingController(
      text: item != null
          ? (item.amount.toStringAsFixed(
              item.amount.truncateToDouble() == item.amount ? 0 : 2,
            ))
          : '',
    );

    if (widget.editingItem != null) {
      // Editing Mode
      _mode = (widget.editingItem!.isVariable ?? false)
          ? EntryMode.flexi
          : EntryMode.quick;
      // Initialize _isDaily logic: Daily if frequency is daily, OR if variable but no dueDay (default)
      // If it has a DueDay, we treat it as "Monthly" UI-wise
      if (_mode == EntryMode.flexi) {
        _isDaily = widget.editingItem?.dueDay == null;
      } else {
        _isDaily = widget.editingItem?.frequency == 'daily';
      }
    } else if (widget.existingItem != null) {
      // Add Transaction Mode (from existing item)
      _mode = EntryMode.quick;
      _isDaily = widget.existingItem?.frequency == 'daily'; // inherited
    } else {
      // Add New Mode
      _isDaily = widget.isDaily;
      _mode = widget.initialIsVariable ? EntryMode.flexi : EntryMode.quick;
    }

    // Restore missing initialization
    _selectedCategoryId = item?.categoryId ?? widget.category?.id;

    if (item != null) {
      _isExpense = item.isExpense;
    } else if (widget.category != null) {
      _isExpense = widget.category!.type == 'expense';
    } else {
      _isExpense = true;
    }

    _dueDay = item?.dueDay;

    // Listen to title changes for suggestions
    _titleController.addListener(_checkSuggestions);
  }

  @override
  void dispose() {
    _titleController.removeListener(_checkSuggestions);
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _checkSuggestions() {
    final title = _titleController.text.toLowerCase();
    String categoryName = '';

    // Get selected category name
    if (_selectedCategoryId != null) {
      final provider = context.read<TransactionProvider>();
      final category = provider.categories
          .where((c) => c.id == _selectedCategoryId)
          .firstOrNull;
      categoryName = category?.name.toLowerCase() ?? '';
    }

    String? message;

    // Helper check
    bool matches(String text, List<String> keywords) {
      return keywords.any((k) => text.contains(k));
    }

    final ledgerKeywords = [
      'loan',
      'lend',
      'borrow',
      'repay',
      'debt',
      'owe',
      'ledger',
    ];
    final investmentKeywords = [
      'stock',
      'mutual fund',
      'sip',
      'equity',
      'crypto',
      'bitcoin',
      'invest',
    ];
    final dutchKeywords = ['split', 'share', 'dutch', 'group', 'trip'];

    // Check Title & Category
    if (matches(title, ledgerKeywords) ||
        matches(categoryName, ledgerKeywords)) {
      message = 'Tracking a loan? Use the Ledger feature for better tracking.';
    } else if (matches(title, investmentKeywords) ||
        matches(categoryName, investmentKeywords)) {
      message =
          'Investments have their own dedicated section with AI analysis.';
    } else if (matches(title, dutchKeywords) ||
        matches(categoryName, dutchKeywords)) {
      message = 'Splitting bills? Try "Go Dutch" to manage group expenses.';
    }

    if (message != _suggestionMessage) {
      setState(() {
        _suggestionMessage = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final userProvider = context.watch<UserProvider>();
    final categories = provider.categories;

    // Payment Methods
    final customMethods = userProvider.customPaymentMethods;
    final List<String> paymentMethods = [
      'Cash',
      'UPI',
      'Debit Card',
      'Credit Card',
      'Bank Account',
      ...customMethods,
    ].where((m) {
      if (customMethods.contains(m)) return true;
      return userProvider.isPaymentMethodEnabled(m);
    }).toList();

    // Dropdown Items
    final List<DropdownMenuItem<String>> dropdownItems = categories
        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
        .toList();

    dropdownItems.add(
      const DropdownMenuItem(value: 'other_virtual', child: Text('Other')),
    );

    dropdownItems.add(
      DropdownMenuItem(
        value: 'new_category',
        child: Text(
          '+ New Category',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    // Auto-select logic moved to safe place or handled via fallback in value
    // But Dropdown value must match item.
    // If _selectedCategoryId is null, we can try to find a valid one to Display, but strictly we should set the state.
    // However, since categories update via provider, we can just ensure value is valid.

    String? effectiveCategoryId = _selectedCategoryId;
    if (effectiveCategoryId == null && categories.isNotEmpty) {
      final others = categories
          .where((c) => c.name.toLowerCase().contains('other'))
          .firstOrNull;
      effectiveCategoryId = others?.id ?? categories.first.id;
      // We don't setState here to avoid rebuild loop, but we use this value for the Dropdown
      // But if user picks something else, _selectedCategoryId updates.
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Toggle (Quick Entry / One Time) - Only if NOT editing
              if (widget.editingItem == null) ...[
                _buildModeToggle(context),
                const SizedBox(height: 24),
              ],

              // Suggestion Banner
              if (_suggestionMessage != null) ...[
                _buildSuggestionBanner(context),
                const SizedBox(height: 16),
              ],

              Text(
                widget.editingItem != null
                    ? (_mode == EntryMode.flexi
                        ? 'Edit Variable Entry'
                        : 'Edit Quick Entry')
                    : (_mode == EntryMode.flexi
                        ? 'New Variable Entry'
                        : _mode == EntryMode.oneTime
                            ? 'One Time Transaction'
                            : 'New Quick Entry'),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: effectiveCategoryId,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: dropdownItems,
                onChanged: (value) async {
                  if (value == 'new_category') {
                    // Open Category Dialog on top
                    final newCategoryId = await showDialog<String>(
                      context: context,
                      builder: (context) => const CategoryDialog(),
                    );

                    // If a new category was created (ID returned), select it
                    if (newCategoryId != null) {
                      setState(() {
                        _selectedCategoryId = newCategoryId;
                        // Also update expense/income status based on new category
                        final cat = categories.firstWhere(
                          (c) => c.id == newCategoryId,
                          orElse: () => categories.first,
                        );
                        _isExpense = cat.type == 'expense';
                        // Optionally update icon if desired
                        // _selectedIcon = cat.icon;
                      });
                    } else {
                      // User cancelled or failed
                      setState(() {
                        _selectedCategoryId = null;
                      });
                    }
                  } else {
                    setState(() {
                      _selectedCategoryId = value;
                      if (value != null && value != 'other_virtual') {
                        final cat = categories.firstWhere(
                          (c) => c.id == value,
                          orElse: () => categories.first,
                        );
                        _isExpense = cat.type == 'expense';
                        // Check suggestions on category change
                        _checkSuggestions(); // Trigger logic
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Icon Selector (Always show now, or logic specific?)
              if (_mode != EntryMode.oneTime) ...[
                const SizedBox(height: 16),
                _buildIconSelector(context),
                const SizedBox(height: 16),
              ],

              // Expense/Income Toggle (Only for Other/Virtual)
              if (_shouldShowTypeToggle(categories)) ...[
                _buildTypeToggle(context),
                const SizedBox(height: 16),
              ],

              // Title & Amount (Hide Amount if Variable)
              TextField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [CapitalizeFirstLetterTextFormatter()],
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_mode != EntryMode.flexi) ...[
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Payment Method (Only for One Time)
              if (_mode == EntryMode.oneTime) ...[
                DropdownButtonFormField<String>(
                  value: paymentMethods.contains(_selectedPaymentMethod)
                      ? _selectedPaymentMethod
                      : (paymentMethods.isNotEmpty ? paymentMethods.first : null),
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.payment),
                  ),
                  items: paymentMethods
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged:
                      (value) => setState(() => _selectedPaymentMethod = value),
                ),
                const SizedBox(height: 16),
              ],

              // Frequency & Due Date (Available for both types now)
              if (_mode != EntryMode.oneTime) ...[
                _buildFrequencyToggle(context),
                if (!_isDaily && _mode != EntryMode.flexi) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _dueDay,
                    decoration: InputDecoration(
                      labelText: 'Due Day (Optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                    items: List.generate(31, (index) => index + 1)
                        .map(
                          (day) => DropdownMenuItem(
                            value: day,
                            child: Text('Day $day'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _dueDay = value),
                  ),
                ],
              ],

              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.editingItem != null
                              ? 'Update Entry'
                              : (_mode == EntryMode.flexi
                                  ? 'Save Variable Entry'
                                  : _mode == EntryMode.oneTime
                                      ? 'Save Transaction'
                                      : 'Save Quick Entry'),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _shouldShowTypeToggle(List<Category> categories) {
    if (_selectedCategoryId == 'other_virtual') return true;
    if (_selectedCategoryId == null) return false;
    final cat = categories
        .where((c) => c.id == _selectedCategoryId)
        .firstOrNull;
    if (cat != null && cat.name.toLowerCase().contains('other')) return true;
    return false;
  }

  Widget _buildModeToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleBtn(
              context,
              'Quick Entry',
              _mode == EntryMode.quick,
              () => setState(() => _mode = EntryMode.quick),
            ),
          ),
          Expanded(
            child: _buildToggleBtn(
              context,
              'Flexi',
              _mode == EntryMode.flexi,
              () => setState(() => _mode = EntryMode.flexi),
            ),
          ),
          Expanded(
            child: _buildToggleBtn(
              context,
              'One Time',
              _mode == EntryMode.oneTime,
              () => setState(() => _mode = EntryMode.oneTime),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(
    BuildContext context,
    String text,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: isActive
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconSelector(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: iconOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final iconName = iconOptions[index];
          final isSelected = _selectedIcon == iconName;
          return GestureDetector(
            onTap: () => setState(() => _selectedIcon = iconName),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              ),
              child: Icon(
                _getIconData(iconName),
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeBtn(
              context,
              'Expense',
              Colors.red,
              _isExpense,
              () => setState(() => _isExpense = true),
            ),
          ),
          Expanded(
            child: _buildTypeBtn(
              context,
              'Income',
              Colors.green,
              !_isExpense,
              () => setState(() => _isExpense = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBtn(
    BuildContext context,
    String text,
    Color color,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive
                  ? color
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleBtn(
              context,
              'Daily',
              _isDaily,
              () => setState(() => _isDaily = true),
            ),
          ),
          Expanded(
            child: _buildToggleBtn(
              context,
              'Monthly',
              !_isDaily,
              () => setState(() => _isDaily = false),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Replicated logic
    switch (iconName) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'restaurant':
        return Icons.restaurant;
      case 'commute':
        return Icons.commute;
      case 'home':
        return Icons.home;
      case 'medical_services':
        return Icons.medical_services;
      case 'school':
        return Icons.school;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'work':
        return Icons.work;
      case 'savings':
        return Icons.savings;
      case 'attach_money':
        return Icons.attach_money;
      case 'smoking_rooms':
        return Icons.smoking_rooms;
      case 'liquor':
        return Icons.liquor;
      case 'shopping_basket':
        return Icons.shopping_basket;
      case 'eco':
        return Icons.eco;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'movie':
        return Icons.movie;
      case 'pets':
        return Icons.pets;
      case 'phone_android':
        return Icons.phone_android;
      case 'wifi':
        return Icons.wifi;
      case 'electric_bolt':
        return Icons.electric_bolt;
      case 'coffee':
        return Icons.coffee;
      case 'fastfood':
        return Icons.fastfood;
      case 'checkroom':
        return Icons.checkroom;
      case 'water_drop':
        return Icons.water_drop;
      case 'flight':
        return Icons.flight;
      case 'local_taxi':
        return Icons.local_taxi;
      case 'medication':
        return Icons.medication;
      case 'local_laundry_service':
        return Icons.local_laundry_service;
      case 'content_cut':
        return Icons.content_cut;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'child_care':
        return Icons.child_care;
      case 'car_repair':
        return Icons.car_repair;
      case 'local_parking':
        return Icons.local_parking;
      case 'menu_book':
        return Icons.menu_book;
      case 'subscriptions':
        return Icons.subscriptions;
      case 'music_note':
        return Icons.music_note;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'spa':
        return Icons.spa;
      case 'celebration':
        return Icons.celebration;
      default:
        return Icons.category;
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return; // Prevent double-click
    setState(() => _isSaving = true);

    final provider = context.read<TransactionProvider>();

    // Resolve Category ID
    var finalCategoryId = _selectedCategoryId;
    if (finalCategoryId == null) {
      final categories = provider.categories;
      if (categories.isNotEmpty) {
        final others = categories
            .where((c) => c.name.toLowerCase().contains('other'))
            .firstOrNull;
        finalCategoryId = others?.id ?? categories.first.id;
      }
    }

    // Validation
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      setState(() => _isSaving = false);
      return;
    }

    if (_mode != EntryMode.flexi && _amountController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an amount')));
      setState(() => _isSaving = false);
      return;
    }

    if (finalCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a category')));
      setState(() => _isSaving = false);
      return;
    }

    // --- One Time Mode ---
    if (_mode == EntryMode.oneTime) {
      final success = await provider.addTransaction(
        _titleController.text,
        double.tryParse(_amountController.text) ?? 0.0,
        _isExpense,
        categoryId: finalCategoryId == 'other_virtual' ? null : finalCategoryId,
        paymentMethod: _selectedPaymentMethod,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save transaction')),
          );
        }
      }
      return;
    }

    // --- Quick/Flexi Entry Mode ---
    // Consolidate Save Logic
    final itemData = {
      'title': _titleController.text,
      'amount': _mode == EntryMode.flexi
          ? 0.0
          : (double.tryParse(_amountController.text) ?? 0.0),
      'frequency': _isDaily ? 'daily' : 'monthly',
      'categoryId': finalCategoryId == 'other_virtual' ? null : finalCategoryId,
      'isExpense': _isExpense,
      'icon': _selectedIcon,
      'dueDay': _isDaily ? null : _dueDay,
      'isVariable': _mode == EntryMode.flexi,
      // userId handled by backend service
    };

    if (widget.editingItem != null) {
      // Update existing item
      final error = await provider.updateItem(widget.editingItem!.id, itemData);
      if (error != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Update failed: $error'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return; // Do not close dialog on error
      }
      try {
        await _handleNotification(widget.editingItem!.id, isUpdate: true);
      } catch (e) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated ${_titleController.text}')),
        );
      }
    } else {
      final newItem = await provider.addItem(itemData);
      if (newItem != null) {
        try {
          await _handleNotification(newItem.id, isUpdate: false);
        } catch (e) {}
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleNotification(
    String itemId, {
    required bool isUpdate,
  }) async {
    if (_dueDay == null || _isDaily) {
      if (isUpdate) {
        await NotificationService().cancelNotification(itemId.hashCode);
      }
      return;
    }

    await NotificationService().scheduleMonthlyNotification(
      id: itemId.hashCode,
      title: 'Due: ${_titleController.text}',
      body: 'A friendly reminder to pay this bill.',
      dayOfMonth: _dueDay!,
    );
  }

  Widget _buildSuggestionBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _suggestionMessage!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _suggestionMessage = null; // Dismiss
              });
            },
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
