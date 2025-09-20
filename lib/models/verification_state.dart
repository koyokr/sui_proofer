import 'package:flutter/material.dart';

enum VerificationState {
  pending,    // Verifying (gray)
  verified,   // Verified (green)
  failed      // Verification failed (red)
}

extension VerificationStateExtension on VerificationState {
  String get titleText => "Sui Proofer";

  String get statusMessage {
    switch (this) {
      case VerificationState.pending:
        return "Waiting for SMS";
      case VerificationState.verified:
        return "SMS Received";
      case VerificationState.failed:
        return "Verification Failed!";
    }
  }

  String get description {
    switch (this) {
      case VerificationState.pending:
        return "Waiting for verification message...";
      case VerificationState.verified:
        return "Verified successfully!";
      case VerificationState.failed:
        return "Verification failed - timeout";
    }
  }

  IconData get icon {
    switch (this) {
      case VerificationState.pending:
        return Icons.hourglass_empty;
      case VerificationState.verified:
        return Icons.verified_user;
      case VerificationState.failed:
        return Icons.warning;
    }
  }

  List<Color> get gradientColors {
    switch (this) {
      case VerificationState.pending:
        return [
          Colors.grey[800]!,
          Colors.grey[700]!,
          Colors.grey[600]!,
        ];
      case VerificationState.verified:
        return [
          Colors.green[900]!,
          Colors.green[800]!,
          Colors.green[700]!,
        ];
      case VerificationState.failed:
        return [
          Colors.red[900]!,
          Colors.red[800]!,
          Colors.red[700]!,
        ];
    }
  }

  Color get accentColor {
    switch (this) {
      case VerificationState.pending:
        return Colors.grey;
      case VerificationState.verified:
        return Colors.greenAccent;
      case VerificationState.failed:
        return Colors.redAccent;
    }
  }
}