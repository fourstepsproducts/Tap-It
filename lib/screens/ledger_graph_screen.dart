import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import '../models/ledger_transaction.dart';

// We need to define PieChartPainter here if it's not exported or if we want to be independent.
// Given previous view of graph_screen.dart, it uses a custom painter. We should probably duplicate or extract it.
// For now, I'll copy the painter class at the bottom to avoid dependency issues if it's private.

class LedgerGraphScreen extends StatefulWidget {
  final List<LedgerTransaction> transactions;
  final String currentUserContact;
  final String currencySymbol;

  const LedgerGraphScreen({
    super.key,
    required this.transactions,
    required this.currentUserContact,
    this.currencySymbol = '₹',
  });

  @override
  State<LedgerGraphScreen> createState() => _LedgerGraphScreenState();
}

class _LedgerGraphScreenState extends State<LedgerGraphScreen> {
  String _balanceDistributionPeriod = 'All Time';
  String _spendingTrendPeriod = 'Weekly';
  final ScrollController _scrollController = ScrollController();

  final List<String> _periods = [
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
    'All Time',
  ];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _arePhonesEqual(String? p1, String? p2) {
    if (p1 == null || p2 == null) return false;
    final n1 = p1.replaceAll(RegExp(r'\D'), '');
    final n2 = p2.replaceAll(RegExp(r'\D'), '');
    if (n1.isEmpty || n2.isEmpty) return false;
    if (n1 == n2) return true;
    final minLen = n1.length < n2.length ? n1.length : n2.length;
    if (minLen >= 7) {
      return n1.substring(n1.length - minLen) == n2.substring(n2.length - minLen);
    }
    return false;
  }

  void _scrollToLastTransaction() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_scrollController.hasClients) return;

      var filteredTransactions = _getFilteredTransactions(_spendingTrendPeriod);
      Map<String, double> periodData = {};
      DateTime now = DateTime.now();

      // Similar logic to GraphScreen but checking isSent (Expense equivalent)
      // We will track "Money Sent" (Red/Expense) in the bar chart typically?
      // Or maybe net flow? Let's stick to "Money Sent" (Money Out) as the 'spending' trend.

      if (_spendingTrendPeriod == 'Daily') {
        for (int hour = 0; hour < 24; hour++) {
          String hourKey = '${hour.toString().padLeft(2, '0')}:00';
          periodData[hourKey] = 0;
        }
        for (var t in filteredTransactions.where(
          (t) => _arePhonesEqual(t.senderPhone, widget.currentUserContact),
        )) {
          if (t.dateTime.day == now.day) {
            String hourKey = '${t.dateTime.hour.toString().padLeft(2, '0')}:00';
            if (periodData.containsKey(hourKey)) {
              periodData[hourKey] = periodData[hourKey]! + t.amount;
            }
          }
        }
      } else if (_spendingTrendPeriod == 'Weekly') {
        for (int i = 6; i >= 0; i--) {
          DateTime date = now.subtract(Duration(days: i));
          String dateKey = DateFormat('EEE').format(date);
          periodData[dateKey] = 0;
        }
        for (var t in filteredTransactions.where(
          (t) => _arePhonesEqual(t.senderPhone, widget.currentUserContact),
        )) {
          String dayKey = DateFormat('EEE').format(t.dateTime);
          if (periodData.containsKey(dayKey)) {
            periodData[dayKey] = periodData[dayKey]! + t.amount;
          }
        }
      } else if (_spendingTrendPeriod == 'Yearly') {
        for (int month = 1; month <= 12; month++) {
          DateTime monthDate = DateTime(now.year, month, 1);
          String monthKey = DateFormat('MMM').format(monthDate);
          periodData[monthKey] = 0;
        }
        for (var t in filteredTransactions.where(
          (t) => _arePhonesEqual(t.senderPhone, widget.currentUserContact),
        )) {
          if (t.dateTime.year == now.year) {
            String monthKey = DateFormat('MMM').format(t.dateTime);
            if (periodData.containsKey(monthKey)) {
              periodData[monthKey] = periodData[monthKey]! + t.amount;
            }
          }
        }
      } else if (_spendingTrendPeriod == 'All Time') {
        for (var t in filteredTransactions.where(
          (t) => _arePhonesEqual(t.senderPhone, widget.currentUserContact),
        )) {
          String monthKey = DateFormat('MMM yy').format(t.dateTime);
          periodData[monthKey] = (periodData[monthKey] ?? 0) + t.amount;
        }
      }

      if (periodData.isEmpty) return;

      var entries = periodData.entries.toList();
      int lastNonZeroIndex = -1;
      for (int i = entries.length - 1; i >= 0; i--) {
        if (entries[i].value > 0) {
          lastNonZeroIndex = i;
          break;
        }
      }

      if (lastNonZeroIndex >= 0) {
        double barWidth = 44.0;
        double scrollPosition =
            (lastNonZeroIndex - 2).clamp(0, entries.length - 1).toDouble() *
            barWidth;
        double maxScroll = _scrollController.position.maxScrollExtent;
        double targetScroll = scrollPosition.clamp(0, maxScroll);

        _scrollController.animateTo(
          targetScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<LedgerTransaction> _getFilteredTransactions(String period) {
    DateTime now = DateTime.now();
    switch (period) {
      case 'Daily':
        return widget.transactions
            .where(
              (t) =>
                  t.dateTime.year == now.year &&
                  t.dateTime.month == now.month &&
                  t.dateTime.day == now.day,
            )
            .toList();
      case 'Weekly':
        DateTime weekAgo = now.subtract(const Duration(days: 7));
        return widget.transactions
            .where((t) => t.dateTime.isAfter(weekAgo))
            .toList();
      case 'Monthly':
        return widget.transactions
            .where(
              (t) =>
                  t.dateTime.year == now.year && t.dateTime.month == now.month,
            )
            .toList();
      case 'Yearly':
        return widget.transactions
            .where((t) => t.dateTime.year == now.year)
            .toList();
      case 'All Time':
      default:
        return widget.transactions;
    }
  }

  double _getTotalReceived(List<LedgerTransaction> transactions) {
    return transactions
        .where(
          (t) => !_arePhonesEqual(t.senderPhone, widget.currentUserContact),
        )
        .fold(0, (sum, t) => sum + t.amount);
  }

  double _getTotalSent(List<LedgerTransaction> transactions) {
    return transactions
        .where((t) => _arePhonesEqual(t.senderPhone, widget.currentUserContact))
        .fold(0, (sum, t) => sum + t.amount);
  }

  @override
  Widget build(BuildContext context) {
    double totalReceived = _getTotalReceived(widget.transactions);
    double totalSent = _getTotalSent(widget.transactions);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ledger Statistics',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 24),
              _buildIncomeExpenseChart(
                totalReceived,
                totalSent,
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),
              const SizedBox(height: 20),
              _buildPieChart(
                context,
              ).animate().fadeIn(delay: 50.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 20),
              _buildStatisticsCards(
                totalReceived,
                totalSent,
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 20),
              // "Spending Trend" is confusing for Ledger (Sent Trend?), but we can keep the label or rename it
              _buildSpendingTrend()
                  .animate()
                  .fadeIn(delay: 150.ms)
                  .slideY(begin: 0.1, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseChart(double received, double sent) {
    double total = received + sent;
    double receivedPercent = total > 0 ? (received / total) * 100 : 0;
    double sentPercent = total > 0 ? (sent / total) * 100 : 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Received vs Sent',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${receivedPercent.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Received',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.currencySymbol}${NumberFormat('#,##0').format(received)}',
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
                      '${sentPercent.toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sent',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.currencySymbol}${NumberFormat('#,##0').format(sent)}',
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
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                if (receivedPercent > 0)
                  Expanded(
                    flex: receivedPercent.toInt(),
                    child: Container(
                      height: 12,
                      color: const Color(0xFF51CF66),
                    ),
                  ),
                if (sentPercent > 0)
                  Expanded(
                    flex: sentPercent.toInt(),
                    child: Container(
                      height: 12,
                      color: const Color(0xFFFF6B6B),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(BuildContext context) {
    var filteredTransactions = _getFilteredTransactions(
      _balanceDistributionPeriod,
    );
    double received = _getTotalReceived(filteredTransactions);
    double sent = _getTotalSent(filteredTransactions);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distribution',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              _buildPeriodChips(_balanceDistributionPeriod, (period) {
                setState(() => _balanceDistributionPeriod = period);
              }),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(
                painter: LedgerPieChartPainter(
                  received: received,
                  sent: sent,
                  emptyColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem('Received', const Color(0xFF51CF66), received),
              _buildLegendItem('Sent', const Color(0xFFFF6B6B), sent),
            ],
          ),
        ],
      ),
    );
  }

  // Helper widgets...
  Widget _buildPeriodChips(
    String currentPeriod,
    Function(String) onPeriodChanged,
  ) {
    final labels = {
      'Daily': 'D',
      'Weekly': 'W',
      'Monthly': 'M',
      'Yearly': 'Y',
      'All Time': 'All',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _periods.map((period) {
        bool isSelected = period == currentPeriod;
        return GestureDetector(
          onTap: () => onPeriodChanged(period),
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              labels[period]!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegendItem(String label, Color color, double amount) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${widget.currencySymbol}${NumberFormat('#,##0').format(amount)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatisticsCards(double totalReceived, double totalSent) {
    int count = widget.transactions.length;
    double net = totalReceived - totalSent;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Transactions',
                count.toString(),
                Icons.receipt_long,
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Net Balance',
                '${widget.currencySymbol}${NumberFormat('#,##0').format(net)}',
                Icons.account_balance_wallet,
                net >= 0 ? const Color(0xFF51CF66) : const Color(0xFFFF6B6B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingTrend() {
    var filteredTransactions = _getFilteredTransactions(_spendingTrendPeriod);
    Map<String, double> periodData = {};
    DateTime now = DateTime.now();

    // Logic for "Money Out" trend (Sent)
    if (_spendingTrendPeriod == 'Daily') {
      for (int hour = 0; hour < 24; hour++) {
        periodData['${hour.toString().padLeft(2, '0')}:00'] = 0;
      }
      for (var t in filteredTransactions.where(
        (t) => _arePhonesEqual(t.senderPhone, widget.currentUserContact),
      )) {
        if (t.dateTime.day == now.day) {
          String key = '${t.dateTime.hour.toString().padLeft(2, '0')}:00';
          if (periodData.containsKey(key)) {
            periodData[key] = periodData[key]! + t.amount;
          }
        }
      }
    } else if (_spendingTrendPeriod == 'Weekly') {
      for (int i = 6; i >= 0; i--) {
        periodData[DateFormat('EEE').format(now.subtract(Duration(days: i)))] =
            0;
      }
      // The instruction provided a snippet that seems to belong to a different context
      // (e.g., a _processData method calculating totalLent/totalBorrowed with otherUserContact).
      // Applying it directly here would introduce undefined variables and syntax errors.
      // Assuming the intent was to update the filtering logic for 'Weekly' to use senderPhone/receiverPhone
      // similar to the 'Yearly' and 'All Time' blocks, but for the 'Sent Trend' context.
      // The original 'Weekly' block already filters by senderEmail.
      // If the goal was to change the filtering criteria, please provide a more specific instruction.
      // For now, I'm keeping the original logic as the provided snippet is not directly applicable here.
      for (var t in filteredTransactions.where(
        (t) => _arePhonesEqual(t.senderPhone, widget.currentUserContact),
      )) {
        String key = DateFormat('EEE').format(t.dateTime);
        if (periodData.containsKey(key)) {
          periodData[key] = periodData[key]! + t.amount;
        }
      }
    } else if (_spendingTrendPeriod == 'Yearly') {
      for (int month = 1; month <= 12; month++) {
        periodData[DateFormat('MMM').format(DateTime(now.year, month, 1))] = 0;
      }
      for (var t in filteredTransactions.where(
        (t) => _arePhonesEqual(t.senderPhone, widget.currentUserContact),
      )) {
        if (t.dateTime.year == now.year) {
          String key = DateFormat('MMM').format(t.dateTime);
          if (periodData.containsKey(key)) {
            periodData[key] = periodData[key]! + t.amount;
          }
        }
      }
    } else if (_spendingTrendPeriod == 'All Time') {
      for (var t in filteredTransactions.where(
        (t) => _arePhonesEqual(t.senderPhone, widget.currentUserContact),
      )) {
        String key = DateFormat('MMM yy').format(t.dateTime);
        periodData[key] = (periodData[key] ?? 0) + t.amount;
      }
    }

    double maxAmount = periodData.values.isEmpty
        ? 1
        : (periodData.values.reduce(math.max) == 0
              ? 1
              : periodData.values.reduce(math.max));
    bool isScrollable = [
      'Daily',
      'Weekly',
      'Yearly',
      'All Time',
    ].contains(_spendingTrendPeriod);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
                'Sent Trend',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              _buildPeriodChips(_spendingTrendPeriod, (p) {
                setState(() => _spendingTrendPeriod = p);
                if (['Daily', 'Weekly', 'Yearly', 'All Time'].contains(p)) {
                  _scrollToLastTransaction();
                }
              }),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: periodData.isEmpty
                ? Center(
                    child: Text(
                      'No data',
                      style: GoogleFonts.inter(color: Colors.grey.shade500),
                    ),
                  )
                : isScrollable
                ? SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: periodData.entries
                          .map((e) => _buildBarChart(e, maxAmount))
                          .toList(),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: periodData.entries
                        .map((e) => _buildBarChart(e, maxAmount))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(MapEntry<String, double> entry, double maxAmount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: (entry.value / maxAmount) * 120,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class LedgerPieChartPainter extends CustomPainter {
  final double received;
  final double sent;
  final Color emptyColor;

  LedgerPieChartPainter({
    required this.received,
    required this.sent,
    required this.emptyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = 20.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double total = received + sent;
    if (total == 0) {
      paint.color = emptyColor;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    double startAngle = -math.pi / 2;

    // Draw Received Arc
    if (received > 0) {
      final sweepAngle = (received / total) * 2 * math.pi;
      paint.color = const Color(0xFF51CF66);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }

    // Draw Sent Arc
    if (sent > 0) {
      final sweepAngle = (sent / total) * 2 * math.pi;
      paint.color = const Color(0xFFFF6B6B);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(LedgerPieChartPainter oldDelegate) {
    return oldDelegate.received != received || oldDelegate.sent != sent;
  }
}
