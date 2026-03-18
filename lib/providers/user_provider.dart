import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
// Keep for now
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/appwrite_service.dart';
import 'package:appwrite/appwrite.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final AppwriteService _appwriteService = AppwriteService();

  UserProfile? _user;
  bool _isLoading =
      false; // Changed from true to false to show splash/login immediately
  bool _isAuthenticated = false;
  bool _isInitialCheckDone = false;

  UserProfile? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialCheckDone => _isInitialCheckDone;

  List<String> _banks = [];
  List<String> get banks => _banks;

  Map<String, String> _primaryPaymentMethods = {};
  Map<String, String> get primaryPaymentMethods => _primaryPaymentMethods;

  List<String> _customPaymentMethods = [];
  List<String> get customPaymentMethods => _customPaymentMethods;

  String _paymentMethodLayout = 'grid'; // Default layout
  String get paymentMethodLayout => _paymentMethodLayout;

  late Box<UserProfile> _userBox;
  late Box _settingsBox; // New box for banks and primary methods
  bool _isHiveInitialized = false;

  UserProvider() {
    // init(); // Do not call async init in constructor without care
  }

  Future<void> init() async {
    await checkAuthStatus();
  }

  // Added loadUser as alias for checkAuthStatus to fix error in HomeScreen
  Future<void> loadUser() async {
    await checkAuthStatus();
  }

  Future<void> _initHive() async {
    if (_isHiveInitialized) return;
    _userBox = await Hive.openBox<UserProfile>('user_profile');
    _settingsBox = await Hive.openBox('user_settings');
    _isHiveInitialized = true;

    // Load banks and primary methods
    _banks = List<String>.from(_settingsBox.get('banks', defaultValue: []));
    _primaryPaymentMethods = Map<String, String>.from(
      _settingsBox.get('primary_payment_methods', defaultValue: {}),
    );
    _customPaymentMethods = List<String>.from(
      _settingsBox.get('custom_payment_methods', defaultValue: []),
    );
    _paymentMethodLayout = _settingsBox.get(
      'payment_method_layout',
      defaultValue: 'grid',
    );
  }

  Future<void> checkAuthStatus({bool forceCheck = false}) async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());

    try {
      await _initHive();

      // 1. Load from Cache
      if (_userBox.isNotEmpty) {
        _user = _userBox.get('current_user');
        if (_user != null) {
          _isAuthenticated = true;
          // Schedule for next frame to avoid build-time errors
          Future.microtask(() => notifyListeners());
        }
      }

      // 2. Check Real Auth
      final isLoggedIn = await _authService.isLoggedIn(forceCheck: forceCheck);

      if (isLoggedIn) {
        final userData = await _authService.getCurrentUser();
        if (userData != null) {
          final newUser = UserProfile(
            userId: userData['userId'],
            name: userData['name'],
            email: userData['email'],
            phone: userData['phone'],
            photoUrl: userData['photoUrl'] ?? '',
            joinDate: DateTime.parse(userData['joinDate']),
          );
          _user = newUser;
          // Sync Banks & Primary Methods from Cloud to Local
          if (userData['banks'] != null) {
            _banks = List<String>.from(userData['banks']);
            await _settingsBox.put('banks', _banks);
          }
          if (userData['primaryPaymentMethods'] != null) {
            _primaryPaymentMethods = Map<String, String>.from(
              userData['primaryPaymentMethods'],
            );
            await _settingsBox.put(
              'primary_payment_methods',
              _primaryPaymentMethods,
            );
          }
          if (userData['customPaymentMethods'] != null) {
            _customPaymentMethods = List<String>.from(
              userData['customPaymentMethods'],
            );
            await _settingsBox.put(
              'custom_payment_methods',
              _customPaymentMethods,
            );
          }

          _user = newUser;
          _isAuthenticated = true;

          // Update Cache
          await _userBox.put('current_user', newUser);
        } else {
          _isAuthenticated = false;
          // If server says no user, maybe clear cache?
          // Yes, consistent state.
          // But if offline, this block might throw/not happen.
          // _user = null; // Do NOT clear if just offline error.
        }
      } else {
        // Explicitly NOT logged in (e.g. session expired or never logged in)
        _isAuthenticated = false;
        _user = null;
        await _userBox.clear();
      }
    } catch (e) {
      if (e is AppwriteException && e.code == 401) {
        // Definitely not logged in
        _isAuthenticated = false;
        _user = null;
        if (_isHiveInitialized) await _userBox.clear();
      } else {
        if (e is! AppwriteException || e.code != 401) {
          // ignore: empty_catches
        }
        // On other errors (offline), trust cache.
        if (_user != null) {
          _isAuthenticated = true;
        } else {
          _isAuthenticated = false;
        }
      }
    } finally {
      _isLoading = false;
      _isInitialCheckDone = true;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    // _isLoading = true; // Removed to prevent global rebuild
    // Future.microtask(() => notifyListeners());

    try {
      final result = await _authService.login(email: email, password: password);

      if (result['success']) {
        // Essential delay for Web session propagation
        await Future.delayed(const Duration(milliseconds: 200));
        await checkAuthStatus(forceCheck: true);
      }
      return result;
    } catch (e) {
      String msg = 'Login failed. Please try again.';

      if (e is AppwriteException) {
        switch (e.type) {
          case 'user_invalid_credentials':
          case 'user_invalid_token':
            msg = 'Incorrect email or password.';
            break;
          case 'user_blocked':
            msg = 'Your account has been blocked. Please contact support.';
            break;
          case 'user_not_found':
            msg = 'No account found with this email.';
            break;
          case 'rate_limit_exceeded':
            msg = 'Too many login attempts. Please try again later.';
            break;
          default:
            if (e.message != null && e.message!.isNotEmpty) {
              msg = e.message!;
            }
        }
      }
      return {'success': false, 'message': msg};
    } finally {
      // _isLoading = false; // Removed
      // Future.microtask(() => notifyListeners());
    }
  }

  Future<Map<String, dynamic>> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    // _isLoading = true;
    // Future.microtask(() => notifyListeners());

    try {
      final result = await _authService.signUp(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      if (result['success']) {
        // Essential delay for Web session propagation
        await Future.delayed(const Duration(milliseconds: 200));
        await checkAuthStatus(forceCheck: true);
      }
      return result;
    } catch (e) {
      String msg = 'Sign up failed. Please try again.';

      if (e is AppwriteException) {
        switch (e.type) {
          case 'user_already_exists':
            msg =
                'An account with this email already exists. Please login instead.';
            break;
          case 'password_recently_used': // Rare for signup but good to have
            msg = 'This password has been used recently.';
            break;
          case 'password_personal_data':
            msg =
                'Password should not contain personal data (like name/email).';
            break;
          default:
            if (e.message != null && e.message!.isNotEmpty) {
              msg = e.message!;
            }
        }
      }
      return {'success': false, 'message': msg};
    } finally {
      // _isLoading = false;
      // Future.microtask(() => notifyListeners());
    }
  }

  Future<void> updateProfile(UserProfile updatedProfile) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Update Auth and Database
      await _appwriteService.updateUserProfile(
        userId: updatedProfile.userId,
        name: updatedProfile.name,
        phone: updatedProfile.phone,
        photoUrl: updatedProfile.photoUrl,
      );

      _user = updatedProfile;
      if (_isHiveInitialized) {
        await _userBox.put('current_user', updatedProfile);
      }
    } catch (e) {
      // ignore: empty_catches
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadProfilePhoto(String filePath) async {
    if (_user == null) return null;
    _isLoading = true;
    notifyListeners();
    try {
      final url = await _appwriteService.uploadProfilePhoto(
        _user!.userId,
        filePath,
      );
      if (url != null) {
        // Update profile with the new photourl
        final updatedProfile = UserProfile(
          userId: _user!.userId,
          name: _user!.name,
          email: _user!.email,
          phone: _user!.phone,
          photoUrl: url,
          joinDate: _user!.joinDate,
        );
        await updateProfile(updatedProfile);
        return url;
      }
      return null;
    } catch (e) {
      // ignore: empty_catches
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInWithGoogle() async {
    // _isLoading = true;
    // Future.microtask(() => notifyListeners());
    try {
      final success = await _authService.signInWithGoogle();
      if (success) {
        await checkAuthStatus();
      }
      return success;
    } finally {
      // _isLoading = false;
      // notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    Future.microtask(() => notifyListeners()); // Wrap notifyListeners
    try {
      if (_isHiveInitialized) {
        await _userBox.clear();
        await _settingsBox.clear();
        _banks = [];
        _primaryPaymentMethods = {};
        _customPaymentMethods = [];
      }
      // Check if already logged out from Appwrite to avoid unnecessary calls/errors
      if (!await _appwriteService.isLoggedIn()) {
        // Silent return, no print
        _isLoading = false;
        notifyListeners();
        return;
      }
      await _authService.logout();
      _user = null;
      _isAuthenticated = false;
    } catch (e) {
      // Log error but proceed with local logout if Appwrite logout fails
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Bank Management Methods ---

  Future<void> addBank(String bankName) async {
    if (!_banks.contains(bankName)) {
      _banks.add(bankName);
      await _settingsBox.put('banks', _banks);
      notifyListeners();
      await _syncPreferences();
    }
  }

  Future<void> removeBank(String bankName) async {
    if (_banks.contains(bankName)) {
      _banks.remove(bankName);
      await _settingsBox.put('banks', _banks);

      // Also remove from primary methods if selected
      final keysToRemove = _primaryPaymentMethods.entries
          .where((entry) => entry.value == bankName)
          .map((e) => e.key)
          .toList();

      for (var key in keysToRemove) {
        _primaryPaymentMethods.remove(key);
      }

      if (keysToRemove.isNotEmpty) {
        await _settingsBox.put(
          'primary_payment_methods',
          _primaryPaymentMethods,
        );
      }
      notifyListeners();
      await _syncPreferences();
    }
  }

  Future<void> setPrimaryPaymentMethod(String method, String? bankName) async {
    if (bankName == null) {
      _primaryPaymentMethods.remove(method);
    } else {
      _primaryPaymentMethods[method] = bankName;
    }
    await _settingsBox.put('primary_payment_methods', _primaryPaymentMethods);
    notifyListeners();
    await _syncPreferences();
  }

  Future<void> addCustomPaymentMethod(String methodName) async {
    if (!_customPaymentMethods.contains(methodName)) {
      _customPaymentMethods.add(methodName);
      await _settingsBox.put('custom_payment_methods', _customPaymentMethods);
      notifyListeners();
      await _syncPreferences();
    }
  }

  Future<void> removeCustomPaymentMethod(String methodName) async {
    if (_customPaymentMethods.contains(methodName)) {
      _customPaymentMethods.remove(methodName);
      await _settingsBox.put('custom_payment_methods', _customPaymentMethods);

      // Also remove from primary methods if selected
      final keysToRemove = _primaryPaymentMethods.entries
          .where(
            (entry) => entry.key == methodName,
          ) // Primary key IS the method name
          .map((e) => e.key)
          .toList();

      for (var key in keysToRemove) {
        _primaryPaymentMethods.remove(key);
      }

      // Also if any custom method was used as a value... (unlikely but safe check?)
      // Actually primaryPaymentMethods key is the METHOD name (UPI, Debit Card, etc OR CustomName)
      // and Value is the BANK name.
      // So if "MyCustomMethod" is removed, we should remove the key "MyCustomMethod" from primary methods.
      // logic above does exactly that: where entry.key == methodName.

      if (keysToRemove.isNotEmpty) {
        await _settingsBox.put(
          'primary_payment_methods',
          _primaryPaymentMethods,
        );
      }

      notifyListeners();
      await _syncPreferences();
    }
  }

  bool isPaymentMethodEnabled(String method) {
    if (_primaryPaymentMethods.containsKey('${method}_enabled')) {
      return _primaryPaymentMethods['${method}_enabled'] == 'true';
    }
    return true; // Default to enabled
  }

  Future<void> togglePaymentMethod(String method, bool enabled) async {
    _primaryPaymentMethods['${method}_enabled'] = enabled.toString();
    await _settingsBox.put('primary_payment_methods', _primaryPaymentMethods);
    notifyListeners();
    await _syncPreferences();
  }

  Future<void> renameCustomPaymentMethod(String oldName, String newName) async {
    if (oldName == newName) return;
    if (_customPaymentMethods.contains(newName)) {
      throw 'Method name already exists';
    }

    final index = _customPaymentMethods.indexOf(oldName);
    if (index != -1) {
      _customPaymentMethods[index] = newName;
      await _settingsBox.put('custom_payment_methods', _customPaymentMethods);

      // Update primary methods key if it exists
      if (_primaryPaymentMethods.containsKey(oldName)) {
        final bank = _primaryPaymentMethods[oldName];
        _primaryPaymentMethods.remove(oldName);
        _primaryPaymentMethods[newName] = bank!;
        await _settingsBox.put(
          'primary_payment_methods',
          _primaryPaymentMethods,
        );
      }

      notifyListeners();
      await _syncPreferences();
    }
  }

  Future<void> _syncPreferences() async {
    if (_user != null) {
      await _appwriteService.updateUserPreferences(
        userId: _user!.userId,
        banks: _banks,
        primaryPaymentMethods: _primaryPaymentMethods,
        customPaymentMethods: _customPaymentMethods,
      );
    }
  }

  Future<void> setPaymentMethodLayout(String layout) async {
    _paymentMethodLayout = layout;
    if (_isHiveInitialized) {
      await _settingsBox.put('payment_method_layout', layout);
    }
    notifyListeners();
  }
}
