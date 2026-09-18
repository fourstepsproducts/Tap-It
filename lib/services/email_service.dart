import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  static const String _email = 'fourstepsproducts@gmail.com';
  static const String _password = 'chyu hokb jnkq rrgh'; 

  String generateOTP() {
    final rand = Random();
    String otp = '';
    for (int i = 0; i < 6; i++) {
      otp += rand.nextInt(10).toString();
    }
    return otp;
  }

  Future<bool> sendOTP(String recipientEmail, String otp) async {
    final smtpServer = gmail(_email, _password);

    final message = Message()
      ..from = const Address(_email, 'Tap It Team')
      ..recipients.add(recipientEmail)
      ..subject = 'Password Reset OTP - Tap It'
      ..text = 'Hello,\n\nYour OTP for resetting your password is: $otp\n\nPlease use this code in the app to complete the password reset process. Do not share this code with anyone.\n\nThanks,\nTap It Team';

    try {
      await send(message, smtpServer);
      return true;
    } on MailerException catch (e) {
      print('Message not sent. ${e.message}');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
      return false;
    }
  }
}
