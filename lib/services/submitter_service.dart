import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class SubmitterService {
  static final SubmitterService _instance = SubmitterService._internal();
  factory SubmitterService() => _instance;
  SubmitterService._internal();

  Future<String> getSubmitter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.submitterKey) ?? AppConstants.defaultSubmitter;
  }

  Future<void> setSubmitter(String submitter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.submitterKey, submitter);
  }
}