import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/currency_provider.dart';
import '../../providers/dutch_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/appwrite_service.dart';
import '../../utils/formatters.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateGroupDialog extends StatefulWidget {
  final List<Map<String, String>>? initialMembers;
  const CreateGroupDialog({super.key, this.initialMembers});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  String _selectedType = 'trip';
  final List<String> _types = ['trip', 'home', 'couple', 'other'];

  String _selectedIcon = 'flight_takeoff';
  final List<String> _icons = [
    'flight_takeoff',
    'home',
    'favorite',
    'celebration',
    'restaurant',
    'shopping_bag',
    'bolt',
    'movie',
    'sports_esports',
    'pets',
  ];

  // List of members to add: {id, name, phone}
  final List<Map<String, String>> _membersToAdd = [];
  String? _memberError;
  final String _selectedCountryCode = '+91';
  final TextEditingController _searchController = TextEditingController();
  List<Contact> _contacts = [];
  bool _contactsLoaded = false;
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialMembers != null) {
      _membersToAdd.addAll(widget.initialMembers!);
    }
    _loadContacts();
  }

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
    }
  }

  bool get _hasNonAppMembers =>
      _membersToAdd.any((m) => m['id'] == null || m['id']!.isEmpty);

  void _removeMember(int index) {
    setState(() {
      _membersToAdd.removeAt(index);
    });
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final dutchProvider = context.read<DutchProvider>();
    final currencyProvider = context.read<CurrencyProvider>();
    final currentUser = userProvider.user;

    if (currentUser == null) return;

    final memberIds = [currentUser.userId];
    for (var m in _membersToAdd) {
      memberIds.add(m['id']!);
    }

    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final rawName = _nameController.text.trim();
      final name = rawName.isNotEmpty
          ? rawName[0].toUpperCase() + rawName.substring(1)
          : rawName;

      final success = await dutchProvider.createGroup(
        name: name,
        type: _selectedType,
        members: memberIds,
        createdBy: currentUser.userId,
        currency: currencyProvider.currencySymbol,
        icon: _selectedIcon,
      );

      if (success) {
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                dutchProvider.error ?? 'Unknown error creating group',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
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

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<DutchProvider>().isLoading;
    final ledgerProvider = context.watch<LedgerProvider>();
    final suggestedUsers = ledgerProvider.knownAppUsers;

    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Group',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [CapitalizeFirstLetterTextFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. Goa Trip 2024',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                Text(
                  'Icon',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _icons.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final iconName = _icons[index];
                      final isSelected = _selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = iconName),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconData(iconName),
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Type',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _types.map((type) {
                    final isSelected = _selectedType == type;
                    return ChoiceChip(
                      label: Text(type[0].toUpperCase() + type.substring(1)),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedType = type);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                Text(
                  'Members',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _searchController,
                  onChanged: (value) async {
                    setState(() {
                      if (value.isEmpty) {
                        _searchResults = [];
                      } else {
                        _searchResults = _contacts
                            .where((contact) {
                              final name = contact.displayName;
                              final nameMatch = name.toLowerCase().contains(
                                value.toLowerCase(),
                              );
                              final phoneMatch = contact.phones.any(
                                (p) => p.number.contains(value),
                              );
                              return nameMatch || phoneMatch;
                            })
                            .take(5)
                            .toList();
                      }
                    });

                    if (value.length >= 3) {
                      try {
                        final remoteUsers = await AppwriteService()
                            .searchContacts(value);
                        if (_searchController.text == value) {
                          setState(() {
                            for (var user in remoteUsers) {
                              final remotePhone = user['phone']
                                  .toString()
                                  .replaceAll(RegExp(r'\D'), '');
                              final remoteFormatted = remotePhone.length >= 10
                                  ? remotePhone.substring(
                                      remotePhone.length - 10,
                                    )
                                  : remotePhone;

                              int index = _searchResults.indexWhere((r) {
                                if (r is Contact) {
                                  return r.phones.any((p) {
                                    final pNorm = p.number.replaceAll(
                                      RegExp(r'\D'),
                                      '',
                                    );
                                    final pFormatted = pNorm.length >= 10
                                        ? pNorm.substring(pNorm.length - 10)
                                        : pNorm;
                                    return pFormatted == remoteFormatted;
                                  });
                                }
                                final rNorm = r['phone'].toString().replaceAll(
                                  RegExp(r'\D'),
                                  '',
                                );
                                final rFormatted = rNorm.length >= 10
                                    ? rNorm.substring(rNorm.length - 10)
                                    : rNorm;
                                return rFormatted == remoteFormatted;
                              });

                              if (index != -1) {
                                // Replace local contact with remote user data
                                _searchResults[index] = {
                                  ...user,
                                  'isRemote': true,
                                };
                              } else {
                                _searchResults.add({...user, 'isRemote': true});
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
                    fillColor: Theme.of(context).colorScheme.surface,
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchResults = [];
                              });
                            },
                          )
                        : null,
                  ),
                ),

                // Suggested People
                if (_searchController.text.isEmpty &&
                    suggestedUsers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Available People',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: suggestedUsers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final user = suggestedUsers[index];
                        final isSelected = _membersToAdd.any(
                          (m) => m['id'] == user['id'],
                        );
                        return _buildMemberCard(
                          name: user['name']!,
                          phone: user['phone']!,
                          id: user['id']!,
                          isSelected: isSelected,
                          isAppUser: true,
                          showInvite: false,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _membersToAdd.removeWhere(
                                  (m) => m['id'] == user['id'],
                                );
                              } else {
                                _membersToAdd.add({
                                  'id': user['id']!,
                                  'name': user['name']!,
                                  'phone': user['phone']!,
                                });
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],

                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _searchResults[index];
                        String name = '';
                        String phone = '';
                        String id = '';
                        bool isRemote = false;

                        if (item is Contact) {
                          name = item.displayName;
                          phone = item.phones.isNotEmpty
                              ? item.phones.first.number
                              : '';
                        } else {
                          name = item['name'] ?? '';
                          phone = item['phone'] ?? '';
                          id = item['userId'] ?? '';
                          isRemote = item['isRemote'] ?? false;
                        }

                        final isSelected = _membersToAdd.any(
                          (m) =>
                              m['phone'] == phone ||
                              (isRemote && m['id'] == id),
                        );

                        return _buildMemberCard(
                          name: name,
                          phone: phone,
                          id: id,
                          isSelected: isSelected,
                          isAppUser: isRemote,
                          showInvite: false,
                          onTap: () async {
                            setState(() {
                              if (isSelected) {
                                _membersToAdd.removeWhere(
                                  (m) =>
                                      m['phone'] == phone ||
                                      (isRemote && m['id'] == id),
                                );
                              } else {
                                final cleanPhone = phone.replaceAll(
                                  RegExp(r'\D'),
                                  '',
                                );
                                final formattedPhone = cleanPhone.length >= 10
                                    ? cleanPhone.substring(
                                        cleanPhone.length - 10,
                                      )
                                    : cleanPhone;

                                _membersToAdd.add({
                                  'id': id,
                                  'name': name,
                                  'phone':
                                      '$_selectedCountryCode$formattedPhone',
                                });
                              }
                            });

                            if (!isSelected && item is Contact) {
                              try {
                                final cleanPhone = phone.replaceAll(
                                  RegExp(r'\D'),
                                  '',
                                );
                                final formattedPhone = cleanPhone.length >= 10
                                    ? cleanPhone.substring(
                                        cleanPhone.length - 10,
                                      )
                                    : cleanPhone;
                                final fullPhone =
                                    '$_selectedCountryCode$formattedPhone';
                                final user = await AppwriteService()
                                    .getUserByPhone(fullPhone);
                                if (user != null) {
                                  setState(() {
                                    final last = _membersToAdd.last;
                                    last['id'] = user['userId'];
                                    last['name'] = user['name'] ?? last['name'];
                                  });
                                }
                              } catch (e) { /* ignored */ }
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],

                if (_searchController.text.isNotEmpty &&
                    _searchResults.isEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'No app users found for "${_searchController.text}"',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () async {
                            final text = _searchController.text.trim();
                            final isPhone = RegExp(
                              r'^\+?[0-9]{10,}$',
                            ).hasMatch(text);
                            final url = Uri.parse(
                              isPhone
                                  ? 'https://wa.me/$text?text=Hey! Join me on Tap It to track our shared expenses easily.'
                                  : 'whatsapp://send?text=Hey! Join me on Tap It to track our shared expenses easily.',
                            );
                            if (await canLaunchUrl(url)) {
                              await launchUrl(
                                url,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Invite via WhatsApp'),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                if (_membersToAdd.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Added Members',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _membersToAdd.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final m = _membersToAdd[index];
                        final isAppUser =
                            m['id'] != null && m['id']!.isNotEmpty;
                        return _buildMemberCard(
                          name: m['name']!,
                          phone: m['phone']!,
                          id: m['id'] ?? '',
                          isSelected: true,
                          isAppUser: isAppUser,
                          showInvite: true,
                          onRemove: () => _removeMember(index),
                        );
                      },
                    ),
                  ),
                  if (_hasNonAppMembers)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Only app users can be added to groups. Please remove others.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                if (_memberError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      _memberError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isLoading || _hasNonAppMembers)
                        ? null
                        : _createGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create Group'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard({
    required String name,
    required String phone,
    required String id,
    required bool isSelected,
    required bool isAppUser,
    required bool showInvite,
    VoidCallback? onTap,
    VoidCallback? onRemove,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withOpacity(0.1),
            width: isSelected ? 2 : 1,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isAppUser
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.grey.shade100,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: isAppUser
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isSelected && onRemove == null)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).cardColor,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
                if (onRemove != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).cardColor,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isAppUser)
              Text(
                'On Tap It',
                style: GoogleFonts.inter(
                  fontSize: 7,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              )
            else ...[
              Text(
                phone,
                style: GoogleFonts.inter(fontSize: 7, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (showInvite) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(
                      'https://wa.me/$phone?text=Hey! Join me on Tap It to track our shared expenses easily.',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.share, size: 8, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'Invite',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'flight_takeoff':
        return Icons.flight_takeoff;
      case 'home':
        return Icons.home;
      case 'favorite':
        return Icons.favorite;
      case 'celebration':
        return Icons.celebration;
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'bolt':
        return Icons.bolt;
      case 'movie':
        return Icons.movie;
      case 'sports_esports':
        return Icons.sports_esports;
      case 'pets':
        return Icons.pets;
      default:
        return Icons.group;
    }
  }
}
