import 'dart:convert';

String? parseSerialNumber(String rawQr) {
  final trimmed = rawQr.trim();
  if (trimmed.isEmpty) return null;

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      final s =
          decoded['serial'] ??
          decoded['serial_number'] ??
          decoded['sn'] ??
          decoded['SN'];
      final snString = s?.toString().trim();
      if (snString != null && snString.isNotEmpty) return snString;
    }
  } catch (_) {
    // Not a valid JSON, fallback to plain string parsing
  }

  // Attempt to extract SN: ... or SN=... from plain text or broken JSON
  final match = RegExp(
    r'''(?:^|[{\s,])SN\s*[:=]\s*["']?([^,"'}\s]+)''',
    caseSensitive: false,
  ).firstMatch(trimmed);
  final extracted = match?.group(1)?.trim();
  if (extracted != null && extracted.isNotEmpty) {
    return extracted;
  }

  // Fallback: treat the whole string as the serial number
  return trimmed;
}
