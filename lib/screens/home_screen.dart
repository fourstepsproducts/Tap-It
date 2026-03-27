import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/transaction_provider.dart';
import '../providers/user_provider.dart';
import '../providers/ledger_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/investment_provider.dart';
import '../widgets/personal_dashboard.dart';
import '../widgets/ledger_dashboard.dart';
import '../widgets/investment_dashboard.dart';
import '../widgets/dutch_dashboard.dart';
import '../widgets/starter_guide.dart';


import 'ledger_history_screen.dart';
import 'ledger/ledger_due_date_screen.dart';
import 'notification_screen.dart';
import 'ledger_graph_screen.dart';
import 'personal_history_screen.dart';
import 'personal_graph_screen.dart';
import 'investment_history_screen.dart';
import 'investment_graph_screen.dart';
import 'account_screen.dart';
import 'category_screen.dart';
import 'ai_analyzer_screen.dart';
import 'dutch/dutch_history_screen.dart';
import 'dutch/dutch_reports_screen.dart';
import '../providers/dutch_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  // 0: Personal, 1: Ledger, 2: Investment, 3: Dutch
  int _currentMode = 0;
  bool _showGuide = false;
  final LocalAuthentication auth = LocalAuthentication();

  final GlobalKey _personalKey = GlobalKey();
  final GlobalKey _ledgerKey = GlobalKey();
  final GlobalKey _investmentKey = GlobalKey();
  final GlobalKey _dutchKey = GlobalKey();

  Future<void> _authenticate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isBiometricEnabled =
          prefs.getBool('biometric_enabled') ?? false;

      if (!isBiometricEnabled) {
        setState(() {
          _currentMode = 1; // Switch to Ledger
          _selectedIndex = 0; // Reset to Home
        });
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to access Ledger',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (didAuthenticate) {
        setState(() {
          _currentMode = 1; // Switch to Ledger
          _selectedIndex = 0; // Reset to Home
        });
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final userProvider = context.read<UserProvider>();
      final prefs = await SharedPreferences.getInstance();
      final hasSeenGuide = prefs.getBool('has_seen_guide') ?? false;

      if (!hasSeenGuide && mounted) {
        setState(() => _showGuide = true);
      }

      if (userProvider.isInitialCheckDone &&
          userProvider.isAuthenticated &&
          mounted) {
        // Safe delay to ensure app state is fully synced after navigation
        await Future.delayed(const Duration(milliseconds: 600));

        if (mounted) {
          try {
            context.read<TransactionProvider>().fetchData().then((_) {
              context.read<TransactionProvider>().syncWidget();
            });
            context.read<LedgerProvider>().fetchLedgerTransactions();
            context.read<InvestmentProvider>().fetchInvestments();
            context.read<DutchProvider>().fetchGlobalData();
          } catch (e) {
            // ignore: empty_catches
          }
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Dynamic Title based on mode? Or generic?
    // User requested toggle inside AppBar actions.

    return Stack(
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 80,
            backgroundColor: Colors.transparent,
            elevation: 0,
            titleSpacing: 20,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6), // Reduced padding
                  decoration: BoxDecoration(
                    color:
                        theme.colorScheme.primary, // Restored background color
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/icon/app_logo.png',
                    width: 28, // Increased logo size
                    height: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tap It',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: theme.appBarTheme.titleTextStyle?.color,
                  ),
                ),
              ],
            ),
            actions: [
              Consumer<LedgerProvider>(
                builder: (context, provider, child) {
                  final requestCount = provider.incomingRequests.length;
                  return IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotificationScreen(),
                        ),
                      );
                    },
                    icon: Badge(
                      isLabelVisible: requestCount > 0,
                      label: Text('$requestCount'),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AccountScreen(),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.settings,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleBtn('Tap Spend', 0, _personalKey),
                      _buildToggleBtn('Tap Due', 1, _ledgerKey),
                      _buildToggleBtn('Tap Invest', 2, _investmentKey),
                      _buildToggleBtn('Split It', 3, _dutchKey),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: _buildBody(),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: MaterialStateProperty.all(
                GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onItemTapped,
              backgroundColor: theme.cardColor,
              indicatorColor: theme.colorScheme.primary.withOpacity(1.0),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_filled),
                  label: 'Home',
                ),
                if (_currentMode == 0)
                  const NavigationDestination(
                    icon: Icon(Icons.category),
                    label: 'Category',
                  ),
                if (_currentMode == 1) // Ledger Mode
                  const NavigationDestination(
                    icon: Icon(Icons.calendar_month),
                    label: 'Due Date',
                  ),
                if (_currentMode == 2) // Investment Mode
                  const NavigationDestination(
                    icon: Icon(Icons.auto_awesome),
                    label: 'AI Analyzer',
                  ),
                const NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.bar_chart),
                  label: 'Report',
                ),
              ],
            ),
          ),
        ),
        if (_showGuide)
          Positioned.fill(
            child: StarterGuide(
              targetKeys: [_personalKey, _ledgerKey, _investmentKey, _dutchKey],
              onStepChanged: (step) {
                setState(() {
                  _currentMode = step;
                  _selectedIndex = 0;
                });
              },
              onFinish: () {
                setState(() {
                  _showGuide = false;
                  _currentMode = 0;
                  _selectedIndex = 0;
                });
              },
            ),
          ),
      ],
    );
  }

  Widget _buildToggleBtn(String text, int modeIndex, GlobalKey key) {
    final isActive = _currentMode == modeIndex;
    return GestureDetector(
      key: key,
      onTap: () {
        if (!isActive) {
          if (modeIndex == 1) {
            // Ledger needs auth
            _authenticate();
          } else {
            setState(() {
              _currentMode = modeIndex;
              _selectedIndex = 0; // Reset to Home when switching modes
            });
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: isActive ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final ledgerProvider = context.watch<LedgerProvider>();
    final userProvider = context.watch<UserProvider>();
    final currencySymbol = context.watch<CurrencyProvider>().currencySymbol;
    final currentUserContact = userProvider.user?.phone ?? '';
    final ledgerTransactions = ledgerProvider.ledgerTransactions;

    // Index Logic Update for Dutch (Mode 3)
    // Mode 3: 0=Dash, 1=History, 2=Report

    int contentId = 0;

    if (_currentMode == 0) {
      if (_selectedIndex == 0) {
        contentId = 0;
      } else if (_selectedIndex == 1) {
        contentId = 1; // Category
      } else if (_selectedIndex == 2) {
        contentId = 3; // History
      } else if (_selectedIndex == 3) {
        contentId = 4; // Report
      }
    } else if (_currentMode == 1) {
      if (_selectedIndex == 0) {
        contentId = 0;
      } else if (_selectedIndex == 1) {
        contentId = 5; // Due Date
      } else if (_selectedIndex == 2) {
        contentId = 3;
      } else if (_selectedIndex == 3) {
        contentId = 4;
      }
    } else if (_currentMode == 2) {
      if (_selectedIndex == 0) {
        contentId = 0;
      } else if (_selectedIndex == 1) {
        contentId = 2; // AI
      } else if (_selectedIndex == 2) {
        contentId = 3;
      } else if (_selectedIndex == 3) {
        contentId = 4;
      }
    } else if (_currentMode == 3) {
      // Dutch
      if (_selectedIndex == 0) {
        contentId = 0;
      }
      // Index 1 triggers History because we have no middle tab
      else if (_selectedIndex == 1) {
        contentId = 3;
      } else if (_selectedIndex == 2) {
        contentId = 4;
      }
    }

    switch (contentId) {
      case 0: // Dashboard
        if (_currentMode == 0) return const PersonalDashboard();
        if (_currentMode == 1) return const LedgerDashboard();
        if (_currentMode == 2) return const InvestmentDashboard();
        return const DutchDashboard(); // Mode 3

      case 1: // Category (Personal)
        return const CategoryScreen();

      case 2: // AI Analyzer (Investment)
        return const AIAnalyzerScreen();

      case 3: // History
        if (_currentMode == 0) {
          return PersonalHistoryScreen(
            transactions: context.watch<TransactionProvider>().transactions,
            currencySymbol: currencySymbol,
          );
        }
        if (_currentMode == 1) {
          final myIdentities = [
            if (userProvider.user?.phone != null) userProvider.user!.phone,
            if (userProvider.user?.email != null) userProvider.user!.email,
          ].cast<String>();

          return LedgerHistoryScreen(
            transactions: ledgerTransactions,
            myIdentities: myIdentities,
            currencySymbol: currencySymbol,
          );
        }
        if (_currentMode == 2) return const InvestmentHistoryScreen();
        return const DutchHistoryScreen(isGlobal: true);

      case 4: // Graph/Report
        if (_currentMode == 0) return const PersonalGraphScreen();
        if (_currentMode == 1) {
          return LedgerGraphScreen(
            transactions: ledgerTransactions,
            currentUserContact: currentUserContact,
            currencySymbol: currencySymbol,
          );
        }
        if (_currentMode == 2) return const InvestmentGraphScreen();
        return const DutchReportsScreen(isGlobal: true);

      case 5: // Due Date (Ledger)
        return const LedgerDueDateScreen();

      default:
        return const SizedBox.shrink();
    }
  }
}
