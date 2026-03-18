import 'package:hive/hive.dart';
import 'dart:convert'; // Added for jsonDecode

part 'user_profile.g.dart';

@HiveType(typeId: 0)
class UserProfile {
  @HiveField(0)
  final String userId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String email;

  @HiveField(3)
  final String phone;

  @HiveField(4)
  final String photoUrl;

  @HiveField(5)
  final DateTime joinDate;

  @HiveField(6)
  final List<String> banks;

  @HiveField(7)
  final Map<String, String> primaryPaymentMethods;

  UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.joinDate,
    this.banks = const [],
    this.primaryPaymentMethods = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['\$id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      photoUrl: json['photoUrl'] ?? '',
      joinDate: DateTime.parse(
        json['joinDate'] ?? DateTime.now().toIso8601String(),
      ),
      banks: json['banks'] != null
          ? List<String>.from(json['banks'])
          : const [],
      primaryPaymentMethods: json['primaryPaymentMethods'] != null
          ? _parsePrimaryMethods(json['primaryPaymentMethods'])
          : const {},
    );
  }

  static Map<String, String> _parsePrimaryMethods(dynamic data) {
    if (data is Map) {
      return Map<String, String>.from(data);
    }
    if (data is String && data.isNotEmpty) {
      try {
        // If stored as JSON string in Appwrite
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return Map<String, String>.from(decoded);
        }
      } catch (e) {
        // ignore: empty_catches
      }
    }
    return {};
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'joinDate': joinDate.toIso8601String(),
      'banks': banks,
      // Store as JSON string for Appwrite string attribute, or Map if supported
      'primaryPaymentMethods': primaryPaymentMethods,
    };
  }
}
