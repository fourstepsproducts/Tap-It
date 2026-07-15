import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tapit/services/appwrite_service.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth_android/local_auth_android.dart';

import '../../models/transaction.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _biometricsEnabled = false;
  final AppwriteService _appwriteService = AppwriteService();
  bool _isExporting = false;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricsEnabled = prefs.getBool('biometric_enabled') ?? false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      // User trying to enable
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometrics not available on this device.'),
          ),
        );
        return;
      }

      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Please authenticate to enable biometric lock',
          authMessages: const <AuthMessages>[
            AndroidAuthMessages(
              signInTitle: 'Enable Biometrics',
              cancelButton: 'No thanks',
            ),
          ],
          options: const AuthenticationOptions(stickyAuth: true),
        );

        if (!didAuthenticate) {
          // User cancelled or failed
          return;
        }
      } on PlatformException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
    }

    // If we reached here, either we are disabling it (no auth needed usually)
    // or we successfully authenticated to enable it.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', value);
    setState(() {
      _biometricsEnabled = value;
    });
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final transactionsData = await _appwriteService.getTransactions();
      final transactions = transactionsData
          .map((data) => Transaction.fromJson(data))
          .toList();

      List<List<dynamic>> csvData = [
        ['Date', 'Title', 'Amount', 'Type', 'Category'],
      ];

      for (var t in transactions) {
        csvData.add([
          t.dateTime.toIso8601String(),
          t.title,
          t.amount,
          t.isExpense ? 'Expense' : 'Income',
          t.categoryId ?? '',
        ]);
      }

      String csvString = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/transactions.csv');
      await file.writeAsString(csvString);

      await Share.shareXFiles([XFile(file.path)], text: 'My Transactions');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Privacy & Security',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onBackground,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader('Security'),
          _buildSwitchTile(
            title: 'Biometric Lock',
            subtitle: 'Require Face ID / Fingerprint to open',
            icon: Icons.fingerprint,
            value: _biometricsEnabled,
            onChanged: _toggleBiometrics,
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('Data Management'),
          _buildActionTile(
            title: _isExporting ? 'Exporting...' : 'Export Data',
            subtitle: 'Download your transaction history (CSV)',
            icon: Icons.download_rounded,
            onTap: _isExporting ? () {} : _exportData,
          ),
          _buildActionTile(
            title: 'Clear Search History',
            subtitle: 'Remove saved search terms',
            icon: Icons.history,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search history cleared.')),
              );
            },
          ),

          const SizedBox(height: 32),
          _buildSectionHeader('Danger Zone', color: Colors.red),
          _buildActionTile(
            title: 'Delete Account',
            subtitle: 'Permanently remove your account and data',
            icon: Icons.delete_forever,
            isDanger: true,
            onTap: () {
              // Show confirmation dialog (mock)
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Account'),
                  content: const Text(
                    'Are you sure? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color ?? Theme.of(context).colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        activeColor: Theme.of(context).colorScheme.primary,
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? Colors.red : Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isDanger
            ? Border.all(color: Colors.red.withOpacity(0.1))
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isDanger
                ? Colors.red
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
