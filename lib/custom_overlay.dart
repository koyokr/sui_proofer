import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:system_alert_window/system_alert_window.dart';
import 'sms_service.dart';
import 'phone_service.dart';
import 'config/app_constants.dart';
import 'models/verification_state.dart';
import 'utils/phone_number_utils.dart';


class CustomOverlay extends StatefulWidget {
  const CustomOverlay({super.key});

  @override
  State<CustomOverlay> createState() => _CustomOverlayState();
}

// Global variables
String? _currentPhoneNumber;
List<SmsMessage> _realtimeSms = [];
VerificationState _verificationState = VerificationState.pending;
List<Map<String, String>> _lastSmsAddressData = []; // Sui address-timestamp pairs extracted from last received SMS
SuiVerificationResult? _verificationResult; // Verification result with details
Timer? _verificationTimer; // Verification timer
bool _isProcessingSms = false; // SMS processing flag

// Utility function to format timestamp
String _formatTimestamp(String timestamp) {
  try {
    final int timestampInt = int.parse(timestamp);
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestampInt);
    return '${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  } catch (e) {
    return timestamp; // Return original if parsing fails
  }
}

class _CustomOverlayState extends State<CustomOverlay> {
  SendPort? mainAppPort;
  bool update = false;
  final SmsService _smsService = SmsService();

  @override
  void initState() {
    super.initState();

    // Ensure initial state is pending (gray)
    _verificationState = VerificationState.pending;

    // Initialize SMS service
    _initializeSmsService();

    SystemAlertWindow.overlayListener.listen((event) {
      log("$event in overlay");
      if (event is bool) {
        setState(() {
          update = event;
        });
      } else if (event is String && event.startsWith('PHONE_NUMBER:')) {
        // Update phone number
        final phoneNumber = event.replaceFirst('PHONE_NUMBER:', '');
        setState(() {
          _currentPhoneNumber = phoneNumber;
          _realtimeSms.clear(); // Clear real-time SMS for new call
          _verificationState = VerificationState.pending; // Start with verifying state
          _lastSmsAddressData.clear(); // Clear Sui address data
          _verificationResult = null; // Clear verification result
          _isProcessingSms = false; // Clear SMS processing flag
        });

        // Start verification timer
        _startVerificationTimer();
        log("Phone number updated: $_currentPhoneNumber");
      } else if (event is String && event.startsWith('SMS_STATUS:')) {
        // Update SMS verification status
        final status = event.replaceFirst('SMS_STATUS:', '');
        setState(() {
          if (status == "Received") {
            _verificationState = VerificationState.verified;
            _cancelVerificationTimer(); // Cancel timer on verification success
          } else {
            _lastSmsAddressData.clear(); // Clear Sui address data on status change
            _verificationResult = null; // Clear verification result
          }
        });
        log("SMS status updated: $status (verification state: $_verificationState)");
      }
    });
  }

  void _initializeSmsService() {
    log("[Overlay SMS] Starting SMS service initialization");

    // Start real-time SMS detection (display simply in UI)
    _smsService.smsStream.listen(
      (sms) async {
        log("[Overlay SMS] Real-time SMS received from ${sms.address}: ${sms.body}");

        // Sui address extraction and logging
        final addressData = _smsService.extractSuiAddressesFromText(sms.body);
        if (addressData.isNotEmpty) {
          log("[Overlay SMS Sui] Found Sui address-timestamp pairs in SMS:");
          for (final data in addressData) {
            log("[Overlay SMS Sui] - Address: ${data['address']}, Timestamp: ${data['timestamp']}");
          }
        }

        // Check if current call is ongoing and SMS is from that number
        if (_currentPhoneNumber != null &&
            PhoneNumberUtils.isMatching(sms.address, _currentPhoneNumber!)) {

          // Stop additional SMS processing if already verified
          if (_verificationState == VerificationState.verified) {
            log("[Overlay SMS] ⚠️ Already verified - stopping SMS processing (from: ${sms.address})");
            return;
          }

          // Prevent duplicate processing if SMS is being processed
          if (_isProcessingSms) {
            log("[Overlay SMS] ⚠️ SMS processing - preventing duplicate processing (from: ${sms.address})");
            return;
          }

          log("[Overlay SMS] SMS matched for current call from: ${sms.address}");
          setState(() {
            _lastSmsAddressData = addressData; // Store Sui address data
          });

          // Verify each Sui address if addresses are included
          if (addressData.isNotEmpty) {
            log("[Overlay SMS] 🔗 Found ${addressData.length} Sui address-timestamp pairs - starting verification");

            // Set SMS processing start flag
            _isProcessingSms = true;

            // Verify all Sui addresses with timestamps
            SuiVerificationResult? validResult;
            for (final data in addressData) {
              final address = data['address']!;
              final timestamp = data['timestamp']!;
              final result = await _smsService.verifySuiAddressWithDetails(address, timestamp);
              if (result.isValid) {
                validResult = result;
                break;
              }
            }

            // Complete verification only if there are valid addresses
            if (validResult != null) {
              setState(() {
                _verificationState = VerificationState.verified;
                _verificationResult = validResult; // Store verification result
              });

              // Cancel timer on verification success
              _cancelVerificationTimer();

              log("[Overlay SMS] ✅ Sui address verification complete - final approval");
              log("[Overlay SMS] 🚫 Setting stop additional SMS processing due to verification completion");

              // Notify verification status to PhoneService singleton instance
              final phoneServiceInstance = PhoneService.getInstance();
              phoneServiceInstance.updateToVerifiedCall(_currentPhoneNumber);
              debugPrint('[Overlay] ★★★ Verification status delivery to PhoneService completed (number: $_currentPhoneNumber) ★★★');

              // Also notify main app of SMS reception status
              SystemAlertWindow.sendMessageToOverlay('SMS_STATUS:Received');
              log("[Overlay SMS] Real-time SMS verification completed for: ${sms.address}");
            } else {
              log("[Overlay SMS] ❌ All Sui address verification failed - maintaining verification state");
              // On failure, don't immediately change to failed state, let timer handle it
            }

            // Clear SMS processing completion flag
            _isProcessingSms = false;
          } else {
            log("[Overlay SMS] ❌ SMS without Sui address-timestamp pairs - maintaining verification state");
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



  // Start verification timer
  void _startVerificationTimer() {
    _verificationTimer?.cancel(); // Cancel existing timer

    log("[Timer] Starting ${AppConstants.verificationTimeout.inSeconds}-second verification timer");
    _verificationTimer = Timer(AppConstants.verificationTimeout, () {
      // Handle as failure if not verified even after timer expiration
      if (_verificationState == VerificationState.pending) {
        setState(() {
          _verificationState = VerificationState.failed;
        });
        log("[Timer] ❌ Verification timeout - changing to failed state");
      }
    });
  }

  // Cancel timer
  void _cancelVerificationTimer() {
    _verificationTimer?.cancel();
    _verificationTimer = null;
    log("[Timer] Verification timer cancelled");
  }


  Widget _buildDetailCard(String label, String value, Color valueColor, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: valueColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: valueColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void callBackFunction(String tag) {
    debugPrint("Got tag $tag");
    mainAppPort ??= IsolateNameServer.lookupPortByName(
      AppConstants.mainAppPort,
    );
    mainAppPort?.send('Date: ${DateTime.now()}');
    mainAppPort?.send(tag);

    // Notify main app when closed by touch
    if (tag.contains("Touch Close")) {
      mainAppPort?.send('OVERLAY_CLOSED_BY_TOUCH');
    }
  }


  Widget overlay() {
    return GestureDetector(
      // Close when touching outside area
      onTap: () {
        log('[Overlay] Outside area touch - closing overlay');
        callBackFunction("Outside Close");
        SystemAlertWindow.closeSystemWindow(prefMode: prefMode);
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.8), // Darker background
        child: SafeArea(
          child: GestureDetector(
            // Don't close when touching internal container
            onTap: () {
              log('[Overlay] Internal container touch - maintain');
            },
            child: AnimatedContainer(
              duration: AppConstants.overlayAnimationDuration,
              curve: Curves.easeInOut,
              width: double.infinity,
              height: double.infinity, // Full screen
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _verificationState.gradientColors,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _verificationState.accentColor.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _verificationState.accentColor.withValues(alpha: 0.4),
                    blurRadius: 25,
                    spreadRadius: 5,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Main content
                  Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(18),
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
                                          colors: [_verificationState.accentColor, _verificationState.accentColor.withValues(alpha: 0.7)],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _verificationState.accentColor.withValues(alpha: 0.6),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        _verificationState.icon,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _verificationState.titleText,
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
                                    _currentPhoneNumber ?? "Checking phone number...",
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
                          const SizedBox(height: 8),

                          // SMS verification section
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 20),
                                AnimatedContainer(
                                  duration: AppConstants.iconAnimationDuration,
                                  curve: Curves.easeInOut,
                                  padding: const EdgeInsets.all(12),
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
                                        duration: AppConstants.animationDuration,
                                        child: Text(
                                          _verificationState.statusMessage,
                                          key: ValueKey(_verificationState.toString()),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Sui address display area - Direct card display
                                      if (_verificationState == VerificationState.verified && _verificationResult != null) ...[
                                        // Interested Product
                                        if (_verificationResult!.interestedProduct != null)
                                          _buildDetailCard("Product", _verificationResult!.interestedProduct!, Colors.lightBlueAccent, Icons.shopping_bag),
                                        // Consent Collector
                                        if (_verificationResult!.consentCollector != null)
                                          _buildDetailCard("Collector", _verificationResult!.consentCollector!, Colors.orangeAccent, Icons.business),
                                        // Consultation Topic
                                        if (_verificationResult!.consultationTopic != null)
                                          _buildDetailCard("Topic", _verificationResult!.consultationTopic!, Colors.yellowAccent, Icons.chat_bubble),
                                        // Timestamp
                                        if (_verificationResult!.timestamp != null)
                                          _buildDetailCard("Time", _formatTimestamp(_verificationResult!.timestamp!), Colors.greenAccent, Icons.schedule),
                                      ] else if (_verificationState == VerificationState.verified && _verificationResult == null) ...[
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
                                            "This message does not contain Sui addresses",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.orangeAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      AnimatedSwitcher(
                                        duration: AppConstants.animationDuration,
                                        child: Text(
                                          _verificationState.description,
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

                                // Bottom buttons
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Center(
                                    child:
                                      // Close button (center)
                                      GestureDetector(
                                        onTap: () {
                                          log('[Overlay] Close button clicked - closing overlay');
                                          callBackFunction("Close Button");
                                          SystemAlertWindow.closeSystemWindow(prefMode: prefMode);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                                            "Close",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                              ],
                            ),
                          ),
                        ],
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