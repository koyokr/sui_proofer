class PhoneNumberUtils {
  /// Normalize phone number by removing special characters, prefixes, and country codes
  static String normalize(String phoneNumber) {
    String normalized = phoneNumber
        .replaceAll(RegExp(r'[\s\-\(\)\+]'), '')
        .replaceAll('82', '0');

    // Remove *77 prefix for second line calls
    if (normalized.startsWith('*77')) {
      normalized = normalized.substring(3);
    }

    return normalized;
  }

  /// Check if two phone numbers match (exact or last 4 digits)
  static bool isMatching(String number1, String number2) {
    final normalized1 = normalize(number1);
    final normalized2 = normalize(number2);

    // Exact match
    if (normalized1 == normalized2) return true;

    // Last 4 digits match (if both numbers have at least 4 digits)
    if (normalized1.length >= 4 && normalized2.length >= 4) {
      final last4_1 = normalized1.substring(normalized1.length - 4);
      final last4_2 = normalized2.substring(normalized2.length - 4);
      return last4_1 == last4_2;
    }

    return false;
  }

  /// Validate if phone number format is acceptable
  static bool isValidFormat(String phoneNumber) {
    // First check if phone number is null, empty, or Unknown
    if (phoneNumber.isEmpty ||
        phoneNumber == 'Unknown' ||
        phoneNumber == 'null') {
      return false;
    }

    final normalized = normalize(phoneNumber);
    return normalized.isNotEmpty &&
           normalized != 'Unknown' &&
           normalized != 'null' &&
           RegExp(r'^\d+$').hasMatch(normalized);
  }
}