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
        debugPrint('[Phone] Permission denied');
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

      // Check phone number validity with detailed logging
      if (status.number == null) {
        return;
      }

      final isValid = PhoneNumberUtils.isValidFormat(status.number!);


      if (!isValid) {
        return;
      }

      switch (status.status) {
        case PhoneStateStatus.CALL_INCOMING:
          if (!_isOverlayShowing) {
            _callVerified = false;
            _currentCallNumber = status.number!;
            debugPrint('[Phone] Call: $_currentCallNumber');
            _showIncomingCallOverlay(status.number!);
          }
          break;
        case PhoneStateStatus.CALL_ENDED:
          if (_currentCallNumber != null && _currentCallNumber == status.number) {
            debugPrint('[Phone] Call ended: $_callVerified');
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
      debugPrint('[Phone] Show error: $e');
      _isOverlayShowing = false;
    }
  }


  void _hideCallOverlay() {
    if (!_isOverlayShowing) return;

    try {
      SystemAlertWindow.closeSystemWindow(prefMode: SystemWindowPrefMode.OVERLAY);
    } catch (e) {
      debugPrint('[Phone] Show error: $e');
    }
    _isOverlayShowing = false;
  }

  void setCallVerified(bool verified, [String? phoneNumber]) {
    if (verified) {
      // Set current phone number if phone number is provided
      if (phoneNumber != null && _currentCallNumber == null) {
        _currentCallNumber = phoneNumber;
      }

      _callVerified = true;
      debugPrint('[Phone] SMS verified: $_callVerified');
    } else {
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