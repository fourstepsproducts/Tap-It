import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'package:hive_flutter/hive_flutter.dart';

import 'providers/theme_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/user_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/ledger_provider.dart';

import 'models/investment.dart';
import 'models/investment_transaction.dart';
import 'models/transaction.dart';
import 'models/category.dart';
import 'models/item.dart';
import 'models/ledger_transaction.dart';
import 'models/user_profile.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/ledger_screen.dart';
import 'providers/investment_provider.dart';
import 'providers/dutch_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/goal_provider.dart';
import 'package:home_widget/home_widget.dart';

import 'services/notification_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

void main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://696ec91c09bac14676bc4caafac3bf67@o4510837343911936.ingest.de.sentry.io/4510837354070096';
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;

      // Enable debug logs only in debug mode
      options.debug = kDebugMode;
      options.enableLogs = kDebugMode;

      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      options.profilesSampleRate = 1.0;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      await Hive.initFlutter();

      Hive.registerAdapter(TransactionAdapter());
      Hive.registerAdapter(CategoryAdapter());
      Hive.registerAdapter(ItemAdapter());
      Hive.registerAdapter(LedgerTransactionAdapter());
      Hive.registerAdapter(InvestmentAdapter());
      Hive.registerAdapter(InvestmentTransactionAdapter());
      Hive.registerAdapter(UserProfileAdapter());

      runApp(SentryWidget(child: const MyApp()));
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => LedgerProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
        ChangeNotifierProvider(create: (_) => InvestmentProvider()),
        ChangeNotifierProvider(create: (_) => DutchProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()..init()),
      ],
      child: Consumer2<UserProvider, ThemeProvider>(
        builder: (context, userProvider, themeProvider, _) {
          return MaterialApp(
            title: 'Tap It',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.light(
                primary: themeProvider.seedColor,
                onPrimary: Colors.white,
                primaryContainer: themeProvider.seedColor.withOpacity(0.1),
                onPrimaryContainer: themeProvider.seedColor,
                secondary: themeProvider.seedColor,
                onSecondary: Colors.white,
                surface: Colors.white,
                onSurface: const Color(0xFF1E1E1E),
                background: const Color(0xFFF8F9FA),
                onBackground: const Color(0xFF1E1E1E),
                error: const Color(0xFFFF6B6B),
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.white,
              snackBarTheme: SnackBarThemeData(
                backgroundColor: themeProvider.seedColor,
                contentTextStyle: const TextStyle(color: Colors.white),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.black),
                titleTextStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.dark(
                primary: themeProvider.seedColor,
                onPrimary: Colors.white,
                primaryContainer: themeProvider.seedColor.withOpacity(0.2),
                onPrimaryContainer: themeProvider.seedColor.withOpacity(0.8),
                secondary: themeProvider.seedColor,
                onSecondary: Colors.white,
                surface: const Color(0xFF1E1E1E),
                onSurface: Colors.white,
                background: const Color(0xFF121212),
                onBackground: Colors.white,
                error: const Color(0xFFFF6B6B),
                errorContainer: const Color(0xFF422222),
                onErrorContainer: const Color(0xFFFFD9D9),
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF121212),
              cardColor: const Color(0xFF1E1E1E),
              snackBarTheme: SnackBarThemeData(
                backgroundColor: themeProvider.seedColor,
                contentTextStyle: const TextStyle(color: Colors.white),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF121212),
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignUpScreen(),
              '/home': (context) => const HomeScreen(),
              '/ledger': (context) => const LedgerScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Check Auth
    await context.read<UserProvider>().checkAuthStatus();

    // Check if launched from Widget
    _handleWidgetLaunch();

    // Init Notifications (Don't block UI)
    try {
      await NotificationService().init();
      await NotificationService().requestPermissions();
    } catch (e) {
      // ignore: empty_catches
    }

    // Setup Notification Provider
    if (mounted) {
      final user = context.read<UserProvider>().user;
      if (user != null) {
        // Run in background to avoid blocking
        Future.microtask(
          () => context.read<NotificationProvider>().init(user.userId),
        );
      }
    }
  }

  void _handleWidgetLaunch() async {
    final Uri? uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null && mounted) {
      _navigateToItem(uri);
    }
    
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null && mounted) {
        _navigateToItem(uri);
      }
    });
  }

  void _navigateToItem(Uri uri) {
    if (uri.scheme == 'moneycalc' && uri.host == 'add_transaction') {
      final itemId = uri.queryParameters['itemId'];
      if (itemId != null) {
        // Navigation logic: Need to find the item and open Add Transaction dialog/screen
        // For now, we can just print or use a navigator key if available.
        // Since we are in AuthWrapper, it's a bit tricky. 
        // We'll trust the app handles it in HomeScreen if we pass a flag or similar.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
