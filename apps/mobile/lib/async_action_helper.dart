import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'api_client.dart';

/// Centralized runner for asynchronous actions across all screens in CCE Outpass.
/// Enforces:
/// 1. Strict 15-second timeout on any network/remote action.
/// 2. Clean error message extraction (ApiException, SocketException, TimeoutException).
/// 3. Displaying server errors in a themed SnackBar.
/// 4. Reliable re-enabling of UI buttons via the caller's finally/state handler.
class AsyncActionHelper {
  static const Duration timeoutDuration = Duration(seconds: 15);

  /// Executes [action] with a 15-second timeout.
  /// If an error occurs and [context] is mounted, displays a SnackBar with the error.
  /// Returns `true` if succeeded, `false` otherwise.
  static Future<bool> run(
    BuildContext context, {
    required Future<void> Function() action,
    String? successMessage,
    void Function(String error)? onError,
    VoidCallback? onFinally,
  }) async {
    try {
      await action().timeout(
        timeoutDuration,
        onTimeout: () {
          throw TimeoutException('Request timed out after 15 seconds. Please check your connection.');
        },
      );

      if (context.mounted && successMessage != null && successMessage.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(successMessage)),
              ],
            ),
          ),
        );
      }
      return true;
    } catch (e) {
      final message = extractErrorMessage(e);
      onError?.call(message);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
      }
      return false;
    } finally {
      onFinally?.call();
    }
  }

  /// Extracts a clean, human-readable error string from any thrown exception.
  static String extractErrorMessage(dynamic error) {
    if (error is ApiException) {
      return error.message;
    }
    if (error is TimeoutException) {
      return error.message ?? 'Operation timed out after 15 seconds';
    }
    if (error is SocketException) {
      return 'Unable to connect to server. Please check your network.';
    }
    if (error is FormatException) {
      return 'Server response was malformed. Please try again.';
    }
    final raw = error.toString();
    if (raw.contains('ClientException') ||
        raw.contains('Failed to fetch') ||
        raw.contains('XMLHttpRequest error') ||
        raw.contains('Connection refused') ||
        raw.contains('NetworkError')) {
      return 'Unable to connect to the server. Please check your network connection.';
    }
    return raw.replaceFirst('Exception: ', '').replaceFirst('Error: ', '');
  }
}
