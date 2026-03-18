import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import '../providers/transaction_provider.dart';
import '../providers/currency_provider.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/goal_provider.dart';
import '../widgets/goal_details_dialog.dart';

class PersonalGraphScreen extends StatefulWidget {
  const PersonalGraphScreen({super.key});

  @override
  State<PersonalGraphScreen> createState() => _PersonalGraphScreenState();
}

class _PersonalGraphScreenState extends State<PersonalGraphScreen> {
  String _selectedPeriod = 'W'; // D, W, M, Y, All
  int _insightIndex =
      2; // 0: Daily, 1: Weekly, 2: Monthly, 3: Yearly, 4: Overall
  final List<String> _insightPeriods = [
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'Overall',
  ];
  int _incomeVsExpenseIndex = 2; // Default to Monthly

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TransactionProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;

    final transactions = _getFilteredTransactions(provider.transactions);
    final totalTransactions = transactions.length;
    final incomeTransactions = transactions.where((t) => !t.isExpense).toList();
    final expenseTransactions = transactions.where((t) => t.isExpense).toList();

    final totalIncome = incomeTransactions.fold(
      0.0,
      (sum, t) => sum + t.amount,
    );
    final totalExpense = expenseTransactions.fold(
      0.0,
      (sum, t) => sum + t.amount,
    );
    final average = totalTransactions > 0
        ? (totalIncome + totalExpense) / totalTransactions
        : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Statistics',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 24),

              // Income vs Expenses Card
              // Income vs Expenses Card
              _buildIncomeExpenseCard(
                theme,
                currencySymbol,
                provider.transactions,
              ),
              const SizedBox(height: 24),

              // Stat Cards Grid
              _buildStatCards(
                theme,
                currencySymbol,
                totalTransactions,
                average,
                incomeTransactions.length,
                expenseTransactions.length,
              ),
              const SizedBox(height: 24),

              // Spending Trend
              _buildSpendingTrend(theme, currencySymbol, provider.transactions),
              const SizedBox(height: 24),

              // Top Expenses
              _buildTopExpenses(theme, currencySymbol, provider),
              const SizedBox(height: 24),

              // Spending Insights Card
              // Spending Insights Card
              _buildSpendingInsights(
                theme,
                currencySymbol,
                provider.transactions, // Pass ALL transactions
                provider.categories,
              ),
              const SizedBox(height: 24),

              // Completed Goals List
              _buildCompletedGoals(theme, currencySymbol),
            ],
          ),
        ),
      ),
    );
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> transactions) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'D':
        return transactions
            .where(
              (t) =>
                  t.dateTime.year == now.year &&
                  t.dateTime.month == now.month &&
                  t.dateTime.day == now.day,
            )
            .toList();
      case 'W':
        final weekAgo = now.subtract(const Duration(days: 7));
        return transactions.where((t) => t.dateTime.isAfter(weekAgo)).toList();
      case 'M':
        return transactions
            .where(
              (t) =>
                  t.dateTime.year == now.year && t.dateTime.month == now.month,
            )
            .toList();
      case 'Y':
        return transactions.where((t) => t.dateTime.year == now.year).toList();
      case 'All':
      default:
        return transactions;
    }
  }

  Widget _buildIncomeExpenseCard(
    ThemeData theme,
    String currency,
    List<Transaction> allTransactions,
  ) {
    final period = _insightPeriods[_incomeVsExpenseIndex];
    final now = DateTime.now();
    List<Transaction> filteredTransactions = allTransactions;

    switch (period) {
      case 'Daily':
        filteredTransactions = allTransactions
            .where(
              (t) =>
                  t.dateTime.year == now.year &&
                  t.dateTime.month == now.month &&
                  t.dateTime.day == now.day,
            )
            .toList();
        break;
      case 'Weekly':
        final weekAgo = now.subtract(const Duration(days: 7));
        filteredTransactions = allTransactions
            .where((t) => t.dateTime.isAfter(weekAgo))
            .toList();
        break;
      case 'Monthly':
        filteredTransactions = allTransactions
            .where(
              (t) =>
                  t.dateTime.year == now.year && t.dateTime.month == now.month,
            )
            .toList();
        break;
      case 'Yearly':
        filteredTransactions = allTransactions
            .where((t) => t.dateTime.year == now.year)
            .toList();
        break;
      case 'Overall':
      default:
        break;
    }

    final income = filteredTransactions
        .where((t) => !t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = filteredTransactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final total = income + expense;
    final incomePercent = total > 0 ? (income / total) * 100 : 0.0;
    final expensePercent = total > 0 ? (expense / total) * 100 : 0.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _incomeVsExpenseIndex =
              (_incomeVsExpenseIndex + 1) % _insightPeriods.length;
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Container(
          key: ValueKey<int>(_incomeVsExpenseIndex),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.pie_chart, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Income vs Expenses ($period)',
                              style: GoogleFonts.inter(
                                fontSize: 16, // Slightly reduced to fit
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.touch_app,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Progress Bar (Dual Color: Green for Income, Red for Expense)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 6,
                        width: double.infinity,
                        color: Colors.white.withOpacity(0.15),
                        child: (income > 0 || expense > 0)
                            ? Row(
                                children: [
                                  if (income > 0)
                                    Expanded(
                                      flex: (income * 100).toInt(),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Color(0xFF51CF66), // Light green
                                              Color(0xFF37B24D), // Darker green
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (expense > 0)
                                    Expanded(
                                      flex: (expense * 100).toInt(),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Color(0xFFFF6B6B), // Light red
                                              Color(0xFFE03131), // Darker red
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${incomePercent.toStringAsFixed(1)}%',
                                style: GoogleFonts.inter(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Income',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$currency${income.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 80,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '${expensePercent.toStringAsFixed(1)}%',
                                style: GoogleFonts.inter(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Expenses',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$currency${expense.toStringAsFixed(0)}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: _buildDots(
                  _incomeVsExpenseIndex,
                  _insightPeriods.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(
    ThemeData theme,
    String currency,
    int total,
    double avg,
    int incomeCount,
    int expenseCount,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          theme,
          'Total Transactions',
          total.toString(),
          Icons.receipt_long,
          theme.colorScheme.primary,
        ),
        _buildStatCard(
          theme,
          'Average',
          '$currency${avg.toStringAsFixed(0)}',
          Icons.trending_up,
          Colors.red,
        ),
        _buildStatCard(
          theme,
          'Income Count',
          incomeCount.toString(),
          Icons.add_circle,
          Colors.green,
        ),
        _buildStatCard(
          theme,
          'Expense Count',
          expenseCount.toString(),
          Icons.remove_circle,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTrend(
    ThemeData theme,
    String currency,
    List<Transaction> allTransactions,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Trend',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              _buildPeriodSelector(theme),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SizedBox(
              height: 180, // Increased height to prevent overflow
              child: _buildBarChart(theme, allTransactions),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    final periods = ['D', 'W', 'M', 'Y', 'All'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: periods.map((period) {
        final isSelected = period == _selectedPeriod;
        return GestureDetector(
          onTap: () => setState(() => _selectedPeriod = period),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              period,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBarChart(ThemeData theme, List<Transaction> allTransactions) {
    final now = DateTime.now();
    Map<String, double> data = {};

    // Get filtered expenses
    final expenses = _getFilteredTransactions(
      allTransactions,
    ).where((t) => t.isExpense);

    // Build data based on period
    if (_selectedPeriod == 'W') {
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = DateFormat('E').format(date);
        data[key] = 0;
      }
      for (var t in expenses) {
        final key = DateFormat('E').format(t.dateTime);
        if (data.containsKey(key)) {
          data[key] = data[key]! + t.amount;
        }
      }
    } else if (_selectedPeriod == 'D') {
      for (int hour = 0; hour < 24; hour += 4) {
        data['${hour}h'] = 0;
      }
      for (var t in expenses) {
        final hour = (t.dateTime.hour ~/ 4) * 4;
        final key = '${hour}h';
        if (data.containsKey(key)) {
          data[key] = data[key]! + t.amount;
        }
      }
    } else if (_selectedPeriod == 'M') {
      // Monthly View - Show Weeks 1-5
      for (int i = 1; i <= 5; i++) {
        data['W$i'] = 0;
      }
      for (var t in expenses) {
        // Calculate week number (1-5 approximations)
        // Simple approximation: (day / 7).ceil()
        final day = t.dateTime.day;
        final week = (day / 7).ceil();
        final key = 'W${week > 5 ? 5 : week}'; // Handle 31st day edge case
        if (data.containsKey(key)) {
          data[key] = data[key]! + t.amount;
        }
      }
    } else {
      data = {'No': 0, 'Data': 0};
    }

    final maxAmount = data.values.isEmpty ? 1.0 : data.values.reduce(math.max);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.entries.map((entry) {
        final height = maxAmount > 0 ? (entry.value / maxAmount) * 100 : 0.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 32,
              height: height,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.key,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTopExpenses(
    ThemeData theme,
    String currency,
    TransactionProvider provider,
  ) {
    final expenses = provider.transactions.where((t) => t.isExpense).toList();

    // Group by category
    Map<String, double> categoryTotals = {};
    for (var t in expenses) {
      if (t.categoryId != null) {
        categoryTotals[t.categoryId!] =
            (categoryTotals[t.categoryId] ?? 0) + t.amount;
      }
    }

    // Sort and take top 3
    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Expenses',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 16),
          if (top3.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No expense data available',
                  style: GoogleFonts.inter(color: Colors.grey.shade400),
                ),
              ),
            )
          else
            ...top3.map((entry) {
              final category = provider.categories.firstWhere(
                (c) => c.id == entry.key,
                orElse: () => provider.categories.isNotEmpty
                    ? provider.categories.first
                    : Category(
                        id: 'unknown',
                        userId: '',
                        name: 'Uncategorized',
                        type: 'expense',
                        icon: 'help_outline',
                      ),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.category,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$currency${entry.value.toStringAsFixed(0)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSpendingInsights(
    ThemeData theme,
    String currency,
    List<Transaction> allTransactions,
    List<Category> categories,
  ) {
    final period = _insightPeriods[_insightIndex];

    // Filter expenses based on independent insight period
    final now = DateTime.now();
    List<Transaction> filteredExpenses = allTransactions
        .where((t) => t.isExpense)
        .toList();

    switch (period) {
      case 'Daily':
        filteredExpenses = filteredExpenses
            .where(
              (t) =>
                  t.dateTime.year == now.year &&
                  t.dateTime.month == now.month &&
                  t.dateTime.day == now.day,
            )
            .toList();
        break;
      case 'Weekly':
        final weekAgo = now.subtract(const Duration(days: 7));
        filteredExpenses = filteredExpenses
            .where((t) => t.dateTime.isAfter(weekAgo))
            .toList();
        break;
      case 'Monthly':
        filteredExpenses = filteredExpenses
            .where(
              (t) =>
                  t.dateTime.year == now.year && t.dateTime.month == now.month,
            )
            .toList();
        break;
      case 'Yearly':
        filteredExpenses = filteredExpenses
            .where((t) => t.dateTime.year == now.year)
            .toList();
        break;
      case 'Overall':
      default:
        // Already all expenses
        break;
    }

    final total = filteredExpenses.fold(0.0, (sum, t) => sum + t.amount);
    final count = filteredExpenses.length;
    final avg = count > 0 ? total / count : 0.0;

    // Find highest and lowest spending days (Only relevant for > 1 day periods, but we can show top tx for daily)
    String highestLabel = 'Highest Day';
    String highestVal = 'N/A';
    String lowestLabel = 'Lowest Day';
    String lowestVal = 'N/A';

    if (period == 'Daily') {
      highestLabel = 'Highest Transaction';
      lowestLabel = 'Lowest Transaction';
      if (filteredExpenses.isNotEmpty) {
        final sorted = List<Transaction>.from(filteredExpenses)
          ..sort((a, b) => b.amount.compareTo(a.amount));
        highestVal = '$currency${sorted.first.amount.toStringAsFixed(0)}';
        lowestVal = '$currency${sorted.last.amount.toStringAsFixed(0)}';
      }
    } else {
      Map<String, double> dailyTotals = {};
      for (var t in filteredExpenses) {
        final key = DateFormat('yyyy-MM-dd').format(t.dateTime);
        dailyTotals[key] = (dailyTotals[key] ?? 0) + t.amount;
      }
      final sortedDays = dailyTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (sortedDays.isNotEmpty) {
        final hDate = DateTime.parse(sortedDays.first.key);
        final lDate = DateTime.parse(sortedDays.last.key);
        final fmt = period == 'Yearly' ? 'MMM d' : 'EEE';
        highestVal =
            '${DateFormat(fmt).format(hDate)} ($currency${sortedDays.first.value.toStringAsFixed(0)})';
        lowestVal =
            '${DateFormat(fmt).format(lDate)} ($currency${sortedDays.last.value.toStringAsFixed(0)})';
      }
    }

    // Most spent category
    Map<String, double> catTotals = {};
    for (var t in filteredExpenses) {
      if (t.categoryId != null) {
        catTotals[t.categoryId!] = (catTotals[t.categoryId] ?? 0) + t.amount;
      }
    }
    final topCatEntry = catTotals.entries.isEmpty
        ? null
        : catTotals.entries.reduce((a, b) => a.value > b.value ? a : b);

    String topCatName = 'N/A';
    double topCatVal = 0.0;

    if (topCatEntry != null && categories.isNotEmpty) {
      final found = categories.firstWhere(
        (c) => c.id == topCatEntry.key,
        orElse: () => categories.isNotEmpty
            ? categories.first
            : Category(
                id: 'unknown',
                userId: '',
                name: 'Uncategorized',
                type: 'expense',
                icon: 'help_outline',
              ),
      );
      topCatName = found.name;
      topCatVal = topCatEntry.value;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _insightIndex = (_insightIndex + 1) % _insightPeriods.length;
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Container(
          key: ValueKey<int>(_insightIndex),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.8),
                theme.colorScheme.primary,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.insights,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Insights ($period)',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.touch_app,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInsightRow(
                      'Total Spent',
                      total > 0
                          ? '$currency${total.toStringAsFixed(0)}'
                          : 'N/A',
                    ),
                    _buildInsightRow(
                      'Avg Per Tx',
                      '$currency${avg.toStringAsFixed(0)}',
                    ),
                    _buildInsightRow('Total Transactions', count.toString()),
                    const Divider(color: Colors.white24, height: 24),
                    _buildInsightRow(highestLabel, highestVal),
                    _buildInsightRow(lowestLabel, lowestVal),
                    const Divider(color: Colors.white24, height: 24),
                    _buildInsightRow('Top Category', topCatName),
                    _buildInsightRow(
                      'Category Total',
                      topCatVal > 0
                          ? '$currency${topCatVal.toStringAsFixed(0)}'
                          : 'N/A',
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                left: 0,
                right: 0,
                child: _buildDots(_insightIndex, _insightPeriods.length),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots(int currentIndex, int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentIndex == index
                ? Colors.white
                : Colors.white.withOpacity(0.3),
          ),
        );
      }),
    );
  }

  Widget _buildCompletedGoals(ThemeData theme, String currency) {
    return Consumer<GoalProvider>(
      builder: (context, goalProvider, child) {
        final completedGoals = goalProvider.goals
            .where((g) => g.isCompleted)
            .toList();

        if (completedGoals.isEmpty) {
          return const SizedBox.shrink();
        }

        // Sort by completedAt descending if available
        completedGoals.sort((a, b) {
          if (a.completedAt != null && b.completedAt != null) {
            return b.completedAt!.compareTo(a.completedAt!);
          }
          return 0;
        });

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed Goals',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 16),
              ...completedGoals.map((goal) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => GoalDetailsDialog(goal: goal),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.emoji_events,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  goal.completedAt != null
                                      ? 'Completed on ${DateFormat('MMM d, yyyy').format(goal.completedAt!)}'
                                      : 'Completed',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$currency${goal.targetAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
