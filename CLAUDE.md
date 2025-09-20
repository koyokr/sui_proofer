# Real-time SMS Overlay Display App
**Android app showing real-time SMS content overlay during incoming calls**

## 📋 Project Overview
### Goal
Android app that displays system overlay during incoming calls and shows real-time SMS content

### Current Features
**✅ Completed**: Real-time SMS content display overlay system
- Incoming call detection and overlay display
- Real-time SMS reception and content display
- Clean UI with optimized code structure

### Environment
- **Flutter**: 3.35.4 (stable)
- **Android API**: 35 (Android 15)
- **Device**: Samsung SM S931N
- **Key Packages**: system_alert_window ^2.0.7, phone_state ^3.0.0, smswatcher ^0.0.3

## 🛠️ Development Workflow
### Development Process
1. **Plan**: Use TodoWrite tool for task planning
2. **Package Search**: Explore existing solutions before implementation
3. **Discuss Options**: Consult with user when multiple options exist
4. **Code**: Follow existing code style and patterns
5. **Quality Check**: **Code → dart fix → flutter analyze** (mandatory order)
6. **Test**: Run flutter build apk --debug and verify build success

### Code Quality Management
- **Mandatory**: Run `dart fix` then `flutter analyze` after every code change
- **Goal**: Maintain 0 analyze warnings (deprecated, unused code, async gaps, etc.)
- **Recommended**: Use `.withValues(alpha:)` instead of `.withOpacity()`
- **Logging**: Use `debugPrint()` instead of `print()`
- **BuildContext**: Always check `context.mounted` in async gaps

### Core Files
- `lib/main.dart`: Main app UI, statistics display and real-time updates
- `lib/phone_service.dart`: Phone state detection, overlay management, statistics handling
- `lib/custom_overlay.dart`: Full-screen overlay UI, SMS verification status display
- `lib/sms_service.dart`: Real-time SMS detection and phone number matching
- `lib/statistics_service.dart`: Verified/unverified call statistics storage
- `lib/permission_service.dart`: Android permission management

## ✅ Implemented Features

### Call Detection & Overlay
- ✅ Real-time incoming call detection (PhoneState.stream)
- ✅ Full-screen overlay display
- ✅ Touch to close overlay
- ✅ Phone number info display with real-time updates

### SMS Verification System
- ✅ Real-time SMS reception detection (smswatcher)
- ✅ Automatic phone number and SMS sender matching
- ✅ Sui blockchain object address pattern recognition (`0x[a-fA-F0-9]{64}_\d+`)
- ✅ Sui API integration with timestamp-based form matching
- ✅ Visual verification status display (red→green transition)
- ✅ Animation effects (AnimatedContainer, AnimatedSwitcher)

### Statistics & State Management
- ✅ Verified/unverified call statistics tracking (SharedPreferences)
- ✅ Real-time UI updates (callback system)
- ✅ Final statistics update on overlay close
- ✅ Immediate statistics reflection during app runtime

### Core Code Patterns
```dart
// Full-screen overlay display
await SystemAlertWindow.showSystemWindow(
  height: -1, // Full screen height
  width: -1,  // Full screen width
  gravity: SystemWindowGravity.TOP,
  prefMode: SystemWindowPrefMode.OVERLAY,
  layoutParamFlags: [], // Enable touch events
);

// Sui blockchain verification pattern
final suiPattern = RegExp(r'0x[a-fA-F0-9]{64}_\d+');
final addressData = suiPattern.allMatches(sms.body).map((match) {
  final parts = match.group(0)!.split('_');
  return {'address': parts[0], 'timestamp': parts[1]};
}).toList();

// Sui API verification with timestamp matching
final response = await http.post(
  Uri.parse('https://fullnode.testnet.sui.io'),
  body: jsonEncode({
    'method': 'sui_getObject',
    'params': [address, {'showContent': true}]
  }),
);

// Modern Color API usage
color: Colors.black.withValues(alpha: 0.8) // instead of withOpacity
```

## 🔧 Code Style & Rules
- **Permission Management**: PhoneService singleton pattern
- **State Management**: Overlay display state tracking
- **Event Handling**: Inter-isolate message passing
- **Error Handling**: try-catch with debug logging
- **Timer Management**: Auto-close and manual cancel logic

## 📦 Key Packages
```yaml
dependencies:
  system_alert_window: 2.0.7   # System overlay display
  phone_state: ^3.0.0          # Phone state detection
  smswatcher: ^0.0.3           # Real-time SMS detection
  shared_preferences: ^2.3.3   # Local data storage
  permission_handler: ^12.0.1  # Permission management
  http: ^1.5.0                 # Sui blockchain API calls
```

## 🚫 Constraints
- No flutter_local_notifications (only shows notification bar)
- No in-app dialogs/widgets
- System-level overlay only
- Android 15 (API 35) compatibility required
  - Don't use build.gradle, Use build.gradle.kts

## 🎯 Future Improvements
1. **Contact Integration**: Display caller names
2. **Settings Screen**: Sensitivity adjustment, theme changes
3. **Extended Statistics**: Daily/monthly reports
4. **Performance Optimization**: Improve battery usage

## 📝 Problem Solving History
### Initial Development
- **Touch Events Not Working**: Fixed with `layoutParamFlags` configuration
- **Timer Conflicts**: Resolved with isolate messaging for state sync
- **Permission Issues**: Fixed using `SystemWindowPrefMode.OVERLAY`
- **App Crashes**: Fixed `double.maxFinite.toInt()` → used fixed sizes

### Feature Enhancement
- **Duplicate Statistics**: All calls counted as unverified → Fixed with final judgment on overlay close
- **Real-time Updates Not Working**: Built callback system for immediate UI reflection
- **Code Quality Issues**: Flutter analyze 34 → 0 warnings (cleaned deprecated API, unused code)

### Sui Blockchain Integration
- **HTTP Link → Sui Address**: Changed SMS pattern from HTTP URLs to `0x[a-fA-F0-9]{64}_\d+`
- **Pattern Recognition Issues**: Fixed regex from `\(0x...\)_\(\d+\)` → `0x[a-fA-F0-9]{64}_\d+`
- **Timestamp Matching**: Implemented form search by timestamp (reverse iteration for latest entries)
- **API Integration**: Added Sui testnet fullnode API calls for object verification
- **UI Improvements**: Card-based design with icons, compact spacing, fixed "Sui Proofer" branding

### Latest UI Enhancements (2025-09-21)
- **Card Design**: Replaced text lists with individual card components with icons
- **Data Display**: Shows interested_product, consent_collector, consultation_topic, timestamp
- **Branding**: Fixed title to "Sui Proofer" across all verification states
- **Spacing Optimization**: Reduced margins and padding for compact design
- **Typography**: Optimized font sizes for better readability in overlay context

### Best Practices Learned
- **Statistics Updates**: Process at completion point, not at event occurrence
- **UI Reflection**: Real-time state sync with SharedPreferences + callbacks
- **Code Quality**: **Code → dart fix → flutter analyze** workflow mandatory
- **Blockchain Integration**: Always validate API responses and handle edge cases
- **Pattern Matching**: Use simple string operations over complex regex when possible
- **Debugging**: Enhanced logging for complex verification workflows