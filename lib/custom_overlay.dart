import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'package:http/http.dart' as http;
import 'sms_service.dart';
import 'phone_service.dart';

// Constants
class OverlayConstants {
  static const String mainAppPort = 'MainApp';
  static const Duration verificationTimeout = Duration(seconds: 5);
  static const Duration urlValidationTimeout = Duration(seconds: 10);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration overlayAnimationDuration = Duration(milliseconds: 800);
  static const Duration scaleAnimationDuration = Duration(milliseconds: 400);
  static const Duration iconAnimationDuration = Duration(milliseconds: 600);
}

class CustomOverlay extends StatefulWidget {
  const CustomOverlay({super.key});

  @override
  State<CustomOverlay> createState() => _CustomOverlayState();
}

// 전역 변수로 전화번호 저장
String? _currentPhoneNumber;
List<SmsMessage> _realtimeSms = [];

// 검증 상태 정의
enum VerificationState {
  pending,    // 검증 중 (회색)
  verified,   // 검증됨 (초록)
  failed      // 검증 실패 (빨강)
}

VerificationState _verificationState = VerificationState.pending;
List<String> _lastSmsUrls = []; // 마지막 수신 SMS에서 추출된 URL 링크들
Timer? _verificationTimer; // 검증 타이머
bool _isProcessingSms = false; // SMS 처리 중 플래그

class _CustomOverlayState extends State<CustomOverlay> {
  SendPort? mainAppPort;
  bool update = false;
  final SmsService _smsService = SmsService();

  @override
  void initState() {
    super.initState();

    // SMS 서비스 초기화
    _initializeSmsService();

    SystemAlertWindow.overlayListener.listen((event) {
      log("$event in overlay");
      if (event is bool) {
        setState(() {
          update = event;
        });
      } else if (event is String && event.startsWith('PHONE_NUMBER:')) {
        // 전화번호 업데이트
        final phoneNumber = event.replaceFirst('PHONE_NUMBER:', '');
        setState(() {
          _currentPhoneNumber = phoneNumber;
          _realtimeSms.clear(); // 새로운 전화 시 실시간 SMS 초기화
          _verificationState = VerificationState.pending; // 검증 중 상태로 시작
          _lastSmsUrls.clear(); // URL 링크 초기화
          _isProcessingSms = false; // SMS 처리 플래그 초기화
        });

        // 검증 타이머 시작
        _startVerificationTimer();
        log("Phone number updated: $_currentPhoneNumber");
      } else if (event is String && event.startsWith('SMS_STATUS:')) {
        // SMS 검증 상태 업데이트
        final status = event.replaceFirst('SMS_STATUS:', '');
        setState(() {
          if (status == "수신됨") {
            _verificationState = VerificationState.verified;
            _cancelVerificationTimer(); // 검증 성공 시 타이머 취소
          } else {
            _lastSmsUrls.clear(); // 상태 변경 시 URL 링크 초기화
          }
        });
        log("SMS status updated: $status (verification state: $_verificationState)");
      }
    });
  }

  void _initializeSmsService() {
    log("[Overlay SMS] SMS 서비스 초기화 시작");

    // 실시간 SMS 감지 시작 (UI에는 단순하게 표시)
    _smsService.smsStream.listen(
      (sms) async {
        log("[Overlay SMS] Real-time SMS received from ${sms.address}: ${sms.body}");

        // URL 추출 및 로깅
        final urls = _smsService.extractUrlsFromText(sms.body);
        if (urls.isNotEmpty) {
          log("[Overlay SMS URL] Found URLs in SMS:");
          for (String url in urls) {
            log("[Overlay SMS URL] - $url");
          }
        }

        // 현재 전화가 진행 중이고 해당 번호에서 온 SMS인지 확인
        if (_currentPhoneNumber != null &&
            _isMatchingPhoneNumber(sms.address, _currentPhoneNumber!)) {

          // 이미 검증이 완료된 경우 추가 SMS 처리 중단
          if (_verificationState == VerificationState.verified) {
            log("[Overlay SMS] ⚠️ 이미 검증 완료됨 - SMS 처리 중단 (from: ${sms.address})");
            return;
          }

          // SMS 처리 중인 경우 중복 처리 방지
          if (_isProcessingSms) {
            log("[Overlay SMS] ⚠️ SMS 처리 중 - 중복 처리 방지 (from: ${sms.address})");
            return;
          }

          log("[Overlay SMS] SMS matched for current call from: ${sms.address}");
          setState(() {
            _lastSmsUrls = urls; // URL 링크들 저장
          });

          // 링크가 포함된 경우 각 링크를 검증
          if (urls.isNotEmpty) {
            log("[Overlay SMS] 🔗 ${urls.length}개의 링크 발견 - 검증 시작");

            // SMS 처리 시작 플래그 설정
            _isProcessingSms = true;

            // 모든 링크를 검증 (순차적으로)
            bool hasValidLink = false;
            for (String url in urls) {
              try {
                final isValid = await _validateUrlContent(url);
                if (isValid) {
                  hasValidLink = true;
                  log("[Overlay SMS] ✅ 유효한 링크 확인: $url");
                  break; // 하나라도 유효하면 중단
                } else {
                  log("[Overlay SMS] ❌ 무효한 링크: $url");
                }
              } catch (e) {
                log("[Overlay SMS] ❌ 링크 검증 오류 $url: $e");
              }
            }

            // 유효한 링크가 있는 경우에만 검증 완료
            if (hasValidLink) {
              setState(() {
                _verificationState = VerificationState.verified;
              });

              // 검증 성공 시 타이머 취소
              _cancelVerificationTimer();

              log("[Overlay SMS] ✅ 링크 검증 완료 - 최종 승인");
              log("[Overlay SMS] 🚫 검증 완료로 인한 추가 SMS 처리 중단 설정");

              // PhoneService 싱글톤 인스턴스에 검증 상태 알림
              final phoneServiceInstance = PhoneService.getInstance();
              phoneServiceInstance.updateToVerifiedCall(_currentPhoneNumber);
              debugPrint('[Overlay] ★★★ PhoneService에 검증 상태 전달 완료 (번호: $_currentPhoneNumber) ★★★');

              // 메인 앱에도 SMS 수신 상태 알림
              SystemAlertWindow.sendMessageToOverlay('SMS_STATUS:수신됨');
              log("[Overlay SMS] Real-time SMS verification completed for: ${sms.address}");
            } else {
              log("[Overlay SMS] ❌ 모든 링크 검증 실패 - 검증 상태 유지");
              // 실패한 경우 즉시 failed 상태로 변경하지 않고 타이머가 처리하도록 둠
            }

            // SMS 처리 완료 플래그 해제
            _isProcessingSms = false;
          } else {
            log("[Overlay SMS] ❌ 링크가 없는 SMS - 검증 상태 유지");
          }
        } else {
          log("[Overlay SMS] SMS from ${sms.address} doesn't match current call $_currentPhoneNumber");
        }
      },
      onError: (error) {
        log("[Overlay SMS] SMS stream error: $error");
      },
    );

    log("[Overlay SMS] SMS service initialized for real-time detection");
  }

  bool _isMatchingPhoneNumber(String smsNumber, String currentNumber) {
    // 전화번호 비교 (하이픈, 공백, 괄호, + 제거하여 비교)
    String normalize(String number) {
      return number.replaceAll(RegExp(r'[\s\-\(\)\+]'), '').replaceAll('82', '0');
    }

    final normalizedSms = normalize(smsNumber);
    final normalizedCurrent = normalize(currentNumber);

    // 정확한 매칭 또는 끝 4자리 매칭
    bool isMatch = normalizedSms == normalizedCurrent ||
                  (normalizedSms.length >= 4 && normalizedCurrent.length >= 4 &&
                   (normalizedSms.endsWith(normalizedCurrent.substring(normalizedCurrent.length - 4)) ||
                    normalizedCurrent.endsWith(normalizedSms.substring(normalizedSms.length - 4))));

    log("Phone match check: '$smsNumber' ($normalizedSms) vs '$currentNumber' ($normalizedCurrent) = $isMatch");
    return isMatch;
  }

  // 링크의 컨텐츠를 검증하는 함수
  Future<bool> _validateUrlContent(String url) async {
    try {
      log("[URL Validation] Checking URL: $url");

      // HTTP GET 요청
      final response = await http.get(Uri.parse(url)).timeout(
        OverlayConstants.urlValidationTimeout,
        onTimeout: () {
          log("[URL Validation] Timeout for URL: $url");
          return http.Response('Timeout', 408);
        },
      );

      log("[URL Validation] Status Code: ${response.statusCode} for URL: $url");

      if (response.statusCode == 200) {
        // HTTP 200 OK 응답이면 성공
        final body = response.body;
        log("[URL Validation] ✅ HTTP 200 OK - Response body length: ${body.length}");

        // 응답 본문 미리보기 로깅 (처음 100자만)
        log("[URL Validation] Body preview: ${body.length > 100 ? '${body.substring(0, 100)}...' : body}");

        return true; // 200 응답이면 무조건 성공
      } else {
        log("[URL Validation] ❌ HTTP ${response.statusCode} for URL: $url");
        return false;
      }
    } catch (e) {
      log("[URL Validation] ❌ Error validating URL $url: $e");
      return false;
    }
  }

  // 3초 검증 타이머 시작
  void _startVerificationTimer() {
    _verificationTimer?.cancel(); // 기존 타이머 취소

    log("[Timer] ${OverlayConstants.verificationTimeout.inSeconds}초 검증 타이머 시작");
    _verificationTimer = Timer(OverlayConstants.verificationTimeout, () {
      // 타이머 만료 후에도 검증되지 않았다면 실패 처리
      if (_verificationState == VerificationState.pending) {
        setState(() {
          _verificationState = VerificationState.failed;
        });
        log("[Timer] ❌ 검증 타임아웃 - 실패 상태로 변경");
      }
    });
  }

  // 타이머 취소
  void _cancelVerificationTimer() {
    _verificationTimer?.cancel();
    _verificationTimer = null;
    log("[Timer] 검증 타이머 취소됨");
  }

  // 검증 상태에 따른 색상 반환
  List<Color> _getGradientColors() {
    switch (_verificationState) {
      case VerificationState.pending:
        return [
          Colors.grey[800]!,   // 회색 그라데이션
          Colors.grey[700]!,
          Colors.grey[600]!,
        ];
      case VerificationState.verified:
        return [
          Colors.green[900]!,  // 초록색 그라데이션
          Colors.green[800]!,
          Colors.green[700]!,
        ];
      case VerificationState.failed:
        return [
          Colors.red[900]!,    // 빨간색 그라데이션
          Colors.red[800]!,
          Colors.red[700]!,
        ];
    }
  }

  // 검증 상태에 따른 아이콘 색상 반환
  Color _getAccentColor() {
    switch (_verificationState) {
      case VerificationState.pending:
        return Colors.grey;
      case VerificationState.verified:
        return Colors.greenAccent;
      case VerificationState.failed:
        return Colors.redAccent;
    }
  }

  // 검증 상태에 따른 제목 텍스트 반환
  String _getTitleText() {
    switch (_verificationState) {
      case VerificationState.pending:
        return "🔘 실시간 문자 검증 중";
      case VerificationState.verified:
        return "✅ 실시간 문자 확인됨";
      case VerificationState.failed:
        return "❌ 수신전화: 검증되지 않음!";
    }
  }

  // 검증 상태에 따른 아이콘 반환
  IconData _getStatusIcon() {
    switch (_verificationState) {
      case VerificationState.pending:
        return Icons.hourglass_empty;
      case VerificationState.verified:
        return Icons.verified_user;
      case VerificationState.failed:
        return Icons.warning;
    }
  }

  // 검증 상태에 따른 메시지 반환
  String _getStatusMessage() {
    switch (_verificationState) {
      case VerificationState.pending:
        return "문자 대기중";
      case VerificationState.verified:
        return "문자 수신됨";
      case VerificationState.failed:
        return "검증 실패!";
    }
  }

  // 검증 상태에 따른 설명 텍스트 반환
  String _getDescriptionText() {
    switch (_verificationState) {
      case VerificationState.pending:
        return "실시간 문자 메시지를 기다리는 중입니다...";
      case VerificationState.verified:
        return "유효한 링크가 포함된 문자가 확인되었습니다";
      case VerificationState.failed:
        return "${OverlayConstants.verificationTimeout.inSeconds}초 내에 유효한 문자를 받지 못했습니다";
    }
  }

  void callBackFunction(String tag) {
    debugPrint("Got tag $tag");
    mainAppPort ??= IsolateNameServer.lookupPortByName(
      OverlayConstants.mainAppPort,
    );
    mainAppPort?.send('Date: ${DateTime.now()}');
    mainAppPort?.send(tag);

    // 터치로 닫힐 때 메인 앱에 알림
    if (tag.contains("Touch Close")) {
      mainAppPort?.send('OVERLAY_CLOSED_BY_TOUCH');
    }
  }


  Widget overlay() {
    return GestureDetector(
      // 바깥 영역 터치 시 닫기
      onTap: () {
        log('[Overlay] 바깥 영역 터치 - 오버레이 닫기');
        callBackFunction("Outside Close");
        SystemAlertWindow.closeSystemWindow(prefMode: prefMode);
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.8), // 더 진한 배경
        child: SafeArea(
          child: GestureDetector(
            // 내부 컨테이너 터치 시에는 닫히지 않도록
            onTap: () {
              log('[Overlay] 내부 컨테이너 터치 - 유지');
            },
            child: AnimatedContainer(
              duration: OverlayConstants.overlayAnimationDuration,
              curve: Curves.easeInOut,
              width: double.infinity,
              height: double.infinity, // 전체 화면
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _getGradientColors(),
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _getAccentColor().withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getAccentColor().withValues(alpha: 0.4),
                    blurRadius: 25,
                    spreadRadius: 5,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 메인 콘텐츠
                  Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // 헤더
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha:0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha:0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          colors: [_getAccentColor(), _getAccentColor().withValues(alpha: 0.7)],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _getAccentColor().withValues(alpha: 0.6),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _getStatusIcon(),
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _getTitleText(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha:0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha:0.2)),
                                  ),
                                  child: Text(
                                    _currentPhoneNumber ?? "전화번호 확인 중...",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // SMS 검증 섹션
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                AnimatedContainer(
                                  duration: OverlayConstants.iconAnimationDuration,
                                  curve: Curves.easeInOut,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _verificationState == VerificationState.verified
                                        ? [
                                            Colors.green.withValues(alpha:0.3),
                                            Colors.green.withValues(alpha:0.1),
                                          ]
                                        : _verificationState == VerificationState.pending
                                        ? [
                                            Colors.grey.withValues(alpha:0.3),
                                            Colors.grey.withValues(alpha:0.1),
                                          ]
                                        : [
                                            Colors.red.withValues(alpha:0.3),
                                            Colors.red.withValues(alpha:0.1),
                                          ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _verificationState == VerificationState.verified
                                        ? Colors.greenAccent.withValues(alpha:0.4)
                                        : _verificationState == VerificationState.pending
                                        ? Colors.grey.withValues(alpha: 0.4)
                                        : Colors.redAccent.withValues(alpha:0.4),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      AnimatedSwitcher(
                                        duration: OverlayConstants.scaleAnimationDuration,
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(scale: animation, child: child);
                                        },
                                        child: Icon(
                                          _getStatusIcon(),
                                          key: ValueKey(_verificationState.toString()),
                                          color: _getAccentColor(),
                                          size: 48,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      AnimatedSwitcher(
                                        duration: OverlayConstants.animationDuration,
                                        child: Text(
                                          _getStatusMessage(),
                                          key: ValueKey(_verificationState.toString()),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // URL 링크 표시 영역
                                      if (_verificationState == VerificationState.verified && _lastSmsUrls.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.greenAccent.withValues(alpha: 0.5),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "발견된 링크:",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.greenAccent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              ...(_lastSmsUrls.take(3).map((url) => Padding(
                                                padding: const EdgeInsets.only(bottom: 2),
                                                child: Text(
                                                  url,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.lightBlueAccent,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ))),
                                              if (_lastSmsUrls.length > 3)
                                                Text(
                                                  "... 및 ${_lastSmsUrls.length - 3}개 더",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white.withValues(alpha: 0.7),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ] else if (_verificationState == VerificationState.verified && _lastSmsUrls.isEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.orangeAccent.withValues(alpha: 0.5),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            "이 문자에는 링크가 포함되지 않았습니다",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.orangeAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      AnimatedSwitcher(
                                        duration: OverlayConstants.animationDuration,
                                        child: Text(
                                          _getDescriptionText(),
                                          key: ValueKey("${_verificationState}_desc"),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white.withValues(alpha:0.8),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Spacer(),

                                // 하단 버튼들
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Center(
                                    child:
                                      // 닫기 버튼 (중앙)
                                      GestureDetector(
                                        onTap: () {
                                          log('[Overlay] 닫기 버튼 클릭 - 오버레이 닫기');
                                          callBackFunction("Close Button");
                                          SystemAlertWindow.closeSystemWindow(prefMode: prefMode);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.95),
                                            borderRadius: BorderRadius.circular(25),
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Text(
                                            "닫기",
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // X 버튼
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        log('[Overlay] X 버튼 클릭 - 오버레이 닫기');
                        callBackFunction("X Button Close");
                        SystemAlertWindow.closeSystemWindow(prefMode: prefMode);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.black54,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  SystemWindowPrefMode prefMode = SystemWindowPrefMode.OVERLAY;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: overlay(),
    );
  }
}