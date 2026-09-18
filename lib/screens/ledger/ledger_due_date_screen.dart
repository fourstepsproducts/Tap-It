import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/ledger_transaction.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/empty_state.dart';

class LedgerDueDateScreen extends StatefulWidget {
  const LedgerDueDateScreen({super.key});

  @override
  State<LedgerDueDateScreen> createState() => _LedgerDueDateScreenState();
}

class _LedgerDueDateScreenState extends State<LedgerDueDateScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ledgerProvider = context.watch<LedgerProvider>();
    final userProvider = context.watch<UserProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final transactions = ledgerProvider.ledgerTransactions;
    final currentUserContact = userProvider.user?.phone ?? '';

    // Calculate Overdue Details
    final overdueList = _calculateOverduePeople(
      transactions,
      currentUserContact,
    );

    // Filter by search
    final filteredList = _searchQuery.isEmpty
        ? overdueList
        : overdueList
              .where(
                (item) => item['name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();

    // Split into Collections and Payables
    final toCollect = filteredList
        .where((item) => (item['amount'] as double) > 0)
        .toList();
    final toPay = filteredList
        .where((item) => (item['amount'] as double) < 0)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Due Dates',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      // Optional: Add Filter Icon?
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track pending debts',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search people...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        icon: Icon(Icons.search, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredList.isEmpty
                  ? EmptyState(
                      title: _searchQuery.isEmpty
                          ? 'All Caught Up!'
                          : 'No one found',
                      message: _searchQuery.isEmpty
                          ? 'No pending debts found.'
                          : 'Try a different name.',
                      icon: Icons.check_circle_outline,
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        if (toCollect.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'TO COLLECT',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ...toCollect.map(
                            (item) => _buildOverdueItem(
                              context,
                              item,
                              currencySymbol,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        if (toPay.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'TO PAY',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          ...toPay.map(
                            (item) => _buildOverdueItem(
                              context,
                              item,
                              currencySymbol,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueItem(
    BuildContext context,
    Map<String, dynamic> item,
    String currencySymbol,
  ) {
    final name = item['name'];
    final phone = item['phone'];
    final amount = item['amount'] as double;
    final isPayable = amount < 0; // Negative means I owe them
    final absAmount = amount.abs();
    final daysOverdue = item['daysOverdue'] as int;
    final overdueSince = item['since'] as DateTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isPayable
                  ? const Color(0xFFFFEBEE)
                  : const Color(0xFFE5F5E9), // Red vs Green bg
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isPayable
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF51CF66),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.orange.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$daysOverdue days ${isPayable ? "outstanding" : "overdue"}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.orange.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Since ${DateFormat('MMM dd, yyyy').format(overdueSince)}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currencySymbol${NumberFormat('#,##0').format(absAmount)}',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isPayable
                      ? const Color(0xFFFF6B6B)
                      : const Color(0xFF51CF66),
                ),
              ),
              const SizedBox(height: 8),
              if (isPayable)
                InkWell(
                  onTap: () =>
                      _showSettleDialog(context, name, phone, absAmount),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Settle',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (phone != null &&
                  phone.isNotEmpty &&
                  !phone.toString().startsWith('local:'))
                InkWell(
                  onTap: () => _launchWhatsAppReminder(
                    context,
                    name,
                    phone,
                    absAmount,
                    currencySymbol,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.send, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Remind',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Logic Helpers
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

  List<Map<String, dynamic>> _calculateOverduePeople(
    List<LedgerTransaction> transactions,
    String currentUserContact,
  ) {
    // 1. Group by Person
    Map<String, List<LedgerTransaction>> personTransactions = {};
    Map<String, String> personNames = {}; // Phone -> Name
    Map<String, String> personPhones =
        {}; // Name -> Phone (Reverse lookup for safety)

    for (var t in transactions) {
      final isSent = _arePhonesEqual(t.senderPhone, currentUserContact);
      final otherPhone = isSent ? t.receiverPhone : t.senderPhone;
      final otherName = isSent ? t.receiverName : t.senderName;

      // Use Phone as key if available, else Name
      String key = otherName.trim();
      if (otherPhone != null &&
          otherPhone.isNotEmpty &&
          !otherPhone.startsWith('local:')) {
        key = otherPhone;
      }

      if (!personTransactions.containsKey(key)) {
        personTransactions[key] = [];
        personNames[key] = otherName;
        if (otherPhone != null) personPhones[key] = otherPhone;
      }
      personTransactions[key]!.add(t);
    }

    List<Map<String, dynamic>> results = [];

    // 2. Analyze each person
    personTransactions.forEach((key, txList) {
      // Sort oldest to newest
      txList.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      double netBalance = 0;
      DateTime? overdueStartDate;

      // Replay history to find when they went into debt (or I went into debt)
      for (var t in txList) {
        final isSent = _arePhonesEqual(t.senderPhone, currentUserContact);

        // Update balance (Positive = They owe me, Negative = I owe them)
        if (isSent) {
          netBalance += t.amount;
        } else {
          netBalance -= t.amount;
        }

        // Check debt status
        if (netBalance > 0) {
          // They owe me.
          if (overdueStartDate == null || netBalance <= 0) {
            overdueStartDate = t.dateTime; // Start of debt
          }
        } else if (netBalance < 0) {
          // I owe them.
          if (overdueStartDate == null || netBalance >= 0) {
            overdueStartDate = t.dateTime; // Start of debt
          }
        } else {
          // Balanced
          overdueStartDate = null;
        }
      }

      // 3. If final balance is NOT zero, add to list
      if (netBalance != 0 && overdueStartDate != null) {
        final daysOverdue = DateTime.now().difference(overdueStartDate).inDays;

        results.add({
          'name': personNames[key] ?? 'Unknown',
          'phone': personPhones[key] ?? key,
          'amount': netBalance,
          'daysOverdue': daysOverdue,
          'since': overdueStartDate,
        });
      }
    });

    // Sort by days overdue (descending)
    results.sort(
      (a, b) => (b['daysOverdue'] as int).compareTo(a['daysOverdue'] as int),
    );

    return results;
  }

  void _showSettleDialog(
    BuildContext context,
    String name,
    String phone,
    double fullAmount,
  ) {
    // Settle = I am paying them back.
    // In Ledger terms, I "Lend" (Give) money to cancel out the "Received" (Debt).
    // isReceived: false

    final amountController = TextEditingController(text: fullAmount.toString());
    final descController = TextEditingController(text: 'Settling Debt');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Settle Debt',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Paying back $name',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText:
                      '${context.read<CurrencyProvider>().currencySymbol} ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final amount =
                        double.tryParse(amountController.text) ?? 0.0;
                    if (amount > 0) {
                      final userProvider = context.read<UserProvider>();
                      final currentUser = userProvider.user;

                      // Add Transaction: Lend (isReceived: false) to reduce negative balance
                      context.read<LedgerProvider>().addLedgerTransaction(
                        name,
                        phone.isEmpty ? null : phone,
                        amount,
                        descController.text,
                        isReceived:
                            false, // Paying back = Giving money = Lending logic
                        currentUserId: currentUser?.userId ?? '',
                        currentUserName: currentUser?.name ?? '',
                        currentUserPhone: currentUser?.phone ?? '',
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Payment recorded for $name')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFFF6B6B), // Red for paying
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchWhatsAppReminder(
    BuildContext context,
    String name,
    String phone,
    double amount,
    String currencySymbol,
  ) async {
    final formattedAmount = '$currencySymbol${amount.toStringAsFixed(2)}';
    final message =
        "Hello $name, just a gentle reminder about the pending amount of $formattedAmount. Please settle it when possible. Thanks!";
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open WhatsApp'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
