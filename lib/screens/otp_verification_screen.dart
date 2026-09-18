import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/otp_security_service.dart';
import 'reset_password_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String generatedOtp;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.generatedOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _otpSecurityService = OtpSecurityService();
  String? _errorMessage;
  bool _isLocked = false;
  bool _isLoading = false;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _checkInitialCooldown();
  }

  Future<void> _checkInitialCooldown() async {
    final attempts = await _otpSecurityService.getFailedAttempts(widget.email);
    if (mounted) {
      setState(() {
        _failedAttempts = attempts;
      });
    }

    if (await _otpSecurityService.isEmailOnCooldown(widget.email)) {
      final remaining = await _otpSecurityService.getRemainingCooldown(widget.email);
      if (mounted) {
        setState(() {
          _isLocked = true;
          _errorMessage = 'Too many failed attempts. Try again in $remaining.';
        });
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_isLocked) {
      final remaining = await _otpSecurityService.getRemainingCooldown(widget.email);
      setState(() {
        _errorMessage = 'Account locked. Try again in $remaining.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final enteredOtp = _otpController.text.trim();
    
    if (enteredOtp.isEmpty || enteredOtp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit OTP.';
        _isLoading = false;
      });
      return;
    }

    if (enteredOtp == widget.generatedOtp) {
      // Success - reset attempts
      await _otpSecurityService.resetAttempts(widget.email);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResetPasswordScreen(email: widget.email),
          ),
        );
      }
    } else {
      // Failed attempt
      final isNowOnCooldown = await _otpSecurityService.recordFailedAttempt(widget.email);
      
      if (mounted) {
        setState(() {
          _failedAttempts++;
        });

        if (isNowOnCooldown) {
          setState(() {
            _isLocked = true;
            _errorMessage = 'Too many failed attempts. Please try again in 10 minutes.';
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Invalid OTP. Please try again.';
            _otpController.clear();
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Verify OTP', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor,
              primaryColor.withOpacity(0.8),
              primaryColor.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.password, size: 60, color: primaryColor),
                    const SizedBox(height: 24),
                    Text(
                      'Enter OTP',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E1E1E),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We have sent a 6-digit OTP to \n${widget.email}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1E1E1E),
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_isLocked)
                      Text(
                        'Attempts remaining: ${OtpSecurityService.maxAttempts - _failedAttempts}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: _failedAttempts == 2 ? const Color(0xFFFF6B6B) : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5E5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.inter(color: const Color(0xFFFF6B6B), fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        disabledBackgroundColor: primaryColor.withOpacity(0.6),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Verify',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
