import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';

/// Firebase Phone Authentication sends and verifies the SMS code.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  String? _verificationId;
  ConfirmationResult? _confirmationResult;
  bool _otpSent = false;
  bool _busy = false;
  String? _error;

  AppState get _state => AppStateScope.of(context);

  String _normalizedMobile() {
    final digits = _mobile.text.replaceAll(RegExp(r'\D+'), '');
    return digits.startsWith('91') ? digits.substring(2) : digits;
  }

  Future<void> _sendOtp() async {
    final mobile = _normalizedMobile();
    if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final phoneNumber = '+91$mobile';
      if (kIsWeb) {
        _confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(phoneNumber);
        if (mounted) setState(() => _otpSent = true);
      } else {
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phoneNumber,
          verificationCompleted: _signInWithCredential,
          verificationFailed: (error) {
            if (mounted) setState(() => _error = error.message ?? 'Unable to send verification code');
          },
          codeSent: (verificationId, _) {
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _otpSent = true;
              });
            }
          },
          codeAutoRetrievalTimeout: (verificationId) {
            _verificationId = verificationId;
          },
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final user = (await FirebaseAuth.instance.signInWithCredential(credential)).user;
      final idToken = await user?.getIdToken();
      if (idToken == null) throw StateError('Firebase did not return a sign-in token');
      await _state.loginWithFirebaseToken(idToken);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _error = null; });
    try {
      final UserCredential credential;
      if (kIsWeb) {
        credential = await _confirmationResult!.confirm(_code.text.trim());
      } else {
        final verificationId = _verificationId;
        if (verificationId == null) throw StateError('Request a new verification code');
        final phoneCredential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: _code.text.trim(),
        );
        credential = await FirebaseAuth.instance.signInWithCredential(phoneCredential);
      }
      final idToken = await credential.user?.getIdToken();
      if (idToken == null) throw StateError('Firebase did not return a sign-in token');
      await _state.loginWithFirebaseToken(idToken);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('CCE Outpass',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('Christ College of Engineering, Irinjalakuda',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _mobile,
                    decoration: const InputDecoration(
                      labelText: 'Registered mobile number',
                      prefixText: '+91 ',
                    ),
                    keyboardType: TextInputType.phone,
                    enabled: !_otpSent,
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _code,
                      decoration: const InputDecoration(labelText: '6-digit OTP'),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : (_otpSent ? _verify : _sendOtp),
                    child: Text(_busy
                        ? 'Please wait…'
                        : (_otpSent ? 'Verify & sign in' : 'Send OTP')),
                  ),
                  const SizedBox(height: 12),
                  Text('Sign-in is available for registered, active accounts.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
