import 'package:flutter/material.dart';

import 'app_state.dart';
import 'api_client.dart';
import 'theme/app_theme.dart';

/// Phone + OTP login screen.
/// OTP verification is handled entirely server-side (the backend checks
/// TEMP_OTP_ENABLED or Firebase). The mobile app never knows the OTP logic.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mobile = TextEditingController();
  final _code = TextEditingController();
  bool _otpSent = false;
  bool _busy = false;
  String? _error;

  AppState get _state => AppStateScope.of(context);

  String _normalizedMobile() => normalizeMobilePhone(_mobile.text);

  Future<void> _sendOtp() async {
    final mobile = _normalizedMobile();
    if (!RegExp(r'^\d{10}$').hasMatch(mobile)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _state.sendOtp(mobile);
      if (mounted) {
        setState(() {
          _otpSent = true;
          _busy = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _busy = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _busy = false;
        });
      }
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final mobile = _normalizedMobile();

    try {
      await _state.verifyOtpAndLogin(mobile, _code.text.trim());
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _busy = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / Title
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded,
                            color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text('CCE Outpass',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text('Christ College of Engineering, Irinjalakuda',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Login card
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Sign in',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _mobile,
                          decoration: InputDecoration(
                            labelText: 'Registered mobile number',
                            prefixText: '+91 ',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          keyboardType: TextInputType.phone,
                          enabled: !_otpSent,
                        ),
                        if (_otpSent) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _code,
                            decoration: InputDecoration(
                              labelText: '6-digit OTP',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            autofocus: true,
                          ),
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontSize: 13)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed:
                              _busy ? null : (_otpSent ? _verify : _sendOtp),
                          icon: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(_otpSent
                                  ? Icons.login_rounded
                                  : Icons.send_rounded),
                          label: Text(_busy
                              ? 'Please wait…'
                              : (_otpSent ? 'Verify & sign in' : 'Send OTP')),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        if (_otpSent) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _otpSent = false;
                                _code.clear();
                                _error = null;
                              });
                            },
                            child: const Text('← Change number'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
