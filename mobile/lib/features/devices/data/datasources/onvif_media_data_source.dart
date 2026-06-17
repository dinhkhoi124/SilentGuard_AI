import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/devices/domain/entities/device_credentials.dart';
import 'package:mobile/features/devices/domain/entities/onvif_discovery_result.dart';
import 'package:xml/xml.dart';

abstract interface class OnvifMediaDataSource {
  Future<String> getStreamUri(
    OnvifDiscoveryResult device, {
    DeviceCredentials? credentials,
  });
}

class OnvifMediaDataSourceImpl implements OnvifMediaDataSource {
  OnvifMediaDataSourceImpl({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> getStreamUri(
    OnvifDiscoveryResult device, {
    DeviceCredentials? credentials,
  }) async {
    final security = _securityHeader(credentials);
    final capabilities = await _postSoap(
      device.serviceUrl,
      _envelope(_getCapabilitiesBody(), security),
      'http://www.onvif.org/ver10/device/wsdl/GetCapabilities',
    );

    final mediaUrl = _mediaServiceUrl(capabilities) ?? device.serviceUrl;
    final profiles = await _postSoap(
      mediaUrl,
      _envelope(_getProfilesBody(), security),
      'http://www.onvif.org/ver10/media/wsdl/GetProfiles',
    );
    final profileToken = _firstProfileToken(profiles);
    if (profileToken == null || profileToken.isEmpty) {
      throw const OnvifMediaException('Không tìm thấy media profile ONVIF.');
    }

    final streamResponse = await _postSoap(
      mediaUrl,
      _envelope(_getStreamUriBody(profileToken), security),
      'http://www.onvif.org/ver10/media/wsdl/GetStreamUri',
    );
    final streamUri = _firstElementText(streamResponse, 'Uri');
    if (streamUri == null || !streamUri.toLowerCase().startsWith('rtsp://')) {
      throw const OnvifMediaException('Camera không trả về RTSP URI hợp lệ.');
    }
    return streamUri;
  }

  Future<XmlDocument> _postSoap(
    String url,
    String body,
    String soapAction,
  ) async {
    final response = await _client
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/soap+xml; charset=utf-8',
            'Accept': 'application/soap+xml, text/xml',
            'SOAPAction': '"$soapAction"',
          },
          body: body,
        )
        .timeout(AppConfig.networkTimeout);

    final responseBody = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OnvifMediaException(
        'Camera từ chối yêu cầu ONVIF (${response.statusCode}).',
      );
    }
    return XmlDocument.parse(responseBody);
  }

  String? _mediaServiceUrl(XmlDocument document) {
    for (final media in document.descendants.whereType<XmlElement>()) {
      if (media.name.local != 'Media') continue;
      final xaddr = _firstChildText(media, 'XAddr');
      if (xaddr != null && xaddr.isNotEmpty) return xaddr;
    }
    return null;
  }

  String? _firstProfileToken(XmlDocument document) {
    for (final profile in document.descendants.whereType<XmlElement>()) {
      if (profile.name.local != 'Profiles') continue;
      for (final attribute in profile.attributes) {
        if (attribute.name.local == 'token') return attribute.value;
      }
    }
    return null;
  }

  String? _firstElementText(XmlDocument document, String localName) {
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) return element.innerText.trim();
    }
    return null;
  }

  String? _firstChildText(XmlElement parent, String localName) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.name.local == localName) return child.innerText.trim();
    }
    return null;
  }

  String _envelope(String body, String securityHeader) {
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope
  xmlns:s="http://www.w3.org/2003/05/soap-envelope"
  xmlns:tds="http://www.onvif.org/ver10/device/wsdl"
  xmlns:trt="http://www.onvif.org/ver10/media/wsdl"
  xmlns:tt="http://www.onvif.org/ver10/schema">
  <s:Header>$securityHeader</s:Header>
  <s:Body>$body</s:Body>
</s:Envelope>
''';
  }

  String _getCapabilitiesBody() {
    return '''
<tds:GetCapabilities>
  <tds:Category>Media</tds:Category>
</tds:GetCapabilities>
''';
  }

  String _getProfilesBody() {
    return '<trt:GetProfiles />';
  }

  String _getStreamUriBody(String profileToken) {
    final escapedToken = _xmlEscape(profileToken);
    return '''
<trt:GetStreamUri>
  <trt:StreamSetup>
    <tt:Stream>RTP-Unicast</tt:Stream>
    <tt:Transport>
      <tt:Protocol>RTSP</tt:Protocol>
    </tt:Transport>
  </trt:StreamSetup>
  <trt:ProfileToken>$escapedToken</trt:ProfileToken>
</trt:GetStreamUri>
''';
  }

  String _securityHeader(DeviceCredentials? credentials) {
    if (credentials == null || credentials.isEmpty) return '';

    final random = Random.secure();
    final nonceBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final created = DateTime.now().toUtc().toIso8601String();
    final passwordDigest = sha1.convert([
      ...nonceBytes,
      ...utf8.encode(created),
      ...utf8.encode(credentials.password),
    ]);

    final nonce = base64Encode(nonceBytes);
    return '''
<wsse:Security
  s:mustUnderstand="1"
  xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
  xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
  <wsse:UsernameToken>
    <wsse:Username>${_xmlEscape(credentials.username)}</wsse:Username>
    <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">${base64Encode(passwordDigest.bytes)}</wsse:Password>
    <wsse:Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">$nonce</wsse:Nonce>
    <wsu:Created>$created</wsu:Created>
  </wsse:UsernameToken>
</wsse:Security>
''';
  }

  String _xmlEscape(String value) {
    return const HtmlEscape(HtmlEscapeMode.element).convert(value);
  }
}

class OnvifMediaException implements Exception {
  const OnvifMediaException(this.message);

  final String message;

  @override
  String toString() => message;
}
