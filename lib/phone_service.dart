import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'utils/phone_number_utils.dart';

class PhoneService {
  static final PhoneService _instance = PhoneService._internal();
  factory PhoneService() {
    _singletonInstance = _instance;
    return _instance;
  }
  PhoneService._internal();

  static PhoneService getInstance() {
    _singletonInstance ??= PhoneService._internal();
    return _singletonInstance!;
  }

  StreamSubscription<PhoneState>? _phoneStateSubscription;
  bool _isInitialized = false;
  bool _isOverlayShowing = false;
  StreamSubscription? _overlaySubscription;
  static PhoneService? _singletonInstance;
  bool _callVerified = false;
  String? _currentCallNumber;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // First check if permission exists
    final hasPermission = await SystemAlertWindow.checkPermissions();
    if (hasPermission != true) {
      // Request permission if not available
      final overlayPermission = await SystemAlertWindow.requestPermissions();
      if (overlayPermission != true) {
        debugPrint('Overlay permission denied');
        return false;
      }
    }

    // Start phone state listener
    _startPhoneStateListener();

    // Register overlay event listener
    _overlaySubscription = SystemAlertWindow.overlayListener.listen((event) {
      if (event.toString().contains('click') || event.toString().contains('touch')) {
        _hideCallOverlay();
      }
    });

    _isInitialized = true;
    return true;
  }



  void _startPhoneStateListener() {
    _phoneStateSubscription = PhoneState.stream.listen((PhoneState status) {
      debugPrint('[Phone] ${status.status} - ${status.number ?? 'Unknown'}');

      // Check phone number validity with detailed logging
      if (status.number == null) {
        debugPrint('[Phone] Ignoring null number');
        return;
      }

      final isValid = PhoneNumberUtils.isValidFormat(status.number!);
      final normalized = PhoneNumberUtils.normalize(status.number!);

      debugPrint('[Phone] Number validation: ${status.number} -> normalized: $normalized, valid: $isValid');

      if (!isValid) {
        debugPrint('[Phone] Ignoring invalid number: ${status.number}');
        return;
      }

      switch (status.status) {
        case PhoneStateStatus.CALL_INCOMING:
          if (!_isOverlayShowing) {
            _callVerified = false;
            _currentCallNumber = status.number!;
            debugPrint('[Phone] New call started: $_currentCallNumber');
            _showIncomingCallOverlay(status.number!);
          }
          break;
        case PhoneStateStatus.CALL_ENDED:
          if (_currentCallNumber != null && _currentCallNumber == status.number) {
            debugPrint('[Phone] Call ended - number: $_currentCallNumber, verification status: $_callVerified');
            // Simply output log only
            debugPrint('[Phone] Call end completed - verification status: $_callVerified');
            _hideCallOverlay();
            _currentCallNumber = null;
          }
          break;
        default:
          _hideCallOverlay();
          break;
      }
    });
  }

  Future<void> _showIncomingCallOverlay(String phoneNumber) async {
    if (_isOverlayShowing) return;

    _isOverlayShowing = true;
    debugPrint('[Overlay] Displaying overlay: $phoneNumber');

    try {
      await SystemAlertWindow.showSystemWindow(
        height: -1,
        width: -1,
        gravity: SystemWindowGravity.TOP,
        notificationTitle: "Sui Proofer - Incoming Call",
        notificationBody: phoneNumber,
        prefMode: SystemWindowPrefMode.OVERLAY,
        layoutParamFlags: [],
      );

      await SystemAlertWindow.sendMessageToOverlay('PHONE_NUMBER:$phoneNumber');
      await SystemAlertWindow.sendMessageToOverlay('SMS_STATUS:Waiting');
    } catch (e) {
      debugPrint('[Overlay] Error: $e');
      _isOverlayShowing = false;
    }
  }


  void _hideCallOverlay() {
    if (!_isOverlayShowing) return;

    try {
      SystemAlertWindow.closeSystemWindow(prefMode: SystemWindowPrefMode.OVERLAY);
    } catch (e) {
      debugPrint('[Overlay] Error: $e');
    }
    _isOverlayShowing = false;
  }

  void setCallVerified(bool verified, [String? phoneNumber]) {
    if (verified) {
      // Set current phone number if phone number is provided
      if (phoneNumber != null && _currentCallNumber == null) {
        _currentCallNumber = phoneNumber;
        debugPrint('[Phone] Current phone number set: $_currentCallNumber');
      }

      _callVerified = true;
      debugPrint('[Phone] ★★★ SMS verification completed - number: $_currentCallNumber, status: $_callVerified ★★★');
    } else {
      debugPrint('[Phone] SMS verification failed - verified: $verified, number: $_currentCallNumber');
    }
  }

  bool get isCallVerified => _callVerified;
  String? get currentCallNumber => _currentCallNumber;


  Future<void> updateToVerifiedCall([String? phoneNumber]) async {
    setCallVerified(true, phoneNumber);
  }

  void dispose() {
    _phoneStateSubscription?.cancel();
    _overlaySubscription?.cancel();
    _hideCallOverlay();
    _isInitialized = false;
  }
}