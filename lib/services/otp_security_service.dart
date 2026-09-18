import 'package:shared_preferences/shared_preferences.dart';

class OtpSecurityService {
  static const int maxAttempts = 3;
  static const int cooldownMinutes = 10;

  // Keys for SharedPreferences
  String _getAttemptsKey(String email) => 'otp_attempts_$email';
  String _getCooldownKey(String email) => 'otp_cooldown_$email';

  /// Returns the current number of failed attempts for the given email
  Future<int> getFailedAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_getAttemptsKey(email)) ?? 0;
  }

  /// Records a failed attempt. 
  /// Returns `true` if the user has reached the maximum attempts and a cooldown has started.
  Future<bool> recordFailedAttempt(String email) async {
    final prefs = await SharedPreferences.getInstance();
    int currentAttempts = await getFailedAttempts(email);
    currentAttempts += 1;
    
    await prefs.setInt(_getAttemptsKey(email), currentAttempts);

    if (currentAttempts >= maxAttempts) {
      // Start cooldown
      final cooldownTime = DateTime.now().add(const Duration(minutes: cooldownMinutes));
      await prefs.setString(_getCooldownKey(email), cooldownTime.toIso8601String());
      return true;
    }
    
    return false;
  }

  /// Resets the failed attempts and clears any cooldowns for the given email
  Future<void> resetAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getAttemptsKey(email));
    await prefs.remove(_getCooldownKey(email));
  }

  /// Checks if the email is currently on cooldown
  Future<bool> isEmailOnCooldown(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownString = prefs.getString(_getCooldownKey(email));
    
    if (cooldownString == null) return false;

    final cooldownTime = DateTime.parse(cooldownString);
    if (DateTime.now().isBefore(cooldownTime)) {
      return true; // Still on cooldown
    } else {
      // Cooldown expired, reset attempts so they get 3 new tries
      await resetAttempts(email);
      return false;
    }
  }

  /// Returns a human-readable string of the remaining cooldown time (e.g., "9m 30s")
  /// Returns null if not on cooldown.
  Future<String?> getRemainingCooldown(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final cooldownString = prefs.getString(_getCooldownKey(email));
    
    if (cooldownString == null) return null;

    final cooldownTime = DateTime.parse(cooldownString);
    final now = DateTime.now();
    
    if (now.isBefore(cooldownTime)) {
      final difference = cooldownTime.difference(now);
      final minutes = difference.inMinutes;
      final seconds = difference.inSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
    
    return null;
  }
}
