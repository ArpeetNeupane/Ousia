import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ousia/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _service = AuthService();
  int _step = 0; // 0=email, 1=otp, 2=new password
  bool _isLoading = false;
  String? _error;
  String _email = '';

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final result = await _service.forgotPassword(email);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      _email = email;
      setState(() => _step = 1);
    } else {
      setState(() => _error = result['message']);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final result = await _service.verifyOtp(_email, otp);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      setState(() => _step = 2);
    } else {
      setState(() => _error = result['message']);
    }
  }

  Future<void> _resetPassword() async {
    final newPass = _newPassController.text.trim();
    final confirm = _confirmPassController.text.trim();
    final otp = _otpController.text.trim();
    if (newPass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    final result = await _service.resetPassword(_email, otp, newPass, confirm);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully! Please log in.')),
      );
    } else {
      setState(() => _error = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => _step > 0 ? setState(() => _step--) : Navigator.pop(context),
        ),
        title: Text(
          _step == 0 ? 'Forgot Password' : _step == 1 ? 'Enter Code' : 'New Password',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: cs.onSurface),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator
            Row(
              children: List.generate(3, (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= _step ? cs.primary : cs.outlineVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 32),

            if (_step == 0) ...[
              Text('Enter your email', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 8),
              Text("We'll send a 6-digit code to your email.", style: GoogleFonts.inter(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(Icons.email_outlined, color: cs.onSurfaceVariant),
                ),
              ),
            ] else if (_step == 1) ...[
              Text('Check your email', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 8),
              Text('Enter the 6-digit code sent to $_email', style: GoogleFonts.inter(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8, color: cs.onSurface),
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ] else ...[
              Text('Set new password', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 24),
              TextField(
                controller: _newPassController,
                obscureText: !_showNew,
                style: GoogleFonts.inter(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPassController,
                obscureText: !_showConfirm,
                style: GoogleFonts.inter(color: cs.onSurface),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.inter(color: Colors.red, fontSize: 13)),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (_step == 0 ? _sendOtp : _step == 1 ? _verifyOtp : _resetPassword),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _step == 0 ? 'Send Code' : _step == 1 ? 'Verify Code' : 'Reset Password',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}