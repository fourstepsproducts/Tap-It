import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/transaction_provider.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../widgets/category_card.dart';
import '../widgets/category_dialog.dart';
import '../widgets/add_item_dialog.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Categories',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCategoryList('expense'), _buildCategoryList('income')],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCategoryDialog(context);
        },
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildCategoryList(String type) {
    final provider = context.watch<TransactionProvider>();
    final categories = provider.categories
        .where((c) => c.type == type)
        .toList();

    // Sorting: Alphabetical
    categories.sort((a, b) => a.name.compareTo(b.name));

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 48,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No $type categories',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to add your first category',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final usageCount = provider.getCategoryUsageCount(category.id);

        // Filter items for this category from the global list
        final categoryItems = provider.quickItems
            .where((i) => i.categoryId == category.id)
            .toList();

        return CategoryCard(
          key: ValueKey(category.id),
          category: category,
          usageCount: usageCount,
          items: categoryItems,
          onEdit: () => _showCategoryDialog(context, category: category),
          onDelete: () => _deleteCategory(context, category),
          onItemTap: (item) => _showAddItemDialog(context, existingItem: item),
          onAddItem: () => _showAddItemDialog(context, category: category),
          colorScheme: Theme.of(context).colorScheme,
        );
      },
    );
  }

  // Removed navigation to detail screen

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    try {
      showDialog(
        context: context,
        builder: (context) {
          return CategoryDialog(
            category: category,
            initialType: _tabController.index == 0 ? 'expense' : 'income',
          );
        },
      );
    } catch (e) {
      // ignore: empty_catches
    }
  }

  void _showAddItemDialog(
    BuildContext context, {
    Category? category,
    Item? existingItem,
  }) {
    showDialog(
      context: context,
      builder: (context) =>
          AddItemDialog(category: category, existingItem: existingItem),
    );
  }

  void _deleteCategory(BuildContext context, Category category) {
    final provider = context.read<TransactionProvider>();
    final hasTransactions = provider.hasTransactionsForCategory(category.id);

    if (hasTransactions) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Cannot Delete',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'This category is used in existing transactions and cannot be deleted. Please reassign or delete the transactions first.',
            style: GoogleFonts.inter(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: GoogleFonts.inter()),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Category',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${category.name}"?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () {
              provider.deleteCategory(category.id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
