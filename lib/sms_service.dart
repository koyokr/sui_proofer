import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:smswatcher/smswatcher.dart';
import 'config/app_constants.dart';
import 'utils/phone_number_utils.dart';

class SuiVerificationResult {
  final bool isValid;
  final String? objectAddress;
  final String? submitterAddress;
  final String? interestedProduct;
  final String? consentCollector;
  final String? consultationTopic;
  final String? timestamp;

  SuiVerificationResult({
    required this.isValid,
    this.objectAddress,
    this.submitterAddress,
    this.interestedProduct,
    this.consentCollector,
    this.consultationTopic,
    this.timestamp,
  });
}

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
      isIncoming: sms['type'] != 'sent', // SMS received from smswatcher is incoming by default
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

  /// Get SMS stream
  Stream<SmsMessage> get smsStream {
    _smsStreamController ??= StreamController<SmsMessage>.broadcast();
    _smsStream ??= _smsStreamController!.stream;

    // Start SMS detection
    _startSmsMonitoring();
    return _smsStream!;
  }

  /// Get SMS history for specific phone number (only from sender to me)
  Future<List<SmsMessage>> getSmsHistory(String phoneNumber, {int limit = AppConstants.defaultHistoryLimit}) async {
    try {
      log('[SMS Service] Getting SMS history from caller: $phoneNumber');

      // Get all SMS with smswatcher
      final smswatcher = Smswatcher();
      final allSms = await smswatcher.getAllSMS();

      if (allSms == null || allSms.isEmpty) {
        log('[SMS Service] No SMS found');
        return [];
      }

      final normalizedTarget = PhoneNumberUtils.normalize(phoneNumber);
      log('[SMS Service] Normalized target: $normalizedTarget');

      // Filter only SMS from that number to me (sender only)
      final filteredSms = allSms.where((sms) {
        final sender = sms['sender'] ?? sms['address'] ?? '';
        final isMatch = PhoneNumberUtils.isMatching(sender, phoneNumber);

        if (isMatch) {
          log('[SMS Service] Found matching SMS from: $sender');
        }

        return isMatch;
      }).toList();

      // Sort by date (newest first)
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

  /// Get all SMS (recent first)
  Future<List<SmsMessage>> getAllSms({int limit = AppConstants.defaultSmsLimit}) async {
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

  /// Extract Sui object addresses with timestamps from SMS
  List<Map<String, String>> extractSuiAddressesFromText(String text) {
    log('[SMS Service] Extracting Sui addresses with timestamps from text: $text');

    // New pattern: 0x[a-fA-F0-9]{64}_\d+ (no parentheses)
    final suiPattern = RegExp(
      r'0x[a-fA-F0-9]{64}_\d+',
      caseSensitive: false,
    );

    final matches = suiPattern.allMatches(text);
    final addressData = matches.map((match) {
      final fullMatch = match.group(0)!;
      // Split by underscore to get address and timestamp
      final parts = fullMatch.split('_');

      return {
        'address': parts.isNotEmpty ? parts[0] : '',
        'timestamp': parts.length > 1 ? parts[1] : '',
      };
    }).toList();

    // Remove duplicates based on address
    final uniqueData = <String, Map<String, String>>{};
    for (final data in addressData) {
      if (data['address']!.isNotEmpty) {
        uniqueData[data['address']!] = data;
      }
    }

    final result = uniqueData.values.toList();
    log('[SMS Service] Extracted ${result.length} Sui address-timestamp pairs: $result');
    return result;
  }

  /// Verify Sui object address by calling Sui API with timestamp matching
  Future<SuiVerificationResult> verifySuiAddressWithDetails(String address, String timestamp) async {
    try {
      log('[SMS Service] ===== STARTING VERIFICATION =====');
      log('[SMS Service] Verifying Sui address: $address');
      log('[SMS Service] Target timestamp: $timestamp');

      const expectedSubmitter = '0x8b89d808ce6e1c5a560354c264f7ff4166e05d138b8534fcae78058acfe298f4';

      final response = await http.post(
        Uri.parse('https://fullnode.testnet.sui.io'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'sui_getObject',
          'params': [
            address,
            {'showContent': true}
          ]
        }),
      );

      if (response.statusCode != 200) {
        log('[SMS Service] HTTP error ${response.statusCode}: ${response.body}');
        return SuiVerificationResult(isValid: false);
      }

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

      // Check if response has expected structure
      if (!jsonData.containsKey('result')) {
        log('[SMS Service] No result field in response');
        return SuiVerificationResult(isValid: false);
      }

      final result = jsonData['result'] as Map<String, dynamic>?;
      if (result == null || !result.containsKey('data')) {
        log('[SMS Service] No data field in result');
        return SuiVerificationResult(isValid: false);
      }

      final data = result['data'] as Map<String, dynamic>?;
      if (data == null || !data.containsKey('content')) {
        log('[SMS Service] No content field in data');
        return SuiVerificationResult(isValid: false);
      }

      final content = data['content'] as Map<String, dynamic>?;
      if (content == null || !content.containsKey('fields')) {
        log('[SMS Service] No fields field in content');
        return SuiVerificationResult(isValid: false);
      }

      final fields = content['fields'] as Map<String, dynamic>?;
      if (fields == null || !fields.containsKey('forms')) {
        log('[SMS Service] No forms field in fields');
        return SuiVerificationResult(isValid: false);
      }

      final forms = fields['forms'] as List<dynamic>?;
      if (forms == null || forms.isEmpty) {
        log('[SMS Service] Forms list is empty or null');
        return SuiVerificationResult(isValid: false);
      }

      log('[SMS Service] Found ${forms.length} forms in response');

      // Find form with matching timestamp (search from end for latest entries)
      Map<String, dynamic>? matchingForm;
      for (int i = forms.length - 1; i >= 0; i--) {
        final form = forms[i];
        final formMap = form as Map<String, dynamic>?;
        if (formMap != null && formMap.containsKey('fields')) {
          final fields = formMap['fields'] as Map<String, dynamic>?;
          if (fields != null && fields.containsKey('timestamp')) {
            final formTimestamp = fields['timestamp']?.toString();
            log('[SMS Service] Checking form $i: timestamp=$formTimestamp vs target=$timestamp');
            if (formTimestamp == timestamp) {
              log('[SMS Service] ✅ FOUND MATCHING FORM at index $i');
              matchingForm = fields;
              break;
            }
          }
        }
      }

      if (matchingForm == null) {
        log('[SMS Service] No form found with matching timestamp: $timestamp');
        return SuiVerificationResult(isValid: false);
      }

      // Check submitter in matching form
      if (!matchingForm.containsKey('submitter')) {
        log('[SMS Service] Matching form has no submitter field');
        return SuiVerificationResult(isValid: false);
      }

      final submitter = matchingForm['submitter'] as String?;
      final isValid = submitter == expectedSubmitter;

      log('[SMS Service] Submitter: $submitter, Expected: $expectedSubmitter, Valid: $isValid');

      // Extract additional form data
      final interestedProduct = matchingForm['interested_product']?.toString();
      final consentCollector = matchingForm['consent_collector']?.toString();
      final consultationTopic = matchingForm['consultation_topic']?.toString();

      return SuiVerificationResult(
        isValid: isValid,
        objectAddress: address,
        submitterAddress: submitter,
        interestedProduct: interestedProduct,
        consentCollector: consentCollector,
        consultationTopic: consultationTopic,
        timestamp: timestamp,
      );

    } catch (e) {
      log('[SMS Service] Error verifying Sui address: $e');
      return SuiVerificationResult(isValid: false);
    }
  }

  /// Verify Sui object address by calling Sui API (backward compatibility)
  Future<bool> verifySuiAddress(String address) async {
    // For backward compatibility, use empty timestamp
    final result = await verifySuiAddressWithDetails(address, '');
    return result.isValid;
  }

  /// Start SMS monitoring
  void _startSmsMonitoring() {
    if (_smsWatcherSubscription != null) return;

    log('[SMS Service] Starting SMS monitoring with SmsWatcher');

    final smswatcher = Smswatcher();
    _smsWatcherSubscription = smswatcher.getStreamOfSMS().listen((smsData) {
      try {
        log('[SMS Service] New SMS received: $smsData');

        final message = SmsMessage.fromSmsWatcher(smsData);

        // Sui address extraction and logging
        final addressData = extractSuiAddressesFromText(message.body);
        if (addressData.isNotEmpty) {
          log('[SMS Sui] Found Sui address-timestamp pairs in SMS from ${message.address}:');
          for (final data in addressData) {
            log('[SMS Sui] - Address: ${data['address']}, Timestamp: ${data['timestamp']}');
          }
        }

        _smsStreamController?.add(message);
      } catch (e) {
        log('[SMS Service] Error processing received SMS: $e');
      }
    });
  }

  /// Stop SMS monitoring
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