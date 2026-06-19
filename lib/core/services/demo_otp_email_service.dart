import 'dart:convert';
import 'dart:math';

import 'package:forest_carbon_platform/config/emailjs_config.dart';
import 'package:http/http.dart' as http;

class DemoOtpEmailService {
  DemoOtpEmailService._();
  static final DemoOtpEmailService instance = DemoOtpEmailService._();

  static const Duration otpLifetime = Duration(minutes: 5);

  String generateOtp() {
    final value = Random().nextInt(900000) + 100000;
    return value.toString();
  }

  Future<void> sendOtp({
    required String email,
    required String otp,
  }) async {
    if (!EmailJsConfig.isConfigured) {
      throw StateError(
        'Chua cau hinh EmailJS trong lib/config/emailjs_config.dart.',
      );
    }

    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': EmailJsConfig.serviceId,
        'template_id': EmailJsConfig.templateId,
        'user_id': EmailJsConfig.publicKey,
        'template_params': {
          'to_email': email.trim().toLowerCase(),
          'otp_code': otp,
          'app_name': 'Forest Carbon Platform',
          'expires_in': '${otpLifetime.inMinutes} phut',
        },
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'EmailJS loi ${response.statusCode}: ${response.body}',
      );
    }
  }
}
