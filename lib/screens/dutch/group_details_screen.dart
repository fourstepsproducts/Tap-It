import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../providers/dutch_provider.dart';
import 'dutch_history_screen.dart';
import 'dutch_reports_screen.dart';
import '../../widgets/dutch/add_expense_dialog.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  // Placeholder for expense list (will be separate widget/provider call)

  @override
  void initState() {
    super.initState();
    // Fetch expenses for this group
    Future.microtask(
      () => context.read<DutchProvider>().selectGroup(
        widget.group['id'] ?? widget.group['\$id'],
      ),
    );
  }

  void _shareInviteCode() {
    final code = widget.group['inviteCode'] ?? 'NO_CODE';
    final name = widget.group['name'] ?? 'Group';
    Share.share('Join my group "$name" on Tap It using code: $code');
  }

  void _copyCode() {
    final code = widget.group['inviteCode'] ?? 'NO_CODE';
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Invite code copied!')));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DutchProvider>();
    final expenses = provider.currentGroupExpenses;
    final isLoading = provider.isLoading;
    final inviteCode = widget.group['inviteCode'] ?? 'N/A';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(widget.group['name'] ?? 'Group Details')),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 200 &&
              !isLoading &&
              provider.hasMoreGroupExpenses) {
            provider.loadMoreGroupExpenses();
          }
          return true;
        },
        child: RefreshIndicator(
          onRefresh: () async {
            await provider.selectGroup(
              widget.group['id'] ?? widget.group['\$id'],
            );
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Header Card with Invite Code
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Paid',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${provider.getUserShare().toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Code: $inviteCode',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _copyCode,
                                  child: const Icon(
                                    Icons.copy,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _shareInviteCode,
                              icon: const Icon(Icons.share, size: 14),
                              label: const Text('Invite'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepPurple,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const DutchHistoryScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.history, size: 14),
                              label: const Text('History'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const DutchReportsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.analytics_outlined,
                                size: 14,
                              ),
                              label: const Text('Reports'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tabs / Filter (Placeholder)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Expenses',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {},
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Expenses List
                if (isLoading && expenses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(48.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_person,
                          size: 64,
                          color: Colors.red.shade200,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Access Denied or Connection Error',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.error!.contains('user_unauthorized')
                              ? 'You do not have permission to view expenses in this group. Please check Appwrite "Document Security" settings.'
                              : provider.error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => provider.selectGroup(
                            widget.group['id'] ?? widget.group['\$id'],
                          ),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  )
                else if (expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(48.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No expenses yet',
                          style: GoogleFonts.inter(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          final payerId = expense['payerId'];
                          final payerProfile = provider
                              .currentGroupMemberProfiles
                              .firstWhere(
                                (p) => p['userId'] == payerId,
                                orElse: () => {},
                              );
                          final payerName = payerProfile['name'] ?? 'Unknown';

                          return ListTile(
                            onTap: () => _showExpenseDetails(context, expense),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: Text(
                                payerName.isNotEmpty
                                    ? payerName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              expense['description'],
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Paid by $payerName',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${(expense['amount'] as num).toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                if (expense['status'] != 'completed')
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: expense['status'] == 'rejected'
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      (expense['status'] ?? 'pending')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: expense['status'] == 'rejected'
                                            ? Colors.red
                                            : Colors.orange,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                      if (provider.hasMoreGroupExpenses)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Member Balances Section
                if (provider.currentUserId != null &&
                    provider.groupBalances.isNotEmpty)
                  _buildBalancesSection(context, provider),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AddExpenseDialog(
              groupId: widget.group['id'] ?? widget.group['\$id'],
              members: provider.currentGroupMemberProfiles,
              allMemberIds: List<String>.from(widget.group['members'] ?? []),
            ),
          );
        },
        label: const Text('Add Expense'),
        icon: const Icon(Icons.add),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildBalancesSection(BuildContext context, DutchProvider provider) {
    final memberStats = provider.getMemberStats();
    final memberIds = memberStats.keys.toList();

    if (memberIds.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Member List',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                'Balance Details',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: memberIds.length,
              separatorBuilder: (context, index) =>
                  Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
              itemBuilder: (context, index) {
                final userId = memberIds[index];
                final stats = memberStats[userId]!;
                final consumed = stats['consumed'] ?? 0.0;
                final netPaid = stats['netPaid'] ?? 0.0;
                final balance = stats['balance'] ?? 0.0;

                final userProfile = provider.currentGroupMemberProfiles
                    .firstWhere((p) => p['userId'] == userId, orElse: () => {});
                final userName = userProfile['name'] ?? 'Member';

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      // Member List Column
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  (userProfile['photoUrl'] == null ||
                                      userProfile['photoUrl']
                                          .toString()
                                          .isEmpty)
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                              backgroundImage:
                                  (userProfile['photoUrl'] != null &&
                                      userProfile['photoUrl']
                                          .toString()
                                          .isNotEmpty)
                                  ? NetworkImage(userProfile['photoUrl'])
                                  : null,
                              child:
                                  (userProfile['photoUrl'] == null ||
                                      userProfile['photoUrl']
                                          .toString()
                                          .isEmpty)
                                  ? Text(
                                      userName.isNotEmpty
                                          ? userName[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                userName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Balance Details Column
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Paid: ',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  '₹${netPaid.toStringAsFixed(0)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Share: ',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  '₹${consumed.toStringAsFixed(0)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  balance >= 0 ? 'Gets back: ' : 'Owes: ',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '₹${balance.abs().toStringAsFixed(0)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: balance >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Action Column (Settle Up if needed)
                      if (balance > 0.01 && userId != provider.currentUserId)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: GestureDetector(
                            onTap: () => _showSettleUpDialog(
                              context,
                              userId,
                              userName,
                              balance,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.payment,
                                size: 14,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper for safe ID comparison
  String _safeId(dynamic val) {
    if (val == null) return '';
    if (val is String) return val;
    if (val is Map) {
      return val['\$id'] ?? val['id'] ?? '';
    }
    return val.toString();
  }

  void _showExpenseDetails(BuildContext context, Map<String, dynamic> expense) {
    final provider = context.read<DutchProvider>();
    final amount = (expense['amount'] as num).toDouble();
    final payerId = expense['payerId'];
    final payerProfile = provider.currentGroupMemberProfiles.firstWhere(
      (p) => p['userId'] == payerId,
      orElse: () => {},
    );
    final payerName = payerProfile['name'] ?? 'Unknown';
    final splitType = expense['splitType'] ?? 'equal';
    final splitDataRaw = expense['splitData'];
    final currentUserId = provider.currentUserId;

    List<Map<String, dynamic>> beneficiaries = [];

    try {
      if (splitType == 'equal') {
        final List ids = jsonDecode(splitDataRaw);
        final perPerson = amount / ids.length;
        for (var id in ids) {
          final profile = provider.currentGroupMemberProfiles.firstWhere(
            (p) => p['userId'] == id,
            orElse: () => {},
          );
          beneficiaries.add({
            'userId': id,
            'name': profile['name'] ?? id,
            'amount': perPerson,
          });
        }
      } else if (splitType == 'exact') {
        final Map data = jsonDecode(splitDataRaw);
        data.forEach((id, val) {
          final profile = provider.currentGroupMemberProfiles.firstWhere(
            (p) => p['userId'] == id,
            orElse: () => {},
          );
          beneficiaries.add({
            'userId': id,
            'name': profile['name'] ?? id,
            'amount': (val as num).toDouble(),
          });
        });
      }
    } catch (e) {
      // ignore: empty_catches
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Re-fetch provider to get latest settlements inside the builder
            final provider = context.watch<DutchProvider>();
            final settlements = provider.currentGroupSettlements;
            final expenseId = expense['id'];

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          expense['description'],
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paid by: $payerName',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: GoogleFonts.inter(fontSize: 16),
                        ),
                        Text(
                          '₹${amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'SPLIT BREAKDOWN',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...beneficiaries.map((b) {
                    final memberId = b['userId'];
                    final isPayer = memberId == payerId;
                    final memberName = b['name'];
                    final share = b['amount'];

                    final profile = provider.currentGroupMemberProfiles
                        .firstWhere(
                          (p) => p['userId'] == memberId,
                          orElse: () => {},
                        );

                    final memberSettlements = settlements.where((s) {
                      final sPayer = _safeId(s['payerId']);
                      final sReceiver = _safeId(s['receiverId']);
                      final sExpId = _safeId(s['expenseId']);
                      final targetExpId = _safeId(expenseId);

                      final peopleMatch =
                          sPayer == _safeId(memberId) &&
                          sReceiver == _safeId(payerId);

                      if (!peopleMatch) return false;

                      // Strict match on expense ID
                      if (sExpId.isNotEmpty && sExpId == targetExpId) {
                        return true;
                      }

                      // If settlement has NO expense ID, fall back to Amount match
                      if (sExpId.isEmpty) {
                        final sAmount = (s['amount'] as num)
                            .toDouble()
                            .toStringAsFixed(2);
                        final targetAmount = share.toStringAsFixed(2);
                        return sAmount == targetAmount;
                      }

                      return false;
                    });

                    final hasPending = memberSettlements.any(
                      (s) => s['status'] == 'pending',
                    );
                    final hasCompleted = memberSettlements.any(
                      (s) => s['status'] == 'completed',
                    );
                    final pendingSettlementId = hasPending
                        ? memberSettlements.firstWhere(
                            (s) => s['status'] == 'pending',
                          )['id']
                        : null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            backgroundImage:
                                (profile['photoUrl'] != null &&
                                    profile['photoUrl'].toString().isNotEmpty)
                                ? NetworkImage(profile['photoUrl'])
                                : null,
                            child:
                                (profile['photoUrl'] == null ||
                                    profile['photoUrl'].toString().isEmpty)
                                ? Text(
                                    memberName[0].toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      memberName,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (isPayer) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'PAYER',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (hasCompleted) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'PAID',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  'Share: ₹${share.toStringAsFixed(2)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status / Actions
                          if (isPayer || hasCompleted)
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            )
                          else if (hasPending)
                            if (currentUserId == payerId)
                              ElevatedButton(
                                onPressed: provider.isLoading
                                    ? null
                                    : () => provider.approveSettlement(
                                        pendingSettlementId!,
                                      ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Approve'),
                              )
                            else if (currentUserId == memberId)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'SENDED',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              )
                            else
                              Text(
                                'Pending',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              )
                          else if (currentUserId == memberId)
                            ElevatedButton(
                              onPressed: provider.isLoading
                                  ? null
                                  : () => _confirmAndPay(
                                      context,
                                      provider,
                                      payerId,
                                      payerName,
                                      share,
                                      expenseId,
                                    ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text('Pay'),
                            )
                          else
                            Text(
                              'Owes ₹${share.toStringAsFixed(0)}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.red.shade300,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmAndPay(
    BuildContext context,
    DutchProvider provider,
    String receiverId,
    String receiverName,
    double amount,
    String expenseId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Payment',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Send payment request of ₹${amount.toStringAsFixed(2)} to $receiverName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Get all member IDs for permissions
              final group = provider.groups.firstWhere(
                (g) => g['id'] == provider.currentGroupId,
                orElse: () => {},
              );
              final List<String> groupMembers = List<String>.from(
                group['members'] ?? [],
              );

              await provider.settleDebt(
                payerId: provider.currentUserId!,
                receiverId: receiverId,
                amount: amount,
                groupMembers: groupMembers,
                expenseId: expenseId,
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showSettleUpDialog(
    BuildContext context,
    String otherUserId,
    String otherUserName,
    double netBalance,
  ) {
    final amountController = TextEditingController(
      text: netBalance.abs().toStringAsFixed(2),
    );
    // Actually provider.groupBalances[otherUserId] > 0 means they are owed money.

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              'Settle Up',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(
                    context,
                  ).primaryColor.withOpacity(0.1),
                  backgroundImage:
                      (context
                                  .read<DutchProvider>()
                                  .currentGroupMemberProfiles
                                  .firstWhere(
                                    (p) => p['userId'] == otherUserId,
                                    orElse: () => {},
                                  )['photoUrl'] !=
                              null &&
                          context
                              .read<DutchProvider>()
                              .currentGroupMemberProfiles
                              .firstWhere(
                                (p) => p['userId'] == otherUserId,
                                orElse: () => {},
                              )['photoUrl']
                              .toString()
                              .isNotEmpty)
                      ? NetworkImage(
                          context
                              .read<DutchProvider>()
                              .currentGroupMemberProfiles
                              .firstWhere(
                                (p) => p['userId'] == otherUserId,
                                orElse: () => {},
                              )['photoUrl'],
                        )
                      : null,
                  child:
                      (context
                                  .read<DutchProvider>()
                                  .currentGroupMemberProfiles
                                  .firstWhere(
                                    (p) => p['userId'] == otherUserId,
                                    orElse: () => {},
                                  )['photoUrl'] ==
                              null ||
                          context
                              .read<DutchProvider>()
                              .currentGroupMemberProfiles
                              .firstWhere(
                                (p) => p['userId'] == otherUserId,
                                orElse: () => {},
                              )['photoUrl']
                              .toString()
                              .isEmpty)
                      ? Text(
                          otherUserName.isNotEmpty
                              ? otherUserName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  'Record payment to $otherUserName',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !isSubmitting,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0.0;
                        if (amount <= 0) return;

                        setState(() => isSubmitting = true);

                        final provider = context.read<DutchProvider>();
                        // Get all member IDs for permissions
                        final group = provider.groups.firstWhere(
                          (g) => g['id'] == provider.currentGroupId,
                          orElse: () => {},
                        );
                        final List<String> groupMembers = List<String>.from(
                          group['members'] ?? [],
                        );

                        try {
                          await provider.settleDebt(
                            payerId: provider.currentUserId!,
                            receiverId: otherUserId,
                            amount: amount,
                            groupMembers: groupMembers,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  provider.error == null
                                      ? 'Settlement recorded! Waiting for approval.'
                                      : 'Failed: ${provider.error}',
                                ),
                                backgroundColor: provider.error == null
                                    ? null
                                    : Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                            );
                            setState(() => isSubmitting = false);
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Confirm Payment'),
              ),
            ],
          ),
        );
      },
    );
  }
}
