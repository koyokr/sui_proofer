import 'dart:async';
import 'package:flutter/services.dart';

class EasyWindowOverlay {
  static const MethodChannel _channel = MethodChannel('easy_window_overlay');

  static Future<bool> checkPermissions() async {
    try {
      final bool result = await _channel.invokeMethod('checkPermissions');
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      final bool result = await _channel.invokeMethod('requestPermissions');
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<void> showOverlay({
    required String text,
    required String phoneNumber,
    int? duration,
  }) async {
    try {
      await _channel.invokeMethod('showOverlay', {
        'text': text,
        'phoneNumber': phoneNumber,
        'duration': duration ?? 5000,
      });
    } catch (e) {
      throw Exception('Failed to show overlay: $e');
    }
  }

  static Future<void> hideOverlay() async {
    try {
      await _channel.invokeMethod('hideOverlay');
    } catch (e) {
      throw Exception('Failed to hide overlay: $e');
    }
  }
}