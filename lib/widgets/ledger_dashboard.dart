import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/formatters.dart';

import '../models/ledger_transaction.dart';
import '../services/appwrite_service.dart';
// import 'package:intl/intl.dart';
// import '../screens/ledger_graph_screen.dart';
// import '../screens/ledger_history_screen.dart';
import '../screens/ledger/person_ledger_screen.dart';
import '../providers/ledger_provider.dart';
import '../providers/user_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/empty_state.dart';

class LedgerDashboard extends StatefulWidget {
  const LedgerDashboard({super.key});

  @override
  State<LedgerDashboard> createState() => _LedgerDashboardState();
}

class _LedgerDashboardState extends State<LedgerDashboard> {
  bool _showAllPeople = false;
  List<Contact> _contacts = [];
  bool _contactsLoaded = false;

  Future<void> _loadContacts() async {
    if (_contactsLoaded) return;

    final status = await Permission.contacts.request();

    if (status.isGranted) {
      try {
        final contacts = await FastContacts.getAllContacts(
          fields: [ContactField.displayName, ContactField.phoneNumbers],
        );

        if (mounted) {
          setState(() {
            _contacts = contacts;
            _contactsLoaded = true;
          });
        }
      } catch (e) { /* ignored */ }
    } else {}
  }

  // Copied Dialog Logic
  void _showAddDialog({
    String? initialName,
    String? initialPhone,
    double? initialAmount,
    bool isReceived = false,
  }) {
    _loadContacts(); // Trigger contact load when dialog opens
    final nameController = TextEditingController(text: initialName);
    final phoneController = TextEditingController(text: initialPhone);
    final amountController = TextEditingController(
      text: initialAmount?.toString() ?? '',
    );
    final searchController = TextEditingController();
    final descController = TextEditingController();
    String selectedCountryCode = '+91';

    bool? isRegistered;
    bool checkingRegistration = false;
    bool trackWithUser = true; // Default to true if user exists

    List<dynamic> combinedResults = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isReceived ? 'Borrow Money' : 'Lend Money',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: searchController,
                    onChanged: (value) async {
                      setDialogState(() {
                        if (value.isEmpty) {
                          combinedResults = [];
                        } else {
                          // Initial local search
                          combinedResults = _contacts
                              .where((contact) {
                                final name = contact.displayName;
                                final nameMatch = name.toLowerCase().contains(
                                  value.toLowerCase(),
                                );
                                final phones = contact.phones;
                                final phoneMatch = phones.any(
                                  (p) => p.number.contains(value),
                                );
                                return nameMatch || phoneMatch;
                              })
                              .take(5)
                              .toList();
                        }
                      });

                      // Remote search for app users
                      if (value.length >= 3) {
                        try {
                          final remoteUsers = await AppwriteService()
                              .searchContacts(value);
                          if (searchController.text == value) {
                            setDialogState(() {
                              for (var user in remoteUsers) {
                                // Simple duplicate check by phone
                                final phone = user['phone'];
                                bool exists = combinedResults.any((r) {
                                  if (r is Contact) {
                                    return r.phones.any(
                                      (p) => p.number.contains(phone),
                                    );
                                  }
                                  return r['phone'] == phone;
                                });
                                if (!exists) {
                                  combinedResults.add({
                                    ...user,
                                    'isRemote': true,
                                  });
                                }
                              }
                            });
                          }
                        } catch (e) { /* ignored */ }
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by name or number...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.05),
                    ),
                  ),
                  if (combinedResults.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: combinedResults.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = combinedResults[index];
                          String name = '';
                          String phone = '';
                          bool isRemote = false;

                          if (item is Contact) {
                            name = item.displayName;
                            phone = item.phones.isNotEmpty
                                ? item.phones.first.number
                                : '';
                          } else {
                            name = item['name'] ?? '';
                            phone = item['phone'] ?? '';
                            isRemote = item['isRemote'] ?? false;
                          }

                          return ListTile(
                            visualDensity: VisualDensity.compact,
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isRemote)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'On Tap It',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: phone.isNotEmpty
                                ? Text(
                                    phone,
                                    style: GoogleFonts.inter(fontSize: 11),
                                  )
                                : null,
                            onTap: () async {
                              final phoneToUse = phone;
                              final cleanPhone = phoneToUse.replaceAll(
                                RegExp(r'\D'),
                                '',
                              );
                              final formattedPhone = cleanPhone;

                              nameController.text = name;
                              phoneController.text = formattedPhone;

                              setDialogState(() {
                                combinedResults = [];
                                searchController.clear();
                                checkingRegistration = true;
                              });

                              // Trigger Registration Check
                              try {
                                final fullPhone =
                                    '$selectedCountryCode$formattedPhone';
                                final user = await AppwriteService()
                                    .getUserByPhone(fullPhone);

                                setDialogState(() {
                                  isRegistered = user != null;
                                  checkingRegistration = false;
                                  trackWithUser = isRegistered == true;
                                });
                              } catch (e) {
                                setDialogState(
                                  () => checkingRegistration = false,
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CountryCodePicker(
                          onChanged: (code) =>
                              selectedCountryCode = code.dialCode ?? '+91',
                          initialSelection: 'IN',
                          showCountryOnly: false,
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
                        child: TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          onChanged: (value) async {
                            final phone = value.replaceAll(RegExp(r'\D'), '');
                            if (phone.length >= 7) {
                              setDialogState(() => checkingRegistration = true);
                              final fullPhone = '$selectedCountryCode$phone';
                              try {
                                final user = await AppwriteService()
                                    .getUserByPhone(fullPhone);

                                setDialogState(() {
                                  isRegistered = user != null;
                                  checkingRegistration = false;
                                  // Auto-fill Name if found!
                                  if (user != null && user['name'] != null) {
                                    nameController.text = user['name'];
                                  }
                                  // Reset track toggles based on user existence
                                  if (isRegistered == true) {
                                    trackWithUser = true;
                                  } else {
                                    trackWithUser = false;
                                  }
                                });
                              } catch (e) {
                                setDialogState(
                                  () => checkingRegistration = false,
                                );
                              }
                            } else {
                              if (isRegistered != null) {
                                setDialogState(() => isRegistered = null);
                              }
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: checkingRegistration
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : isRegistered == true
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isRegistered == false) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'User not on Tap It. Saving as a Note.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () async {
                                if (phoneController.text.isNotEmpty) {
                                  final phone =
                                      '$selectedCountryCode${phoneController.text}';
                                  final url = Uri.parse(
                                    'https://wa.me/$phone?text=Hey! Join me on Tap It to track our expenses easily. Download it here: [Link]',
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(
                                      url,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Invite via WhatsApp'),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [CapitalizeFirstLetterTextFormatter()],
                    decoration: InputDecoration(
                      labelText: (isReceived ? 'Lender Name' : 'Borrower Name'),
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  if (isRegistered == true) ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(
                        'Track the transactions',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        trackWithUser
                            ? 'Sends a request'
                            : 'Save as private note',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      value: trackWithUser,
                      onChanged: (val) {
                        setDialogState(() {
                          trackWithUser = val;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.isNotEmpty &&
                            amountController.text.isNotEmpty) {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);

                          final phoneStr = phoneController.text.isEmpty
                              ? null
                              : '$selectedCountryCode${phoneController.text}';

                          final userProvider = context.read<UserProvider>();
                          final currentUser = userProvider.user;

                          final ledgerProvider = context.read<LedgerProvider>();

                          // Determine status based on tracking toggle
                          String? customStatus;
                          if (isRegistered == true && trackWithUser) {
                            customStatus = null;
                          } else {
                            customStatus = 'notes';
                          }

                          final error = await ledgerProvider
                              .addLedgerTransaction(
                                nameController.text,
                                phoneStr,
                                double.tryParse(amountController.text) ?? 0.0,
                                descController.text,
                                isReceived: isReceived,
                                currentUserId: currentUser?.userId ?? '',
                                currentUserName: currentUser?.name ?? '',
                                currentUserPhone: currentUser?.phone ?? '',
                                customStatus: customStatus,
                              );

                          if (error == null &&
                              customStatus == 'notes' &&
                              mounted) {
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Added to Notes.')),
                            );
                          }

                          if (error != null && mounted) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Error Adding'),
                                content: Text(error),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text((isReceived ? 'Add Record' : 'Lend Money')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ledgerProvider = context.watch<LedgerProvider>();
    final userProvider = context.watch<UserProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;

    // Data Source Switch
    // Unified Data Source
    final activeTransactions = [
      ...ledgerProvider.ledgerTransactions,
      ...ledgerProvider.outgoingRequests,
      ...ledgerProvider.incomingRequests,
      ...ledgerProvider.notes,
    ];

    final user = userProvider.user;
    final myIdentities = [
      if (user?.phone != null && user!.phone.isNotEmpty) user.phone,
      if (user?.email != null && user!.email.isNotEmpty) user.email,
    ].cast<String>();

    final currentUserId = ledgerProvider.currentUserId;

    if (ledgerProvider.isLoading) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            SkeletonLoader(height: 150, borderRadius: 24),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: SkeletonLoader(height: 80)),
                SizedBox(width: 16),
                Expanded(child: SkeletonLoader(height: 80)),
              ],
            ),
          ],
        ),
      );
    }

    double totalReceived = activeTransactions
        .where(
          (t) =>
              !((currentUserId != null && t.senderId == currentUserId) ||
                  myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id))),
        )
        .fold(0, (sum, t) => sum + t.amount);

    double totalSent = activeTransactions
        .where(
          (t) =>
              (currentUserId != null && t.senderId == currentUserId) ||
              myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id)),
        )
        .fold(0, (sum, t) => sum + t.amount);

    // Net Balance formula: Received - Given
    double netBalance = totalReceived - totalSent;

    return RefreshIndicator(
      onRefresh: () async {
        await ledgerProvider.fetchLedgerTransactions();
      },
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(), // Ensure scrollable even if content is short
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(
              netBalance,
              totalSent, // Rec (To Receive) = Money I Sent
              totalReceived, // Sent (To Pay) = Money I Received
              currencySymbol,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    Icons.upload,
                    'Lend',
                    const Color(0xFFFF6B6B),
                    () => _showAddDialog(isReceived: false),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionButton(
                    Icons.download,
                    'Borrow',
                    const Color(0xFF51CF66),
                    () => _showAddDialog(isReceived: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'People',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'hidden') {
                      _showHiddenPeopleDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'hidden',
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 20,
                            color: Colors.grey,
                          ),
                          SizedBox(width: 8),
                          Text('Hidden People'),
                        ],
                      ),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.more_horiz),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPeopleGrid(
              activeTransactions,
              myIdentities,
              currencySymbol,
              currentUserId,
            ),
            const SizedBox(height: 32),

            // Recent Transactions Section
            Builder(
              builder: (context) {
                final recentTx = activeTransactions.where((tx) {
                  return tx.dateTime.isAfter(
                    DateTime.now().subtract(const Duration(hours: 24)),
                  );
                }).toList();

                // Sort by DateTime descending
                // Sort by DateTime descending
                recentTx.sort((a, b) => b.dateTime.compareTo(a.dateTime));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (recentTx.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.history,
                                size: 48,
                                color: Colors.grey,
                              ),
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
                        ),
                      )
                    else
                      ...recentTx.map((tx) {
                        final isMeSender =
                            (currentUserId != null &&
                                tx.senderId == currentUserId) ||
                            myIdentities.any(
                              (id) => _arePhonesEqual(tx.senderPhone, id),
                            );

                        final isExpense =
                            isMeSender; // I sent/lent = Expense/Out
                        final otherName = isMeSender
                            ? tx.receiverName
                            : tx.senderName;
                        final otherId = isMeSender
                            ? tx.receiverId
                            : tx.senderId;
                        final otherPhoto = otherId != null
                            ? ledgerProvider.userPhotos[otherId]
                            : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isExpense
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                backgroundImage:
                                    (otherPhoto != null &&
                                        otherPhoto.isNotEmpty)
                                    ? NetworkImage(otherPhoto)
                                    : null,
                                child:
                                    (otherPhoto == null || otherPhoto.isEmpty)
                                    ? Icon(
                                        isExpense
                                            ? Icons.arrow_downward
                                            : Icons.arrow_upward,
                                        color: isExpense
                                            ? Colors.red
                                            : Colors.green,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      otherName,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${_formatTime(tx.dateTime)} â€¢ ${tx.status.capitalize()}',
                                      style: GoogleFonts.inter(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${isExpense ? '-' : '+'}$currencySymbol${tx.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isExpense ? Colors.red : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // Helpers
  Widget _buildPeopleGrid(
    List<LedgerTransaction> transactions,
    List<String> myIdentities,
    String currencySymbol,
    String? currentUserId,
  ) {
    final balances = _calculateUserBalances(
      transactions,
      myIdentities,
      currentUserId,
    );
    if (balances.isEmpty) {
      return const EmptyState(
        title: 'No records',
        message: 'Start lending/receiving',
        icon: Icons.people_outline,
      );
    }

    return Column(
      children: [
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio:
                0.75, // Increased height ratio to prevent overflow
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _showAllPeople
              ? balances.length
              : (balances.length > 9 ? 9 : balances.length),
          itemBuilder: (context, index) {
            final b = balances[index];
            return _buildPersonGridItem(
              b['name'],
              b['phone'],
              b['userId'],
              b['balance'],
              transactions,
              myIdentities,
              currencySymbol,
              currentUserId,
              onLongPress: () => _showPersonOptions(
                b['name'],
                b['phone'],
                myIdentities.isNotEmpty ? myIdentities.first : '',
              ),
            );
          },
        ),
        if (balances.length > 9)
          TextButton(
            onPressed: () => setState(() => _showAllPeople = !_showAllPeople),
            child: Text(_showAllPeople ? 'Show Less' : 'Show More'),
          ),
      ],
    );
  }

  // Refactored helper to get transactions for a specific person
  List<LedgerTransaction> _getPersonTransactions(
    List<LedgerTransaction> allTx,
    String personName,
    String personPhone,
    List<String> myIdentities,
    String? currentUserId,
  ) {
    return allTx.where((t) {
      final isMeSender =
          (currentUserId != null && t.senderId == currentUserId) ||
          myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id));
      final isMeReceiver =
          (currentUserId != null && t.receiverId == currentUserId) ||
          myIdentities.any((id) => _arePhonesEqual(t.receiverPhone, id));

      if (isMeSender) {
        // I sent, checking if receiver is this person
        if (personPhone.isNotEmpty && t.receiverPhone != null) {
          return _arePhonesEqual(t.receiverPhone, personPhone);
        }
        return t.receiverName == personName;
      } else if (isMeReceiver) {
        // I received, checking if sender is this person
        if (personPhone.isNotEmpty) {
          return _arePhonesEqual(t.senderPhone, personPhone);
        }
        return t.senderName == personName;
      }
      return false;
    }).toList();
  }

  bool _arePhonesEqual(String? p1, String? p2) {
    if (p1 == null || p2 == null) return false;
    if (p1.contains('@') || p2.contains('@')) {
      return p1.toLowerCase().trim() == p2.toLowerCase().trim();
    }
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

  // Reuse existing calculation logic
  List<Map<String, dynamic>> _calculateUserBalances(
    List<LedgerTransaction> transactions,
    List<String> myIdentities,
    String? currentUserId,
  ) {
    // Filter hidden and soft-deleted people
    final hiddenPeople = context.read<LedgerProvider>().hiddenPeople;
    final softDeletedPeople = context.read<LedgerProvider>().softDeletedPeople;

    // Use a complex key for grouping: Phone (priority) -> Name
    Map<String, double> balances = {};
    Map<String, String> names = {};
    Map<String, String> phones = {};
    Map<String, String> ids = {};
    Map<String, DateTime> lastInteraction = {};

    for (var t in transactions) {
      final isSent =
          (currentUserId != null && t.senderId == currentUserId) ||
          myIdentities.any((id) => _arePhonesEqual(t.senderPhone, id));
      final otherName = isSent ? t.receiverName : t.senderName;
      final otherPhone = isSent ? t.receiverPhone : t.senderPhone;
      final otherId = isSent ? t.receiverId : t.senderId;

      // Skip if hidden or soft-deleted
      if (hiddenPeople.contains(otherName) ||
          softDeletedPeople.contains(otherName)) {
        continue;
      }

      // Grouping Key Logic
      String key;
      if (otherPhone != null &&
          otherPhone.isNotEmpty &&
          !otherPhone.startsWith('local:')) {
        // Primary Key: Normalized Phone
        key = _normalizePhone(otherPhone);
      } else {
        // Fallback Key: Name (Lowercased for loose matching)
        key = otherName.trim().toLowerCase();
      }

      // Update Metadata (Keep most recent name, or non-phone name?)
      // Strategy: Use the name associated with the transaction if we don't have one,
      // or if this transaction is newer?
      // Let's keep the longest name found? Or just the first encountered?
      // Better: Keep the name from the *most recent* transaction.
      if (!names.containsKey(key) ||
          t.dateTime.isAfter(lastInteraction[key] ?? DateTime(2000))) {
        names[key] = otherName;
        lastInteraction[key] = t.dateTime;
      }

      if (otherPhone != null && otherPhone.isNotEmpty) {
        phones[key] = otherPhone;
      }

      if (otherId != null && otherId.isNotEmpty && !ids.containsKey(key)) {
        ids[key] = otherId;
      }

      // Aggregate Balance
      balances[key] = (balances[key] ?? 0) + (isSent ? t.amount : -t.amount);
    }

    return balances.entries
        .map(
          (e) => {
            'name': names[e.key] ?? 'Unknown',
            'phone': phones[e.key] ?? '',
            'userId': ids[e.key] ?? '',
            'balance': e.value,
          },
        )
        .toList();
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  String _formatTime(DateTime dateTime) {
    return TimeOfDay.fromDateTime(dateTime).format(context);
  }

  Widget _buildBalanceCard(
    double net,
    double rec,
    double sent,
    String currencySymbol,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
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
                'Net Balance', // Changed from Net Ledger
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$currencySymbol${net.toStringAsFixed(0)}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.arrow_downward_rounded, // Money In (To Receive)
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'To Receive', // User asked for "To Rec"
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currencySymbol${rec.toStringAsFixed(0)}',
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
                          Icons.arrow_upward_rounded, // Money Out (To Pay)
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'To Pay',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$currencySymbol${sent.toStringAsFixed(0)}',
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
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonGridItem(
    String name,
    String phone,
    String? personUserId,
    double bal,
    List<LedgerTransaction> tx,
    List<String> myIdentities,
    String currencySymbol,
    String? currentUserId, {
    VoidCallback? onLongPress,
  }) {
    // Determine status (Notes vs Tracking)
    // Filter transactions for this person
    final personTransactions = _getPersonTransactions(
      tx,
      name,
      phone,
      myIdentities,
      currentUserId,
    );

    // Determine status (Notes vs Tracking)
    bool isNotes = true;
    if (personTransactions.isEmpty) {
      isNotes = true;
    } else {
      for (var t in personTransactions) {
        if (t.status != 'notes') {
          isNotes = false;
          break;
        }
      }
    }

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PersonLedgerScreen(
              personName: name,
              personPhone: phone,
              currentBalance: bal,
              transactions: personTransactions,
              currencySymbol: currencySymbol,
              myIdentities: myIdentities,
              currentUserId: currentUserId ?? '',
              onAddTransaction:
                  (
                    pName,
                    pPhone,
                    amount,
                    desc, {
                    isReceived = false,
                    currentUserPhone,
                    currentUserEmail,
                  }) {
                    final userProvider = context.read<UserProvider>();
                    final currentUser = userProvider.user;

                    return context.read<LedgerProvider>().addLedgerTransaction(
                      pName,
                      pPhone,
                      amount,
                      desc,
                      isReceived: isReceived,
                      currentUserId: currentUser?.userId ?? '',
                      currentUserName: currentUser?.name ?? '',
                      currentUserPhone:
                          currentUserPhone ?? currentUser?.phone ?? '',
                      currentUserEmail: currentUserEmail ?? currentUser?.email,
                      customStatus: null,
                    );
                  },
              onRemind: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'WhatsApp reminder not implemented in this view yet',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade600.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 22, // Reduced from 26
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    backgroundImage:
                        (personUserId != null &&
                            personUserId.isNotEmpty &&
                            context
                                .read<LedgerProvider>()
                                .userPhotos
                                .containsKey(personUserId))
                        ? NetworkImage(
                            context
                                .read<LedgerProvider>()
                                .userPhotos[personUserId]!,
                          )
                        : null,
                    child:
                        (personUserId == null ||
                            personUserId.isEmpty ||
                            !context
                                .read<LedgerProvider>()
                                .userPhotos
                                .containsKey(personUserId))
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 18, // Reduced from 22
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: -1,
                  right: -1,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isNotes ? Colors.orange : Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(
                      isNotes ? Icons.edit_note : Icons.sync,
                      size: 8, // Reduced from 10
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8), // Reduced from 12
            Text(
              name,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 13, // Reduced from 15
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2), // Reduced from 4
            Text(
              bal >= 0 ? 'Owes you' : 'You owe',
              style: GoogleFonts.inter(
                color: Colors.grey.shade600,
                fontSize: 10, // Reduced from 11
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 1), // Reduced from 2
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$currencySymbol${bal.abs().toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15, // Reduced from 17
                  color: bal >= 0
                      ? const Color(0xFF51CF66)
                      : const Color(0xFFFF6B6B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPersonOptions(
    String name,
    String phone,
    String currentUserContact,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Person'),
              onTap: () {
                Navigator.pop(context);
                _showEditPersonDialog(name, phone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.orange),
              title: const Text(
                'Remove from Dashboard',
                style: TextStyle(color: Colors.orange),
              ),
              onTap: () {
                Navigator.pop(context);
                _confirmDeletePerson(name, phone);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off, color: Colors.grey),
              title: const Text('Hide from Dashboard'),
              onTap: () async {
                Navigator.pop(context);
                final provider = context.read<LedgerProvider>();
                await provider.hidePerson(name);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed $name from view')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPersonDialog(String currentName, String currentPhone) {
    final nameController = TextEditingController(text: currentName);

    // Separate logic to extract country code if possible, default to IN (+91)
    String initialPhone = currentPhone;
    String selectedCountryCode = '+91';

    if (initialPhone.startsWith('+91')) {
      initialPhone = initialPhone.substring(3);
    } else if (initialPhone.startsWith('local:')) {
      initialPhone = ''; // displaying empty for simpler editing
    }

    final phoneController = TextEditingController(text: initialPhone);
    final formKey = GlobalKey<FormState>();

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
                        initialSelection: 'IN', // Default to India for now
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

                        if (newName == currentName &&
                            newPhone == currentPhone) {
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Updating person...')),
                        );

                        final success = await context
                            .read<LedgerProvider>()
                            .updatePerson(
                              oldName: currentName,
                              oldPhone: currentPhone,
                              newName: newName,
                              newPhone: newPhone,
                            );

                        if (success) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Person updated successfully'),
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update person'),
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

  void _confirmDeletePerson(String name, String phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Dashboard?'),
        content: Text(
          'This will remove $name from your dashboard. Records will reappear if you add a new transaction for them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Removing $name...')));

              final provider = context.read<LedgerProvider>();
              await provider.softDeletePerson(name);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name removed from dashboard')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showHiddenPeopleDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final provider = context.watch<LedgerProvider>();
            final hiddenPeople = provider.hiddenPeople;
            final softDeletedPeople = provider.softDeletedPeople;

            // Only show manually hidden people, NOT soft-deleted ones
            final visibleHiddenPeople = hiddenPeople
                .where((name) => !softDeletedPeople.contains(name))
                .toList();

            return AlertDialog(
              title: const Text('Hidden People'),
              content: SizedBox(
                width: double.maxFinite,
                child: visibleHiddenPeople.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'No hidden people.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: visibleHiddenPeople.length,
                        itemBuilder: (context, index) {
                          final name = visibleHiddenPeople[index];
                          return ListTile(
                            title: Text(name),
                            trailing: IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () async {
                                await context
                                    .read<LedgerProvider>()
                                    .unhidePerson(name);
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
