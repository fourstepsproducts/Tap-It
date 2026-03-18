import 'package:flutter/material.dart';

import 'package:shimmer/shimmer.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../models/item.dart';
import '../providers/transaction_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/user_provider.dart';
import '../providers/goal_provider.dart';
import '../screens/settings/bank_details_screen.dart';
import 'add_item_dialog.dart';
import 'transaction_details_dialog.dart';
import 'add_goal_dialog.dart';
import 'fund_goal_dialog.dart';
import 'goal_details_dialog.dart';
import 'package:intl/intl.dart';

class PersonalDashboard extends StatefulWidget {
  const PersonalDashboard({super.key});

  @override
  State<PersonalDashboard> createState() => _PersonalDashboardState();
}

class _PersonalDashboardState extends State<PersonalDashboard> {
  String _entryMode = 'daily'; // daily, monthly, variable
  bool _isReordering = false; // Track reordering mode

  int _currentPage = 0;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access transaction data
    final provider = context.watch<TransactionProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchData();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200 &&
              !provider.isLoading &&
              provider.hasMore) {
            provider.loadMoreTransactions();
          }
          return false;
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance Cards
              GestureDetector(
                onTap: () {
                  setState(() {
                    _currentPage = (_currentPage + 1) % 5;
                  });
                },
                child: SizedBox(
                  height: 240,
                  child: provider.isLoading
                      ? Shimmer.fromColors(
                          baseColor: theme.brightness == Brightness.dark
                              ? Colors.grey[800]!
                              : Colors.grey[300]!,
                          highlightColor: theme.brightness == Brightness.dark
                              ? Colors.grey[700]!
                              : Colors.grey[100]!,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.9,
                                      end: 1.0,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },

                          child: KeyedSubtree(
                            key: ValueKey<int>(_currentPage),
                            child: _buildCurrentBalanceCard(
                              provider,
                              colorScheme,
                              currencySymbol,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Quick Entries Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isReordering ? 'Reordering Items...' : 'Quick Entries',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _isReordering
                      ? TextButton.icon(
                          onPressed: () =>
                              setState(() => _isReordering = false),
                          icon: const Icon(Icons.check),
                          label: const Text('Done'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                          ),
                        )
                      : IconButton(
                          onPressed: _showAddItemDialog, // Updated
                          icon: const Icon(Icons.add_circle),
                          color: colorScheme.primary,
                        ),
                ],
              ),

              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min, // Center content
                    children: [
                      _buildToggleOption(
                        'Daily',
                        _entryMode == 'daily',
                        () => setState(() => _entryMode = 'daily'),
                      ),
                      _buildToggleOption(
                        'Monthly',
                        _entryMode == 'monthly',
                        () => setState(() => _entryMode = 'monthly'),
                      ),
                      _buildToggleOption(
                        'Flexi',
                        _entryMode == 'variable',
                        () => setState(() => _entryMode = 'variable'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Quick Entries - Dynamic Display
              () {
                if (provider.isLoading) {
                  return _buildSkeletonLoader();
                }

                final items = provider.items.where((item) {
                  if (_entryMode == 'variable') {
                    return item.isVariable ?? false;
                  } else {
                    // Show fixed AND variable items matching the frequency
                    return item.frequency == _entryMode;
                  }
                }).toList();

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _entryMode == 'daily'
                            ? 'No daily entries yet.'
                            : (_entryMode == 'monthly'
                                  ? 'No monthly entries yet.'
                                  : 'No variable entries yet.'),
                        style: GoogleFonts.inter(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ReorderableGridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) {
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                    provider.updateItemsOrder(items);
                  },
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Container(
                      key: ValueKey(item.id),
                      child: _buildItemButton(
                        item,
                        currencySymbol,
                        provider.transactions, // Pass transactions here
                      ),
                    );
                  },
                );
              }(),

              const SizedBox(height: 32),

              // Goal Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Goal',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const AddGoalDialog(),
                      );
                    },
                    icon: const Icon(Icons.add_circle),
                    color: colorScheme.primary,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Goal Nudge Banner
              _buildGoalNudgeBanner(theme, colorScheme, currencySymbol),

              const SizedBox(height: 32),

              // Transactions History
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Recent Transactions - Last 24 Hours with Show More/Less
              () {
                // Filter for last 24 hours
                final recentTransactions = provider.transactions.where((tx) {
                  return tx.dateTime.isAfter(
                    DateTime.now().subtract(const Duration(hours: 24)),
                  );
                }).toList();

                if (provider.isLoading && provider.transactions.isEmpty) {
                  return Shimmer.fromColors(
                    baseColor: theme.brightness == Brightness.dark
                        ? Colors.grey[800]!
                        : Colors.grey[300]!,
                    highlightColor: theme.brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : Colors.grey[100]!,
                    child: Column(
                      children: List.generate(
                        3,
                        (index) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (recentTransactions.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        const Icon(Icons.history, size: 48, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'No recent transactions',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                        Text(
                          '(Last 24 hours)',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    ...recentTransactions.map((tx) {
                      return ListTile(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => TransactionDetailsDialog(
                              transaction: tx,
                              currencySymbol: currencySymbol,
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: tx.isExpense
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          child: Icon(
                            tx.isExpense
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: tx.isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                        title: Text(
                          tx.title,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          DateFormat('h:mm a').format(tx.dateTime),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: Text(
                          '${tx.isExpense ? '-' : '+'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: tx.isExpense ? Colors.red : Colors.green,
                          ),
                        ),
                      );
                    }),
                    // No Load More button for strict "Last 24h" view
                  ],
                );
              }(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalNudgeBanner(
    ThemeData theme,
    ColorScheme colorScheme,
    String currencySymbol,
  ) {
    return Consumer<GoalProvider>(
      builder: (context, goalProvider, child) {
        final now = DateTime.now();
        final displayGoals = goalProvider.goals.where((goal) {
          if (!goal.isCompleted) return true;
          if (goal.completedAt != null) {
            return now.difference(goal.completedAt!).inHours <= 24;
          }
          return false;
        }).toList();
        // Show uncompleted goals first
        displayGoals.sort((a, b) {
          if (a.isCompleted && !b.isCompleted) return 1;
          if (!a.isCompleted && b.isCompleted) return -1;
          return 0;
        });

        if (displayGoals.isEmpty) {
          // Empty State Banner
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.15),
                  colorScheme.primary.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const AddGoalDialog(),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                    child: Icon(Icons.add_task, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set a Financial Goal',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Save for a vacation, car, or emergency!',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colorScheme.primary),
                ],
              ),
            ),
          );
        }

        // Active State Banner (Multiple Goals supported via PageView)
        return SizedBox(
          height: 85, // Fixed height for constraints
          child: PageView.builder(
            controller: PageController(
              viewportFraction: displayGoals.length > 1 ? 0.95 : 1.0,
            ),
            itemCount: displayGoals.length,
            itemBuilder: (context, index) {
              final goal = displayGoals[index];
              final isCompleted = goal.isCompleted;
              final double progress = goal.targetAmount > 0
                  ? (goal.savedAmount / goal.targetAmount).clamp(0.0, 1.0)
                  : 0.0;
              final double remainingAmount =
                  goal.targetAmount - goal.savedAmount;

              return Padding(
                padding: EdgeInsets.only(
                  right:
                      displayGoals.length > 1 && index < displayGoals.length - 1
                      ? 8.0
                      : 0.0,
                ),
                child: GestureDetector(
                  onTap: () {
                    // Show Details if Finished, Edit if Active
                    if (isCompleted) {
                      showDialog(
                        context: context,
                        builder: (context) => GoalDetailsDialog(goal: goal),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (context) => AddGoalDialog(editingGoal: goal),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isCompleted
                          ? LinearGradient(
                              colors: [
                                Colors.amber.withOpacity(0.25),
                                Colors.amber.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                colorScheme.primary.withOpacity(0.15),
                                colorScheme.primary.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCompleted
                            ? Colors.amber.withOpacity(0.6)
                            : colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Progress Ring
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: isCompleted ? 1.0 : progress,
                                strokeWidth: 4,
                                backgroundColor:
                                    theme.brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted
                                      ? Colors.amber
                                      : colorScheme.primary,
                                ),
                              ),
                              Center(
                                child: Text(
                                  goal.icon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              if (isCompleted)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Goal Texts
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                goal.title,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isCompleted
                                    ? 'Goal Reached! 🏆'
                                    : '$currencySymbol${remainingAmount.toStringAsFixed(0)} left this month!',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted
                                      ? Colors.amber[700]
                                      : colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Quick Add Button
                        if (!isCompleted)
                          Material(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                // Open the Fund Goal Dialog
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      FundGoalDialog(goal: goal),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Fund',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildToggleOption(
    String text,
    bool isSelected,
    VoidCallback onTap, {
    bool isSubSelect = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSubSelect ? 12 : 16,
          vertical: isSubSelect ? 6 : 8,
        ),
        margin: EdgeInsets.only(right: 8, top: isSubSelect ? 0 : 0),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isSubSelect
                    ? theme.colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
          border: isSubSelect && !isSelected
              ? Border.all(color: theme.colorScheme.primary.withOpacity(0.2))
              : null,
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isSelected
                ? Colors.white
                : (isSubSelect
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.grey[400] : Colors.grey)),
            fontWeight: FontWeight.w600,
            fontSize: isSubSelect ? 11 : 12,
          ),
        ),
      ),
    );
  }

  Widget _buildItemButton(
    dynamic item,
    String currencySymbol,
    List<Transaction> transactions,
  ) {
    final theme = Theme.of(context);

    // Map icon string to IconData
    IconData iconData = Icons.star;
    if (item.icon == 'shopping_cart') {
      iconData = Icons.shopping_cart;
    } else if (item.icon == 'restaurant') {
      iconData = Icons.restaurant;
    } else if (item.icon == 'commute') {
      iconData = Icons.commute;
    } else if (item.icon == 'home') {
      iconData = Icons.home;
    } else if (item.icon == 'medical_services') {
      iconData = Icons.medical_services;
    } else if (item.icon == 'school') {
      iconData = Icons.school;
    } else if (item.icon == 'fitness_center') {
      iconData = Icons.fitness_center;
    } else if (item.icon == 'smoking_rooms') {
      iconData = Icons.smoking_rooms; // Cigars
    } else if (item.icon == 'liquor') {
      iconData = Icons.liquor; // Alcohol
    } else if (item.icon == 'shopping_basket') {
      iconData = Icons.shopping_basket; // Groceries
    } else if (item.icon == 'eco') {
      iconData = Icons.eco; // Vegetables
    } else if (item.icon == 'local_gas_station') {
      iconData = Icons.local_gas_station; // Fuel
    } else if (item.icon == 'movie') {
      iconData = Icons.movie; // Entertainment
    } else if (item.icon == 'pets') {
      iconData = Icons.pets; // Pets
    } else if (item.icon == 'phone_android') {
      iconData = Icons.phone_android; // Recharge
    } else if (item.icon == 'wifi') {
      iconData = Icons.wifi; // Internet
    } else if (item.icon == 'electric_bolt') {
      iconData = Icons.electric_bolt;
    } else if (item.icon == 'coffee') {
      iconData = Icons.coffee; // Coffee
    } else if (item.icon == 'fastfood') {
      iconData = Icons.fastfood; // Snacks
    } else if (item.icon == 'checkroom') {
      iconData = Icons.checkroom; // Clothes
    } else if (item.icon == 'water_drop') {
      iconData = Icons.water_drop; // Water
    } else if (item.icon == 'flight') {
      iconData = Icons.flight; // Travel
    } else if (item.icon == 'medication') {
      iconData = Icons.medication; // Medicine
    } else if (item.icon == 'content_cut') {
      iconData = Icons.content_cut; // Salon
    } else if (item.icon == 'card_giftcard') {
      iconData = Icons.card_giftcard; // Gift
    } else if (item.icon == 'sports_esports') {
      iconData = Icons.sports_esports; // Games
    } else if (item.icon == 'child_care') {
      iconData = Icons.child_care; // Kids
    } else if (item.icon == 'car_repair') {
      iconData = Icons.car_repair; // Repair
    } else if (item.icon == 'local_parking') {
      iconData = Icons.local_parking; // Parking
    } else if (item.icon == 'subscriptions') {
      iconData = Icons.subscriptions; // Subs
    } else if (item.icon == 'music_note') {
      iconData = Icons.music_note; // Music
    } else if (item.icon == 'cleaning_services') {
      iconData = Icons.cleaning_services; // Maid
    }

    // Dynamic Background Color Logic
    Color backgroundColor = theme.cardColor;
    Color borderColor = theme.colorScheme.primary.withOpacity(0.3);

    String displayAmount = '$currencySymbol${item.amount.toStringAsFixed(0)}';

    if (item.isVariable) {
      // Find last transaction amount for this item
      try {
        final lastTransaction = transactions.firstWhere(
          (t) => t.itemId == item.id,
        );
        displayAmount =
            '$currencySymbol${lastTransaction.amount.toStringAsFixed(0)}';
      } catch (e) {
        displayAmount = 'Variable';
      }
    } else if (item.dueDay != null) {
      final now = DateTime.now();
      DateTime nextDue = DateTime(now.year, now.month, item.dueDay!);

      // If due date passed this month, move to next month
      if (nextDue.isBefore(DateTime(now.year, now.month, now.day))) {
        nextDue = DateTime(now.year, now.month + 1, item.dueDay!);
      }

      final daysUntil = nextDue
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

      if (daysUntil <= 3) {
        backgroundColor = item.isExpense
            ? Colors.red.withOpacity(0.2)
            : Colors.green.withOpacity(0.2);
      } else if (daysUntil <= 7) {
        backgroundColor = item.isExpense
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1);
      }
    }

    return GestureDetector(
      onTap: _isReordering
          ? null
          : () async {
              if (item.isVariable) {
                await _showVariableEntryDialog(item);
                return;
              }

              // Regular Quick Entry Logic
              // Capture context-dependent objects BEFORE async gap
              final provider = context.read<TransactionProvider>();
              final messenger = ScaffoldMessenger.of(context);

              // Ask for Payment Method for ALL transactions
              String? paymentMethod = await _selectPaymentMethod();
              if (paymentMethod == null) return; // Cancelled

              if (mounted) {
                provider.addTransaction(
                  item.title,
                  item.amount,
                  item.isExpense,
                  categoryId: item.categoryId,
                  itemId: item.id,
                  paymentMethod: paymentMethod,
                );
                messenger.showSnackBar(
                  SnackBar(content: Text('Added ${item.title}')),
                );
              }
            },
      onLongPress: _isReordering ? null : () => _showItemOptions(item),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconData,
                    color: item.isVariable
                        ? Colors.amber.shade700
                        : (item.isExpense ? Colors.red : Colors.green),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayAmount,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: item.isVariable
                          ? Colors.amber.shade700
                          : (item.isExpense ? Colors.red : Colors.green),
                    ),
                  ),
                ],
              ),
            ),
            if (item.dueDay != null)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: item.isExpense
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Due ${item.dueDay}${_getOrdinal(item.dueDay!)}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: item.isExpense ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVariableEntryDialog(dynamic item) async {
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add ${item.title}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: amountController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixText: context.read<CurrencyProvider>().currencySymbol,
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'Required' : null,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final amount = double.parse(amountController.text);

                // Capture context-dependent objects BEFORE async gap
                final provider = context.read<TransactionProvider>();
                final messenger = ScaffoldMessenger.of(context);

                Navigator.pop(dialogContext); // Close using dialog context

                // Ask for payment method using outer context (implicit)
                final paymentMethod = await _selectPaymentMethod();

                // Check if widget is still mounted
                if (paymentMethod != null && mounted) {
                  // Use captured provider
                  provider.addTransaction(
                    item.title,
                    amount,
                    item.isExpense,
                    categoryId: item.categoryId,
                    itemId: item.id,
                    paymentMethod: paymentMethod,
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text('Added ${item.title}')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showItemOptions(dynamic item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.swap_vert),
                title: const Text('Reorder Items'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _isReordering = true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditItemDialog(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteItem(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _deleteItem(dynamic item) {
    context.read<TransactionProvider>().deleteItem(item.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted ${item.title}')));
  }

  void _showEditItemDialog(dynamic item) {
    _showAddItemDialog(editingItem: item);
  }

  // --- Add/Edit Quick Entry Dialog ---
  void _showAddItemDialog({
    String? preSelectedCategoryId,
    bool? preSelectedIsExpense,
    bool? preSelectedIsDaily,
    bool? preSelectedIsVariable, // NEW
    Item? editingItem,
  }) {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(
        category: null, // We don't have a category context here
        editingItem: editingItem,
        isDaily: preSelectedIsDaily ?? (_entryMode == 'daily'),
        initialIsVariable:
            preSelectedIsVariable ?? (_entryMode == 'variable'), // NEW
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double balance,
    required double income,
    required double expense,
    required ColorScheme colorScheme,
    required String currencySymbol,
    required int currentPage,
    required int totalPages,
    Color? boxColor, // Added
  }) {
    return Container(
      // margin removed to match LedgerDashboard and fix shade mismatch
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: boxColor ?? colorScheme.primary, // Use boxColor if provided
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$currencySymbol${balance.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Income',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currencySymbol${income.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF51CF66), // Green
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1, color: Colors.white12),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Expenses',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$currencySymbol${expense.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFF6B6B), // Red
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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

          // Indicators (Dots)
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentBalanceCard(
    TransactionProvider provider,
    ColorScheme colorScheme,
    String currencySymbol,
  ) {
    switch (_currentPage) {
      case 0:
        return _buildBalanceCard(
          title: 'Total Balance',
          balance: provider.totalBalance,
          income: provider.totalIncome,
          expense: provider.totalExpenses,
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 0,
          totalPages: 5,
        );
      case 1:
        return _buildBalanceCard(
          title: 'Yearly Balance',
          balance: _calculateBalance(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year;
          }),
          income: _calculateIncome(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year;
          }),
          expense: _calculateExpense(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year;
          }),
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 1,
          totalPages: 5,
        );
      case 2:
        return _buildBalanceCard(
          title: 'Monthly Balance',
          balance: _calculateBalance(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year && t.dateTime.month == now.month;
          }),
          income: _calculateIncome(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year && t.dateTime.month == now.month;
          }),
          expense: _calculateExpense(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year && t.dateTime.month == now.month;
          }),
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 2,
          totalPages: 5,
        );
      case 3:
        return _buildBalanceCard(
          title: 'Weekly Balance',
          balance: _calculateBalance(provider.transactions, (t) {
            final now = DateTime.now();
            final weekAgo = now.subtract(const Duration(days: 7));
            return t.dateTime.isAfter(weekAgo);
          }),
          income: _calculateIncome(provider.transactions, (t) {
            final now = DateTime.now();
            final weekAgo = now.subtract(const Duration(days: 7));
            return t.dateTime.isAfter(weekAgo);
          }),
          expense: _calculateExpense(provider.transactions, (t) {
            final now = DateTime.now();
            final weekAgo = now.subtract(const Duration(days: 7));
            return t.dateTime.isAfter(weekAgo);
          }),
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 3,
          totalPages: 5,
        );
      case 4:
      default:
        return _buildBalanceCard(
          title: 'Daily Balance',
          balance: _calculateBalance(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year &&
                t.dateTime.month == now.month &&
                t.dateTime.day == now.day;
          }),
          income: _calculateIncome(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year &&
                t.dateTime.month == now.month &&
                t.dateTime.day == now.day;
          }),
          expense: _calculateExpense(provider.transactions, (t) {
            final now = DateTime.now();
            return t.dateTime.year == now.year &&
                t.dateTime.month == now.month &&
                t.dateTime.day == now.day;
          }),
          colorScheme: colorScheme,
          currencySymbol: currencySymbol,
          currentPage: 4,
          totalPages: 5,
        );
    }
  }

  // Helper methods for calculations
  double _calculateBalance(
    List<Transaction> transactions,
    bool Function(Transaction) filter,
  ) {
    double total = 0;
    for (var t in transactions) {
      if (filter(t)) {
        if (t.isExpense) {
          total -= t.amount;
        } else {
          total += t.amount;
        }
      }
    }
    return total;
  }

  double _calculateIncome(
    List<Transaction> transactions,
    bool Function(Transaction) filter,
  ) {
    return transactions
        .where((t) => !t.isExpense && filter(t))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _calculateExpense(
    List<Transaction> transactions,
    bool Function(Transaction) filter,
  ) {
    return transactions
        .where((t) => t.isExpense && filter(t))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Future<String?> _selectPaymentMethod() {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Consumer<UserProvider>(
          builder: (context, userProvider, child) {
            final isGridView = userProvider.paymentMethodLayout == 'grid';
            final primaryMethods = userProvider.primaryPaymentMethods;

            Future<void> handleLongPress(String method) async {
              final selectedBank = await showModalBottomSheet<String>(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (BuildContext context) {
                  final banks = userProvider.banks;
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Bank for this Transaction',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (banks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Text(
                                "No banks added in Settings.",
                                style: GoogleFonts.inter(color: Colors.grey),
                              ),
                            ),
                          ),
                        ...banks.map(
                          (bank) => ListTile(
                            leading: const Icon(Icons.account_balance),
                            title: Text(
                              bank,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context, bank);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );

              if (selectedBank != null) {
                Navigator.pop(context, '$method ($selectedBank)');
              }
            }

            final customMethods = userProvider.customPaymentMethods;
            final allMethods =
                [
                  {'name': 'Cash', 'icon': Icons.money},
                  {'name': 'UPI', 'icon': Icons.qr_code},
                  {'name': 'Debit Card', 'icon': Icons.credit_card},
                  {'name': 'Credit Card', 'icon': Icons.credit_score},
                  {'name': 'Bank Account', 'icon': Icons.account_balance},
                  ...customMethods.map(
                    (m) => {'name': m, 'icon': Icons.payment},
                  ),
                ].where((method) {
                  final name = method['name'] as String;
                  if (customMethods.contains(name)) return true;
                  return userProvider.isPaymentMethodEnabled(name);
                }).toList();

            return AlertDialog(
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payment Method',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        userProvider.setPaymentMethodLayout('grid'),
                    icon: Icon(
                      Icons.grid_view_rounded,
                      size: 20,
                      color: isGridView
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        userProvider.setPaymentMethodLayout('list'),
                    icon: Icon(
                      Icons.view_headline_rounded,
                      size: 20,
                      color: !isGridView
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: isGridView
                    ? GridView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.0,
                            ),
                        itemCount: allMethods.length,
                        itemBuilder: (context, index) {
                          final item = allMethods[index];
                          final name = item['name'] as String;
                          final icon = item['icon'] as IconData;

                          return _buildPaymentOption(
                            context,
                            name,
                            icon,
                            userProvider,
                            primaryBank:
                                userProvider.isPaymentMethodEnabled(name)
                                ? primaryMethods[name]
                                : null,
                            onLongPress: () {
                              if (name != 'Cash') {
                                handleLongPress(name);
                              }
                            },
                          );
                        },
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: allMethods.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = allMethods[index];
                          final name = item['name'] as String;
                          final icon = item['icon'] as IconData;

                          return _buildVerticalPaymentOption(
                            context,
                            name,
                            icon,
                            userProvider,
                            primaryBank:
                                userProvider.isPaymentMethodEnabled(name)
                                ? primaryMethods[name]
                                : null,
                            onLongPress: () {
                              if (name != 'Cash') {
                                handleLongPress(name);
                              }
                            },
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVerticalPaymentOption(
    BuildContext context,
    String method,
    IconData icon,
    UserProvider userProvider, {
    String? primaryBank,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: () {
        if (method != 'Cash' && userProvider.banks.isEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Add Bank Details?',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'You haven\'t added any banks yet. Adding a bank helps you track accounts better.',
                style: GoogleFonts.inter(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context, method);
                  },
                  child: const Text('Use Default'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BankDetailsScreen(),
                      ),
                    );
                  },
                  child: const Text('Add Bank'),
                ),
              ],
            ),
          );
        } else if (method != 'Cash' &&
            primaryBank == null &&
            userProvider.banks.isNotEmpty) {
          onLongPress?.call();
        } else {
          String result = method;
          if (primaryBank != null) {
            result = '$method ($primaryBank)';
          }
          Navigator.pop(context, result);
        }
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    method,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  if (primaryBank != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      primaryBank,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8), // Replaced arrow with some trailing space
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    BuildContext context,
    String method,
    IconData icon,
    UserProvider userProvider, {
    String? primaryBank,
    VoidCallback? onLongPress,
  }) {
    return InkWell(
      onTap: () {
        if (method != 'Cash' && userProvider.banks.isEmpty) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                'Add Bank Details?',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Text(
                'You haven\'t added any banks yet. Adding a bank helps you track accounts better.',
                style: GoogleFonts.inter(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close suggestion
                    Navigator.pop(context, method); // Return default method
                  },
                  child: const Text('Use Default'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close suggestion
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BankDetailsScreen(),
                      ),
                    );
                  },
                  child: const Text('Add Bank'),
                ),
              ],
            ),
          );
        } else if (method != 'Cash' &&
            primaryBank == null &&
            userProvider.banks.isNotEmpty) {
          // If no primary is set but banks exist, prompt for selection
          onLongPress?.call();
        } else {
          String result = method;
          if (primaryBank != null) {
            result = '$method ($primaryBank)';
          }
          Navigator.pop(context, result);
        }
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 8,
        ), // Reduced padding
        constraints: const BoxConstraints(minHeight: 100),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ), // Reduced icon size
            const SizedBox(height: 6),
            Text(
              method,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                fontSize: 13, // Reduced font size
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Always reserve space for the bank pill
            Visibility(
              visible: primaryBank != null,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  primaryBank ?? 'Placeholder',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Widget _buildSkeletonLoader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
