import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:system_alert_window/system_alert_window.dart';

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

    // 먼저 권한이 있는지 확인
    final hasPermission = await SystemAlertWindow.checkPermissions();
    if (hasPermission != true) {
      // 권한이 없으면 요청
      final overlayPermission = await SystemAlertWindow.requestPermissions();
      if (overlayPermission != true) {
        debugPrint('Overlay permission denied');
        return false;
      }
    }

    // 전화 상태 리스너 시작
    _startPhoneStateListener();

    // 오버레이 이벤트 리스너 등록
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

      // Unknown 번호는 모든 상태에서 무시
      if (status.number == null || status.number == 'Unknown' || status.number == 'null' || status.number!.isEmpty) {
        debugPrint('[Phone] Unknown 번호 무시');
        return;
      }

      switch (status.status) {
        case PhoneStateStatus.CALL_INCOMING:
          if (!_isOverlayShowing) {
            _callVerified = false;
            _currentCallNumber = status.number!;
            debugPrint('[Phone] 새 전화 시작: $_currentCallNumber');
            _showIncomingCallOverlay(status.number!);
          }
          break;
        case PhoneStateStatus.CALL_ENDED:
          if (_currentCallNumber != null && _currentCallNumber == status.number) {
            debugPrint('[Phone] 전화 종료 - 번호: $_currentCallNumber, 검증상태: $_callVerified');
            // 단순히 로그만 출력
            debugPrint('[Phone] 전화 종료 완료 - 검증상태: $_callVerified');
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
    debugPrint('[Overlay] 오버레이 표시: $phoneNumber');

    try {
      await SystemAlertWindow.showSystemWindow(
        height: -1,
        width: -1,
        gravity: SystemWindowGravity.TOP,
        notificationTitle: "수신 전화",
        notificationBody: phoneNumber,
        prefMode: SystemWindowPrefMode.OVERLAY,
        layoutParamFlags: [],
      );

      await SystemAlertWindow.sendMessageToOverlay('PHONE_NUMBER:$phoneNumber');
      await SystemAlertWindow.sendMessageToOverlay('SMS_STATUS:대기중');
    } catch (e) {
      debugPrint('[Overlay] 오류: $e');
      _isOverlayShowing = false;
    }
  }


  void _hideCallOverlay() {
    if (!_isOverlayShowing) return;

    try {
      SystemAlertWindow.closeSystemWindow(prefMode: SystemWindowPrefMode.OVERLAY);
    } catch (e) {
      debugPrint('[Overlay] 오류: $e');
    }
    _isOverlayShowing = false;
  }

  void setCallVerified(bool verified, [String? phoneNumber]) {
    if (verified) {
      // 전화번호가 전달되면 현재 전화번호 설정
      if (phoneNumber != null && _currentCallNumber == null) {
        _currentCallNumber = phoneNumber;
        debugPrint('[Phone] 현재 전화번호 설정: $_currentCallNumber');
      }

      _callVerified = true;
      debugPrint('[Phone] ★★★ SMS 검증 완료 - 번호: $_currentCallNumber, 상태: $_callVerified ★★★');
    } else {
      debugPrint('[Phone] SMS 검증 실패 - verified: $verified, 번호: $_currentCallNumber');
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