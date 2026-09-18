import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/ledger_transaction.dart';
import '../../services/appwrite_service.dart';
typedef OnAddTransactionCallback =
    Future<String?> Function(
      String name,
      String? phone,
      double amount,
      String description, {
      bool isReceived,
      String? currentUserPhone,
      String? currentUserEmail,
    });

class PersonLedgerScreen extends StatefulWidget {
  final String personName;
  final String personPhone;
  final double currentBalance;
  final List<LedgerTransaction> transactions;
  final String currencySymbol;
  final OnAddTransactionCallback onAddTransaction;
  final Function() onRemind;
  final List<String> myIdentities;
  final String currentUserId;
  final bool isNotesMode;

  const PersonLedgerScreen({
    super.key,
    required this.personName,
    required this.personPhone,
    required this.currentBalance,
    required this.transactions,
    required this.currencySymbol,
    required this.onAddTransaction,
    required this.onRemind,
    required this.myIdentities,
    required this.currentUserId,
    this.isNotesMode = false,
  });

  @override
  State<PersonLedgerScreen> createState() => _PersonLedgerScreenState();
}

class _PersonLedgerScreenState extends State<PersonLedgerScreen> {
  final ScrollController _scrollController =
      ScrollController(); // Added ScrollController
  // Scroll logic replaced by reverse:true ListView

  late List<LedgerTransaction> _localTransactions;
  late double _currentBalance;

  @override
  void initState() {
    super.initState();
    _localTransactions = List.from(widget.transactions);
    _currentBalance = widget.currentBalance;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PersonLedgerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  // Updated to support email comparison
  bool _arePhonesEqual(String? p1, String? p2) {
    if (p1 == null || p2 == null) return false;
    // Email check
    if (p1.contains('@') || p2.contains('@')) {
      return p1.trim().toLowerCase() == p2.trim().toLowerCase();
    }
    // Phone check
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

  // Helpers to fetch latest data directly from provider
  List<LedgerTransaction> _getLiveTransactions(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    return provider.getTransactionsForPerson(
      widget.personName,
      widget.personPhone,
      widget.currentUserId,
      widget.myIdentities,
    );
  }

  double _calculateLiveBalance(List<LedgerTransaction> transactions) {
    double balance = 0;
    for (var t in transactions) {
      final isSentByMe =
          (widget.currentUserId.isNotEmpty &&
              t.senderId == widget.currentUserId) ||
          widget.myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id)) ||
          (t.senderName.toLowerCase() == 'me' ||
              t.senderName == 'Self' ||
              t.senderName ==
                  widget.myIdentities.firstOrNull); // Approximate check

      // If I sent it, I am owed (+) or I gave (-)?
      // Logic in Dashboard:
      // balances[key] = (balances[key] ?? 0) + (isSent ? t.amount : -t.amount);
      // Wait, if I sent money (Lending), balance should be POSITIVE (Assuming balance means "They Owe Me")
      // If I received money (Borrowing), balance should be NEGATIVE ("I Owe Them")

      if (isSentByMe) {
        // I sent money. They owe me.
        balance += t.amount;
      } else {
        // I received money. I owe them.
        balance -= t.amount;
      }
    }
    return balance;
  }

  void _showSettleDialog() {
    final amountController = TextEditingController(
      text: _currentBalance.abs().toString(),
    );
    final descController = TextEditingController(text: 'Settlement');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(context).cardColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settle Up',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${widget.currencySymbol} ',
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
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (amountController.text.isNotEmpty) {
                      final amount =
                          double.tryParse(amountController.text) ?? 0.0;
                      final isReceived = _currentBalance > 0;
                      final description = descController.text;
                      Navigator.pop(context);

                      // OPTIMISTIC UPDATE - Show immediately!
                      // final tempId =
                      //    'temp_${DateTime.now().millisecondsSinceEpoch}';

                      // To prevent flicker at top, ensure this is the NEWEST timestamp in the list
                      DateTime now = DateTime.now();
                      final currentTransactions = context
                          .read<LedgerProvider>()
                          .getTransactionsForPerson(
                            widget.personName,
                            widget.personPhone,
                            widget.currentUserId,
                            widget.myIdentities,
                          );
                      if (currentTransactions.isNotEmpty) {
                        final latestDate = currentTransactions
                            .map((tx) => tx.dateTime)
                            .reduce((a, b) => a.isAfter(b) ? a : b);
                        if (now.isBefore(latestDate) ||
                            now.isAtSameMomentAs(latestDate)) {
                          now = latestDate.add(const Duration(milliseconds: 1));
                        }
                      }

                      // Notification to provider handled via callback below, which triggers optimistic update in Provider.
                      // No need for local setState here as we are watching the provider.

                      // NETWORK CALL - Run in background
                      final userProvider = context.read<UserProvider>();
                      final error = await widget.onAddTransaction(
                        widget.personName,
                        widget.personPhone,
                        amount,
                        description,
                        isReceived: isReceived,
                        currentUserPhone: userProvider.user?.phone,
                        currentUserEmail: userProvider.user?.email,
                      );

                      if (error != null) {
                        if (mounted) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Settlement Failed'),
                              content: Text(error),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Settle Up'),
                ),
              ),
            ],
          ),
        ),
      ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
    );
  }

  Future<void> _handleNudge() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Payment Reminder',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                if (_validatePhone()) {
                  _showNudgeOptionsDialog();
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                'In-App Nudge',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Notify now or schedule for later',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                if (_validatePhone()) {
                  _launchWhatsApp();
                }
              },
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat, color: Color(0xFF25D366)),
              ),
              title: Text(
                'WhatsApp',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Send a pre-filled message',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  bool _validatePhone() {
    if (widget.personPhone.isEmpty || widget.personPhone.startsWith('local:')) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Phone Number Required'),
          content: Text(
            'To send a nudge or reminder, please add a phone number for ${widget.personName}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditPersonDialog();
              },
              child: const Text('Add Number'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _sendInAppNudge() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking user availability...'),
          duration: Duration(seconds: 1),
        ),
      );

      final user = await AppwriteService().getUserByPhone(widget.personPhone);

      if (user != null) {
        await AppwriteService().sendNotification(
          userId: user['userId'],
          title: 'Payment Nudge',
          message: 'Friendly reminder to settle up!',
          type: 'nudge',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Nudge sent successfully!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('User Not Found'),
              content: Text(
                '${widget.personName} is not on Tap It yet. Would you like to send a WhatsApp reminder instead?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    _launchWhatsApp();
                  },
                  child: const Text('Open WhatsApp'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showNudgeOptionsDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When to Nudge?',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              onTap: () async {
                Navigator.pop(context);
                await _sendInAppNudge();
              },
              leading: const Icon(Icons.send),
              title: const Text('Now'),
              subtitle: const Text('Send notification immediately'),
            ),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _showScheduleDialog();
              },
              leading: const Icon(Icons.calendar_month),
              title: const Text('Schedule'),
              subtitle: const Text('Pick dates to remind them later'),
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleDialog() {
    List<DateTime> selectedDates = [];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Dates'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CalendarDatePicker(
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onDateChanged: (date) {
                        setState(() {
                          final normalized = DateTime(date.year, date.month, date.day);
                          if (selectedDates.contains(normalized)) {
                            selectedDates.remove(normalized);
                          } else {
                            selectedDates.add(normalized);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedDates.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: selectedDates.map((d) => Chip(
                          label: Text('${d.day}/${d.month}/${d.year}'),
                          onDeleted: () {
                            setState(() {
                              selectedDates.remove(d);
                            });
                          },
                        )).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (selectedDates.isNotEmpty) {
                      _scheduleNudges(selectedDates);
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _scheduleNudges(List<DateTime> dates) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scheduling nudges...'),
          duration: Duration(seconds: 1),
        ),
      );

      final user = await AppwriteService().getUserByPhone(widget.personPhone);

      if (user != null) {
        for (var date in dates) {
          final scheduledTime = DateTime(date.year, date.month, date.day, 10, 0); // 10 AM default
          await AppwriteService().sendNotification(
            userId: user['userId'],
            title: 'Payment Nudge',
            message: 'Friendly reminder to settle up!',
            type: 'nudge',
            scheduledDate: scheduledTime.toIso8601String(),
          );
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully scheduled ${dates.length} nudges!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('User Not Found'),
              content: Text(
                '${widget.personName} is not on Tap It yet. Cannot schedule in-app nudges.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule nudges: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  double get _liveBalance =>
      _calculateLiveBalance(_getLiveTransactions(context));

  Future<void> _launchWhatsApp() async {
    final balance = _liveBalance;
    final phone = widget.personPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final amount = NumberFormat('#,##0').format(balance.abs());

    String message = '';
    if (balance > 0) {
      message =
          'Hi ${widget.personName}, just a friendly reminder that you owe me ${widget.currencySymbol}$amount on Tap It. Thanks!';
    } else {
      message =
          'Hi ${widget.personName}, I owe you ${widget.currencySymbol}$amount on Tap It. Letting you know!';
    }

    final encodedMessage = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$phone?text=$encodedMessage');

    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live Data from Provider
    final liveTransactions = _getLiveTransactions(context);
    final liveBalance = _calculateLiveBalance(liveTransactions);

    // Sort: Newest First (for reverse: true ListView)
    // We utilize stable sort with ID as tie-breaker to prevent UI jitter
    final sortedTransactions = List<LedgerTransaction>.from(liveTransactions)
      ..sort((a, b) {
        int res = b.dateTime.compareTo(a.dateTime);
        if (res == 0) {
          return b.id.compareTo(a.id); // Tie-breaker
        }
        return res;
      });

    final isOwesYou = liveBalance > 0;
    final isYouOwe = liveBalance < 0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.personName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            if (widget.personPhone.isNotEmpty &&
                !widget.personPhone.startsWith('local:'))
              Text(
                widget.personPhone,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          // Refresh Button Removed
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            onPressed: () {
              // Ensure scroll on return? Logic removed as reverse:true handles it
              _showSettleDialog();
            },
            tooltip: 'Settle Up',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: _handleNudge,
            tooltip: 'Nudge / Remind',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _showEditPersonDialog();
              } else if (value == 'delete') {
                _confirmDeletePerson();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20, color: Colors.blue),
                      SizedBox(width: 12),
                      Text('Edit Person'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.orange),
                      SizedBox(width: 12),
                      Text(
                        'Remove from View',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner for Net Balance
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Balance',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  isOwesYou
                      ? 'Owes You ${widget.currencySymbol}${NumberFormat('#,##0').format(liveBalance.abs())}'
                      : (isYouOwe
                            ? 'You Owe ${widget.currencySymbol}${NumberFormat('#,##0').format(liveBalance.abs())}'
                            : 'Settled'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: isOwesYou
                        ? const Color(0xFF51CF66)
                        : (isYouOwe ? const Color(0xFFFF6B6B) : Colors.grey),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await context.read<LedgerProvider>().fetchLedgerTransactions();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Refreshed'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
              child: ListView.builder(
                controller: _scrollController,
                reverse: true, // Chat Style (Bottom-Up)
                physics:
                    const AlwaysScrollableScrollPhysics(), // Allow refresh even if empty
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  80,
                ), // Extra bottom padding for fab/buttons
                itemCount: sortedTransactions.length,
                itemBuilder: (context, index) {
                  final t = sortedTransactions[index];
                  // Check against ANY identity
                  // Improved logic: Match by ID first, then phone/email, then name fallback
                  final isSentByMe =
                      (widget.currentUserId.isNotEmpty &&
                          t.senderId == widget.currentUserId) ||
                      widget.myIdentities.any(
                        (id) => _arePhonesEqual(t.senderPhone, id),
                      ) ||
                      (t.senderName.toLowerCase() == 'me' ||
                          t.senderName == 'Self' ||
                          t.senderName ==
                              context.read<UserProvider>().user?.name);

                  // Improved logic: Use creatorId if available, else fallback
                  bool isMyRequest;
                  if (t.creatorId.isNotEmpty) {
                    isMyRequest = t.creatorId == widget.currentUserId;
                  } else {
                    // Legacy Fallback
                    isMyRequest = isSentByMe;
                  }

                  // Check if it's a settlement
                  final isSettlement = t.description.toLowerCase().contains(
                    'settl',
                  );

                  if (isSettlement) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: t.status == 'pending'
                                      ? Colors.orange
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  t.status == 'pending'
                                      ? 'Settlement Pending'
                                      : 'Settlement Done',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: t.status == 'pending'
                                        ? Colors.orange.shade800
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.currencySymbol}${NumberFormat('#,##0').format(t.amount.abs())} • ${DateFormat('MMM d, h:mm a').format(t.dateTime)}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            if (t.status == 'pending' && !isMyRequest) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      context
                                          .read<LedgerProvider>()
                                          .rejectLedgerTransaction(t.id);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        'Reject',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  InkWell(
                                    onTap: () {
                                      context
                                          .read<LedgerProvider>()
                                          .acceptLedgerTransaction(t);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Accept',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms);
                  }

                  // PENDING REQUEST UI
                  if (t.status == 'pending') {
                    if (isMyRequest) {
                      // Sent Request (Waiting)
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Request Sent',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.currencySymbol}${NumberFormat('#,##0').format(t.amount.abs())}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (t.description.isNotEmpty)
                                Text(
                                  t.description,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  context
                                      .read<LedgerProvider>()
                                      .deleteLedgerTransaction(t.id);
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Cancel Request'),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      // Received Request (Action Needed)
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Confirmation Needed',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.personName} claims you owe', // Contextual?
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${widget.currencySymbol}${NumberFormat('#,##0').format(t.amount.abs())}',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (t.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  t.description,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        context
                                            .read<LedgerProvider>()
                                            .rejectLedgerTransaction(t.id);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        context
                                            .read<LedgerProvider>()
                                            .acceptLedgerTransaction(t);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  }

                  // STANDARD CONFIRMED TRANSACTION
                  return Align(
                    alignment: isSentByMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSentByMe
                            ? const Color(0xFFFF6B6B).withOpacity(0.1)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isSentByMe ? 16 : 4),
                          bottomRight: Radius.circular(isSentByMe ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSentByMe ? 'You Gave' : 'You Got',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSentByMe
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFF51CF66),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${isSentByMe ? '-' : '+'}${widget.currencySymbol}${NumberFormat('#,##0').format(t.amount.abs())}',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isSentByMe
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFF51CF66),
                            ),
                          ),
                          if (t.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              t.description,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('MMM d, h:mm a').format(t.dateTime),
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              // Removed the old 'pending' logic from here as it's handled above
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
                },
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTransactionButton(
                          label: 'You Gave',
                          color: const Color(0xFFFF6B6B),
                          isReceived: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTransactionButton(
                          label: 'You Got',
                          color: const Color(0xFF51CF66),
                          isReceived: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionButton({
    required String label,
    required Color color,
    required bool isReceived,
  }) {
    return ElevatedButton(
      onPressed: () => _showTransactionDialog(isReceived: isReceived),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
      ),
      child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
    );
  }

  void _showTransactionDialog({required bool isReceived}) {
    final amountController = TextEditingController();
    final descController = TextEditingController();

    bool currentIsReceived = isReceived;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isGave = !currentIsReceived;
          final primaryColor = currentIsReceived
              ? const Color(0xFF51CF66)
              : const Color(0xFFFF6B6B);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).cardColor,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Transaction',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Toggle Switch (Gave / Got)
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setDialogState(() => currentIsReceived = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isGave
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'You Gave',
                                  style: GoogleFonts.inter(
                                    color: isGave ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setDialogState(() => currentIsReceived = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: currentIsReceived
                                    ? const Color(0xFF51CF66)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'You Got',
                                  style: GoogleFonts.inter(
                                    color: currentIsReceived
                                        ? Colors.white
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '${widget.currencySymbol} ',
                      prefixStyle: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryColor, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (amountController.text.isNotEmpty) {
                          final amount =
                              double.tryParse(amountController.text) ?? 0.0;
                          final description = descController.text;
                          final isReceived = currentIsReceived;

                          Navigator.pop(context);

                          // OPTIMISTIC UPDATE - Show immediately!
                          final tempId =
                              'temp_${DateTime.now().millisecondsSinceEpoch}';

                          // To prevent flicker at top, ensure this is the NEWEST timestamp in the list
                          DateTime now = DateTime.now();
                          if (_localTransactions.isNotEmpty) {
                            final latestDate = _localTransactions
                                .map((tx) => tx.dateTime)
                                .reduce((a, b) => a.isAfter(b) ? a : b);
                            if (now.isBefore(latestDate) ||
                                now.isAtSameMomentAs(latestDate)) {
                              now = latestDate.add(
                                const Duration(milliseconds: 1),
                              );
                            }
                          }

                          final optimisticTx = LedgerTransaction(
                            id: tempId,
                            senderId: isReceived ? '' : widget.currentUserId,
                            senderName: isReceived ? widget.personName : 'Me',
                            senderPhone: isReceived
                                ? widget.personPhone
                                : (widget.myIdentities.isNotEmpty
                                      ? widget.myIdentities.first
                                      : ''),
                            receiverName: isReceived ? 'Me' : widget.personName,
                            receiverPhone: isReceived
                                ? (widget.myIdentities.isNotEmpty
                                      ? widget.myIdentities.first
                                      : '')
                                : widget.personPhone,
                            receiverId: isReceived ? widget.currentUserId : '',
                            amount: amount,
                            description: description,
                            dateTime: now,
                            status: widget.isNotesMode ? 'notes' : 'pending',
                          );

                          setState(() {
                            if (isReceived) {
                              _currentBalance -= amount;
                            } else {
                              _currentBalance += amount;
                            }
                            _localTransactions.add(optimisticTx);
                          });

                          // NETWORK CALL - Run in background
                          final userProvider = context.read<UserProvider>();
                          final error = await widget.onAddTransaction(
                            widget.personName,
                            widget.personPhone,
                            amount,
                            description,
                            isReceived: isReceived,
                            currentUserPhone: userProvider.user?.phone,
                            currentUserEmail: userProvider.user?.email,
                          );

                          if (error != null && mounted) {
                            // ROLLBACK on failure
                            setState(() {
                              if (isReceived) {
                                _currentBalance += amount;
                              } else {
                                _currentBalance -= amount;
                              }
                              _localTransactions.removeWhere(
                                (t) => t.id == tempId,
                              );
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(error)));
                          }
                        }
                      },
                      child: const Text(
                        'Save Record',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditPersonDialog() {
    final nameController = TextEditingController(text: widget.personName);

    String initialPhone = widget.personPhone;
    String selectedCountryCode = '+91';

    if (initialPhone.startsWith('+91')) {
      initialPhone = initialPhone.substring(3);
    } else if (initialPhone.startsWith('local:')) {
      initialPhone = '';
    }

    final phoneController = TextEditingController(text: initialPhone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(context).cardColor,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Person',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: nameController,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Name required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CountryCodePicker(
                        onChanged: (code) {
                          selectedCountryCode = code.dialCode ?? '+91';
                        },
                        initialSelection: 'IN',
                        favorite: const ['+91', 'IN'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        padding: EdgeInsets.zero,
                        flagWidth: 24,
                        textStyle: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        dialogBackgroundColor: Theme.of(context).colorScheme.surface,
                        dialogTextStyle: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                        ),
                        searchStyle: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                        ),
                        searchDecoration: InputDecoration(
                          hintText: 'Search country',
                          hintStyle: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        boxDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          labelText: 'Phone (Optional)',
                          helperText: 'For reminders & nudges',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final newName = nameController.text.trim();
                        final rawPhone = phoneController.text.trim();

                        final newPhone = rawPhone.isEmpty
                            ? ''
                            : '$selectedCountryCode$rawPhone';

                        Navigator.pop(context);

                        if (newName == widget.personName &&
                            newPhone == widget.personPhone) {
                          return;
                        }

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Updating person...')),
                        );

                        final success = await context
                            .read<LedgerProvider>()
                            .updatePerson(
                              oldName: widget.personName,
                              oldPhone: widget.personPhone,
                              newName: newName,
                              newPhone: newPhone,
                            );

                        if (!mounted) return;
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Person updated successfully'),
                            ),
                          );
                          Navigator.pop(dialogContext);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Failed to update person'),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeletePerson() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from Dashboard?'),
        content: Text(
          'This will remove ${widget.personName} from your dashboard. Records will reappear if you add a new transaction for them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removing ${widget.personName}...')),
              );

              final provider = context.read<LedgerProvider>();
              await provider.softDeletePerson(widget.personName);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${widget.personName} removed from dashboard',
                    ),
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
