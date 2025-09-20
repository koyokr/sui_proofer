import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:smswatcher/smswatcher.dart';
import 'config/app_constants.dart';
import 'utils/phone_number_utils.dart';
import 'services/submitter_service.dart';

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

      // Get all SMS with smswatcher
      final smswatcher = Smswatcher();
      final allSms = await smswatcher.getAllSMS();

      if (allSms == null || allSms.isEmpty) {
        return [];
      }


      // Filter only SMS from that number to me (sender only)
      final filteredSms = allSms.where((sms) {
        final sender = sms['sender'] ?? sms['address'] ?? '';
        final isMatch = PhoneNumberUtils.isMatching(sender, phoneNumber);


        return isMatch;
      }).toList();

      // Sort by date (newest first)
      filteredSms.sort((a, b) {
        final dateA = DateTime.tryParse(a['date']?.toString() ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['date']?.toString() ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      final messages = filteredSms.take(limit).map((sms) => SmsMessage.fromSmsWatcher(sms)).toList();

      return messages;
    } catch (e) {
      log('[SMS] History error: $e');
      return [];
    }
  }

  /// Get all SMS (recent first)
  Future<List<SmsMessage>> getAllSms({int limit = AppConstants.defaultSmsLimit}) async {
    try {

      final smswatcher = Smswatcher();
      final allSms = await smswatcher.getAllSMS();
      final messages = (allSms ?? [])
          .take(limit)
          .map((sms) => SmsMessage.fromSmsWatcher(sms))
          .toList();

      return messages;
    } catch (e) {
      log('[SMS] Get all error: $e');
      return [];
    }
  }

  /// Extract Sui object addresses with timestamps from SMS
  List<Map<String, String>> extractSuiAddressesFromText(String text) {

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
    return result;
  }

  /// Verify Sui object address by calling Sui API with timestamp matching
  Future<SuiVerificationResult> verifySuiAddressWithDetails(String address, String timestamp) async {
    try {
      final submitterService = SubmitterService();
      final expectedSubmitter = await submitterService.getSubmitter();

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
        log('[SMS] HTTP error: ${response.statusCode}');
        return SuiVerificationResult(isValid: false);
      }

      final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

      // Check if response has expected structure
      if (!jsonData.containsKey('result')) {
        return SuiVerificationResult(isValid: false);
      }

      final result = jsonData['result'] as Map<String, dynamic>?;
      if (result == null || !result.containsKey('data')) {
        return SuiVerificationResult(isValid: false);
      }

      final data = result['data'] as Map<String, dynamic>?;
      if (data == null || !data.containsKey('content')) {
        return SuiVerificationResult(isValid: false);
      }

      final content = data['content'] as Map<String, dynamic>?;
      if (content == null || !content.containsKey('fields')) {
        return SuiVerificationResult(isValid: false);
      }

      final fields = content['fields'] as Map<String, dynamic>?;
      if (fields == null || !fields.containsKey('forms')) {
        return SuiVerificationResult(isValid: false);
      }

      final forms = fields['forms'] as List<dynamic>?;
      if (forms == null || forms.isEmpty) {
        return SuiVerificationResult(isValid: false);
      }


      // Find form with matching timestamp (search from end for latest entries)
      Map<String, dynamic>? matchingForm;
      for (int i = forms.length - 1; i >= 0; i--) {
        final form = forms[i];
        final formMap = form as Map<String, dynamic>?;
        if (formMap != null && formMap.containsKey('fields')) {
          final fields = formMap['fields'] as Map<String, dynamic>?;
          if (fields != null && fields.containsKey('timestamp')) {
            final formTimestamp = fields['timestamp']?.toString();
            if (formTimestamp == timestamp) {
              matchingForm = fields;
              break;
            }
          }
        }
      }

      if (matchingForm == null) {
        return SuiVerificationResult(isValid: false);
      }

      // Check submitter in matching form
      if (!matchingForm.containsKey('submitter')) {
        return SuiVerificationResult(isValid: false);
      }

      final submitter = matchingForm['submitter'] as String?;
      final isValid = submitter == expectedSubmitter;


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
      log('[SMS] Verify error: $e');
      return SuiVerificationResult(
        isValid: false,
        objectAddress: address,
        submitterAddress: null,
      );
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


    final smswatcher = Smswatcher();
    _smsWatcherSubscription = smswatcher.getStreamOfSMS().listen((smsData) {
      try {

        final message = SmsMessage.fromSmsWatcher(smsData);

        // Sui address extraction and logging
        final addressData = extractSuiAddressesFromText(message.body);
        if (addressData.isNotEmpty) {
          log('[SMS] Found ${addressData.length} Sui addresses');
        }

        _smsStreamController?.add(message);
      } catch (e) {
        log('[SMS] Process error: $e');
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
  }

  void dispose() {
    stopSmsMonitoring();
  }
}