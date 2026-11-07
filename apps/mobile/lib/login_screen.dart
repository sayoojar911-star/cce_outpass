import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'widgets/physical_id_card_login.dart';

/// Physical College ID Card Login Screen.
/// Provides authentic phone + Firebase OTP authentication housed entirely inside
/// the realistic institutional college identity card.
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.isEmbedded = false,
  });

  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    if (isEmbedded) {
      return const PhysicalIdCardLogin();
    }

    return const Scaffold(
      backgroundColor: Color(0xFFF4F1E8),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s24,
            ),
            child: PhysicalIdCardLogin(),
          ),
        ),
      ),
    );
  }
}
