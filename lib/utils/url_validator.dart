import 'dart:async';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../config/app_constants.dart';

class UrlValidator {
  /// Validate URL content by making HTTP request
  static Future<bool> validateUrl(String url) async {
    try {
      log("[URL Validation] Checking URL: $url");

      final response = await http.get(Uri.parse(url)).timeout(
        AppConstants.urlValidationTimeout,
        onTimeout: () {
          log("[URL Validation] Timeout for URL: $url");
          return http.Response('Timeout', 408);
        },
      );

      log("[URL Validation] Status Code: ${response.statusCode} for URL: $url");

      if (response.statusCode == 200) {
        final body = response.body;
        log("[URL Validation] ✅ HTTP 200 OK - Response body length: ${body.length}");

        // Log body preview
        final preview = body.length > 100 ? '${body.substring(0, 100)}...' : body;
        log("[URL Validation] Body preview: $preview");

        return true;
      } else {
        log("[URL Validation] ❌ HTTP ${response.statusCode} for URL: $url");
        return false;
      }
    } catch (e) {
      log("[URL Validation] ❌ Error validating URL $url: $e");
      return false;
    }
  }

  /// Validate multiple URLs and return true if any is valid
  static Future<bool> validateAnyUrl(List<String> urls) async {
    if (urls.isEmpty) return false;

    log("[URL Validation] 🔗 Found ${urls.length} links - starting validation");

    for (String url in urls) {
      try {
        final isValid = await validateUrl(url);
        if (isValid) {
          log("[URL Validation] ✅ Valid link confirmed: $url");
          return true;
        } else {
          log("[URL Validation] ❌ Invalid link: $url");
        }
      } catch (e) {
        log("[URL Validation] ❌ Link verification error $url: $e");
      }
    }

    log("[URL Validation] ❌ All link validation failed");
    return false;
  }
}