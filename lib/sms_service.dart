import 'dart:async';
import 'dart:developer';
import 'package:smswatcher/smswatcher.dart';

class SmsMessage {
  final String address;
  final String body;
  final DateTime date;
  final bool isIncoming;
  final String id;

  SmsMessage({
    required this.address,
    required this.body,
    required this.date,
    required this.isIncoming,
    required this.id,
  });

  factory SmsMessage.fromSmsWatcher(Map<String, dynamic> sms) {
    return SmsMessage(
      address: sms['sender'] ?? sms['address'] ?? '',
      body: sms['body'] ?? sms['message'] ?? '',
      date: DateTime.tryParse(sms['date']?.toString() ?? '') ?? DateTime.now(),
      isIncoming: sms['type'] != 'sent', // smswatcher에서 받은 SMS는 기본적으로 incoming
      id: sms['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  @override
  String toString() {
    return 'SmsMessage{address: $address, body: $body, date: $date, isIncoming: $isIncoming}';
  }
}

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  StreamController<SmsMessage>? _smsStreamController;
  Stream<SmsMessage>? _smsStream;
  StreamSubscription? _smsWatcherSubscription;

  /// SMS 스트림 가져오기
  Stream<SmsMessage> get smsStream {
    _smsStreamController ??= StreamController<SmsMessage>.broadcast();
    _smsStream ??= _smsStreamController!.stream;

    // SMS 감지 시작
    _startSmsMonitoring();
    return _smsStream!;
  }

  /// 특정 전화번호의 SMS 기록 가져오기 (발신자가 나에게 보낸 것만)
  Future<List<SmsMessage>> getSmsHistory(String phoneNumber, {int limit = 10}) async {
    try {
      log('[SMS Service] Getting SMS history from caller: $phoneNumber');

      // smswatcher로 모든 SMS 가져오기
      final smswatcher = Smswatcher();
      final allSms = await smswatcher.getAllSMS();

      if (allSms == null || allSms.isEmpty) {
        log('[SMS Service] No SMS found');
        return [];
      }

      // 전화번호 정규화
      String normalizePhone(String phone) {
        return phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '').replaceAll('82', '0');
      }

      final normalizedTarget = normalizePhone(phoneNumber);
      log('[SMS Service] Normalized target: $normalizedTarget');

      // 해당 번호에서 나에게 온 SMS만 필터링 (발신자만)
      final filteredSms = allSms.where((sms) {
        final sender = sms['sender'] ?? sms['address'] ?? '';
        final normalizedSender = normalizePhone(sender);

        // 발신자 번호가 타겟 번호와 일치하는지 확인
        bool isMatch = normalizedSender.endsWith(normalizedTarget.substring(normalizedTarget.length > 4 ? normalizedTarget.length - 4 : 0)) ||
                      normalizedTarget.endsWith(normalizedSender.substring(normalizedSender.length > 4 ? normalizedSender.length - 4 : 0)) ||
                      normalizedSender == normalizedTarget;

        if (isMatch) {
          log('[SMS Service] Found matching SMS from: $sender (normalized: $normalizedSender)');
        }

        return isMatch;
      }).toList();

      // 날짜순 정렬 (최신순)
      filteredSms.sort((a, b) {
        final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      final messages = filteredSms.take(limit).map((sms) => SmsMessage.fromSmsWatcher(sms)).toList();

      log('[SMS Service] Found ${messages.length} messages from caller $phoneNumber');
      return messages;
    } catch (e) {
      log('[SMS Service] Error getting SMS history: $e');
      return [];
    }
  }

  /// 모든 SMS 가져오기 (최근 순)
  Future<List<SmsMessage>> getAllSms({int limit = 50}) async {
    try {
      log('[SMS Service] Getting all SMS messages');

      final smswatcher = Smswatcher();
      final allSms = await smswatcher.getAllSMS();
      final messages = (allSms ?? [])
          .take(limit)
          .map((sms) => SmsMessage.fromSmsWatcher(sms))
          .toList();

      log('[SMS Service] Found ${messages.length} total messages');
      return messages;
    } catch (e) {
      log('[SMS Service] Error getting all SMS: $e');
      return [];
    }
  }

  /// SMS에서 URL 링크 추출
  List<String> extractUrlsFromText(String text) {
    log('[SMS Service] Extracting URLs from text: $text');

    // URL 패턴 정규식 - http(s), www, 일반 도메인 패턴 모두 포함
    final urlPattern = RegExp(
      r'(https?://[^\s]+|www\.[^\s]+|[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(?:\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+[^\s]*)',
      caseSensitive: false,
    );

    final matches = urlPattern.allMatches(text);
    final urls = matches.map((match) => match.group(0)!).toList();

    // 중복 제거
    final uniqueUrls = urls.toSet().toList();

    log('[SMS Service] Extracted ${uniqueUrls.length} URLs: $uniqueUrls');
    return uniqueUrls;
  }

  /// SMS 모니터링 시작
  void _startSmsMonitoring() {
    if (_smsWatcherSubscription != null) return;

    log('[SMS Service] Starting SMS monitoring with SmsWatcher');

    final smswatcher = Smswatcher();
    _smsWatcherSubscription = smswatcher.getStreamOfSMS().listen((smsData) {
      try {
        log('[SMS Service] New SMS received: $smsData');

        final message = SmsMessage.fromSmsWatcher(smsData);

        // URL 추출 및 로깅
        final urls = extractUrlsFromText(message.body);
        if (urls.isNotEmpty) {
          log('[SMS URL] Found URLs in SMS from ${message.address}:');
          for (String url in urls) {
            log('[SMS URL] - $url');
          }
        }

        _smsStreamController?.add(message);
      } catch (e) {
        log('[SMS Service] Error processing received SMS: $e');
      }
    });
  }

  /// SMS 모니터링 중지
  void stopSmsMonitoring() {
    _smsWatcherSubscription?.cancel();
    _smsWatcherSubscription = null;
    _smsStreamController?.close();
    _smsStreamController = null;
    _smsStream = null;
    log('[SMS Service] SMS monitoring stopped');
  }

  void dispose() {
    stopSmsMonitoring();
  }
}