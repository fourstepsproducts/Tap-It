import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/investment_provider.dart';
import '../../providers/dutch_provider.dart';

class ResetOptionsScreen extends StatefulWidget {
  const ResetOptionsScreen({super.key});

  @override
  State<ResetOptionsScreen> createState() => _ResetOptionsScreenState();
}

class _ResetOptionsScreenState extends State<ResetOptionsScreen> {
  bool _isProcessing = false;

  List<Map<String, dynamic>> _getModules(ThemeData theme) {
    return [
      {
        'id': 'Spend',
        'title': 'Tap Spend',
        'description': 'Daily expenses, categories, and quick entries.',
        'icon': Icons.shopping_bag_outlined,
        'color': theme.colorScheme.primary,
      },
      {
        'id': 'Due',
        'title': 'Pay Due',
        'description': 'Ledger transactions, debts, and settlements.',
        'icon': Icons.account_balance_wallet_outlined,
        'color': theme.colorScheme.primary,
      },
      {
        'id': 'Invest',
        'title': 'Invest Ment',
        'description': 'Current investments and transaction history.',
        'icon': Icons.trending_up,
        'color': theme.colorScheme.primary,
      },
      {
        'id': 'Split',
        'title': 'Dutch Split',
        'description': 'Shared expenses, group balances, and settlements.',
        'icon': Icons.groups_outlined,
        'color': theme.colorScheme.primary,
      },
    ];
  }

  Future<void> _handleModuleTap(Map<String, dynamic> module) async {
    final rangeResult = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _RangeSelector(moduleTitle: module['title']),
    );

    if (rangeResult == null) return;

    final String label = rangeResult['label'];
    final DateTime? startDate = rangeResult['startDate'];
    final DateTime? endDate = rangeResult['endDate'];

    _confirmAndExecute(
      module: module['id'],
      moduleTitle: module['title'],
      rangeLabel: label,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<void> _confirmAndExecute({
    required String module,
    required String moduleTitle,
    required String rangeLabel,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset $moduleTitle?'),
        content: Text(
          'This will permanently delete all $moduleTitle data for the selected range: $rangeLabel.\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              elevation: 0,
            ),
            child: const Text('Reset Now'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeReset(module, startDate, endDate, moduleTitle);
    }
  }

  Future<void> _executeReset(
    String module,
    DateTime? start,
    DateTime? end,
    String title,
  ) async {
    setState(() => _isProcessing = true);
    final theme = Theme.of(context);
    try {
      if (module == 'Spend') {
        await context.read<TransactionProvider>().resetSpend(
          startDate: start,
          endDate: end,
        );
      } else if (module == 'Due') {
        await context.read<LedgerProvider>().resetDue(
          startDate: start,
          endDate: end,
        );
      } else if (module == 'Invest') {
        await context.read<InvestmentProvider>().resetInvest(
          startDate: start,
          endDate: end,
        );
      } else if (module == 'Split') {
        await context.read<DutchProvider>().resetSplit(
          startDate: start,
          endDate: end,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reset Successful')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleGlobalReset() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'FULL APP RESET',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        content: const Text(
          'WARNING: This will clear EVERYTHING from all modules (Spend, Due, Invest, Split).\n\nYour app will be completely empty. Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              elevation: 0,
            ),
            child: const Text('YES, RESET EVERYTHING'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await Future.wait([
          context.read<TransactionProvider>().resetSpend(),
          context.read<LedgerProvider>().resetDue(),
          context.read<InvestmentProvider>().resetInvest(),
          context.read<DutchProvider>().resetSplit(),
        ]);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Global App Reset Successful'),
              backgroundColor: theme.colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Global Reset Error: $e'),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modules = _getModules(theme);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Options'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Choose a module to reset',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              ...modules.map((m) => _buildModuleCard(m, theme)),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              Text(
                'Advanced Options',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: theme.colorScheme.errorContainer.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.colorScheme.error.withOpacity(0.1),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.error,
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.onError,
                    ),
                  ),
                  title: Text(
                    'Overall App Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  subtitle: Text(
                    'Wipe all data from the entire app',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.error,
                  ),
                  onTap: _isProcessing ? null : _handleGlobalReset,
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: theme.colorScheme.surface.withOpacity(0.7),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(Map<String, dynamic> module, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: module['color'].withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(module['icon'], color: module['color']),
        ),
        title: Text(
          module['title'],
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            module['description'],
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: _isProcessing ? null : () => _handleModuleTap(module),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final String moduleTitle;

  const _RangeSelector({required this.moduleTitle});

  void _select(
    BuildContext context,
    String label,
    DateTime? start,
    DateTime? end,
  ) {
    Navigator.pop(context, {
      'label': label,
      'startDate': start,
      'endDate': end,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    final startOfMonth = DateTime(now.year, now.month, 1);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Reset $moduleTitle For...',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildRangeTile(
            context,
            Icons.today,
            'Today',
            () => _select(context, 'Today', today, endToday),
          ),
          _buildRangeTile(
            context,
            Icons.calendar_view_week,
            'Weekly',
            () => _select(context, 'This Week', startOfWeek, now),
          ),
          _buildRangeTile(
            context,
            Icons.calendar_month,
            'Monthly',
            () => _select(context, 'This Month', startOfMonth, now),
          ),
          _buildRangeTile(
            context,
            Icons.all_inclusive,
            'Everything',
            () => _select(context, 'Everything', null, null),
          ),
          _buildRangeTile(context, Icons.date_range, 'Custom Range', () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      primary: theme.colorScheme.primary,
                      onPrimary: theme.colorScheme.onPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null && context.mounted) {
              _select(context, 'Custom Range', picked.start, picked.end);
            }
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRangeTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 24),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
