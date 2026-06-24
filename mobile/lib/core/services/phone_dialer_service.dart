// lib/core/services/phone_dialer_service.dart

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneDialerService {
  Future<bool> openDialer(String phoneNumber) async {
    final trimmedPhone = phoneNumber.trim();
    if (trimmedPhone.isEmpty) return false;

    // Preserve +, digits, spaces, and dashes for the URI.
    // Basic normalization: we just rely on Uri to encode it, but tel: expects a relatively clean format.
    // It's safest to just remove spaces and dashes for the actual tel: scheme.
    final normalizedPhone = trimmedPhone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (normalizedPhone.isEmpty) return false;

    final uri = Uri(scheme: 'tel', path: normalizedPhone);

    try {
      if (kDebugMode) {
        debugPrint(
          'PhoneDialerService: trying to open dialer for number: $normalizedPhone',
        );
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && kDebugMode) {
        debugPrint('PhoneDialerService: launchUrl returned false for $uri');
      }

      return launched;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PhoneDialerService: Exception while opening dialer: $e');
      }
      return false;
    }
  }
}
