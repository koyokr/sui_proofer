# Real-time SMS Overlay Display App
**수신 전화 시 실시간 SMS 내용을 오버레이로 표시하는 앱**

## 📋 프로젝트 개요
### 목표
전화 수신 시 화면에 오버레이를 표시하고, 실시간으로 SMS 내용을 보여주는 Android 앱

### 현재 기능
**✅ 완료**: 실시간 SMS 내용 표시 오버레이 시스템
- 전화 수신 감지 및 오버레이 표시
- 실시간 SMS 수신 및 내용 표시
- 깔끔한 UI와 최적화된 코드 구조

### 환경 정보
- **Flutter**: 3.35.4 (stable)
- **Android API**: 35 (Android 15)
- **디바이스**: Samsung SM S931N
- **주요 패키지**: system_alert_window ^2.0.7, phone_state ^3.0.0, smswatcher ^0.0.3

## 🛠️ 개발 워크플로
### 개발 프로세스
1. **계획**: TodoWrite 도구로 작업 계획 수립
2. **패키지 검색**: 구현 전 기존 솔루션 탐색
3. **선택지 논의**: 여러 옵션이 있을 때 사용자와 협의
4. **코드 작성**: 기존 코드 스타일 및 패턴 준수
5. **품질 검증**: **flutter analyze 먼저 실행** → dart fix 적용
6. **테스트**: flutter build apk --debug 실행 및 빌드 성공 여부 확인

### 코드 품질 관리
- **필수**: 코드 수정 후 즉시 `flutter analyze` 실행
- **목표**: analyze 경고 0개 유지 (deprecated, unused code, async gaps 등)
- **권장**: `.withOpacity()` → `.withValues(alpha:)` 최신 API 사용
- **로깅**: `print()` 대신 `debugPrint()` 사용
- **BuildContext**: async gap에서 `context.mounted` 체크 필수

### 핵심 파일
- `lib/main.dart`: 메인 앱 UI, 통계 표시 및 실시간 업데이트
- `lib/phone_service.dart`: 전화 상태 감지, 오버레이 관리, 통계 처리
- `lib/custom_overlay.dart`: 전체화면 오버레이 UI, SMS 검증 상태 표시
- `lib/sms_service.dart`: 실시간 SMS 감지 및 전화번호 매칭
- `lib/statistics_service.dart`: 검증/미검증 전화 통계 저장
- `lib/permission_service.dart`: Android 권한 관리

## ✅ 구현 완료 기능

### 전화 감지 및 오버레이
- ✅ 실시간 전화 수신 감지 (PhoneState.stream)
- ✅ 전체화면 오버레이 표시
- ✅ 터치로 오버레이 닫기
- ✅ 전화번호 정보 표시 및 실시간 업데이트

### SMS 검증 시스템
- ✅ 실시간 SMS 수신 감지 (smswatcher)
- ✅ 전화번호와 SMS 발신번호 자동 매칭
- ✅ 검증 상태 시각적 표시 (빨강→초록 변화)
- ✅ 애니메이션 효과 (AnimatedContainer, AnimatedSwitcher)

### 통계 및 상태 관리
- ✅ 검증/미검증 전화 통계 추적 (SharedPreferences)
- ✅ 실시간 UI 업데이트 (콜백 시스템)
- ✅ 오버레이 종료 시 최종 통계 업데이트
- ✅ 앱 실행 중 즉시 통계 반영

### 핵심 코드 패턴
```dart
// 전체화면 오버레이 표시
await SystemAlertWindow.showSystemWindow(
  height: -1, // 전체 화면 높이
  width: -1,  // 전체 화면 너비
  gravity: SystemWindowGravity.TOP,
  prefMode: SystemWindowPrefMode.OVERLAY,
  layoutParamFlags: [], // 터치 이벤트 활성화
);

// 실시간 SMS 검증
_smsService.smsStream.listen((sms) {
  if (_isMatchingPhoneNumber(sms.address, _currentPhoneNumber!)) {
    setState(() { _isVerified = true; });
    _phoneService.updateToVerifiedCall();
  }
});

// 최신 Color API 사용
color: Colors.black.withValues(alpha: 0.8) // withOpacity 대신
```

## 🔧 코드 스타일 및 규칙
- **권한 관리**: PhoneService 싱글톤 패턴 사용
- **상태 관리**: 오버레이 표시 상태 추적
- **이벤트 처리**: isolate 간 메시지 전달
- **에러 처리**: try-catch와 디버그 로그 활용
- **타이머 관리**: 자동 닫기 및 수동 취소 로직

## 📦 주요 패키지
```yaml
dependencies:
  system_alert_window: 2.0.7   # 시스템 오버레이 표시
  phone_state: ^3.0.0          # 전화 상태 감지
  smswatcher: ^0.0.3           # 실시간 SMS 감지
  shared_preferences: ^2.3.3   # 로컬 데이터 저장
  permission_handler: ^12.0.1  # 권한 관리
```

## 🚫 제한사항
- flutter_local_notifications 사용 금지 (알림바만 표시)
- 앱 내부 다이얼로그/위젯 사용 금지
- 시스템 레벨 오버레이만 사용
- Android 15 (API 35) 호환성 필수

## 🎯 향후 개선 가능성
1. **연락처 연동**: 발신자 이름 표시
2. **설정 화면**: 민감도 조절, 테마 변경
3. **통계 확장**: 일별/월별 리포트
4. **성능 최적화**: 배터리 사용량 개선

## 📝 문제 해결 히스토리
### 초기 개발 단계
- **터치 이벤트 미작동**: `layoutParamFlags` 설정으로 해결
- **타이머 충돌**: isolate 메시징으로 상태 동기화 해결
- **권한 문제**: `SystemWindowPrefMode.OVERLAY` 사용으로 해결
- **앱 크래시**: `double.maxFinite.toInt()` → 고정 크기 사용으로 해결

### 기능 개선 단계
- **통계 중복 업데이트**: 모든 전화가 미검증으로 카운트 → 오버레이 종료 시 최종 판단으로 수정
- **실시간 업데이트 미작동**: 콜백 시스템 구축으로 즉시 UI 반영
- **코드 품질 이슈**: Flutter analyze 34개 → 0개 (deprecated API, unused code 정리)

### 학습된 베스트 프랙티스
- **통계 업데이트**: 이벤트 발생 시점이 아닌 완료 시점에 처리
- **UI 반영**: SharedPreferences + 콜백으로 실시간 상태 동기화
- **코드 품질**: 수정 후 즉시 `flutter analyze` 실행 필수