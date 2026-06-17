import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/devices/domain/entities/onvif_discovery_result.dart';
import 'package:xml/xml.dart';

abstract interface class OnvifDiscoveryDataSource {
  Future<List<OnvifDiscoveryResult>> discover();
}

class WsDiscoveryOnvifDataSource implements OnvifDiscoveryDataSource {
  const WsDiscoveryOnvifDataSource();

  static const _multicastAddress = '239.255.255.250';
  static const _wsDiscoveryPort = 3702;

  @override
  Future<List<OnvifDiscoveryResult>> discover() async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
      reuseAddress: true,
    );
    final results = <String, OnvifDiscoveryResult>{};

    late final StreamSubscription<RawSocketEvent> subscription;
    subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) return;

      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        final message = utf8.decode(datagram!.data, allowMalformed: true);
        final result = _parseProbeMatch(message);
        if (result != null) results[result.serviceUrl] = result;
      }
    });

    try {
      socket.broadcastEnabled = true;
      final payload = utf8.encode(_probeEnvelope());
      final multicast = InternetAddress(_multicastAddress);

      for (var attempt = 0; attempt < 3; attempt++) {
        socket.send(payload, multicast, _wsDiscoveryPort);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      await Future<void>.delayed(AppConfig.onvifDiscoveryTimeout);
      return results.values.toList(growable: false);
    } finally {
      await subscription.cancel();
      socket.close();
    }
  }

  OnvifDiscoveryResult? _parseProbeMatch(String message) {
    try {
      final document = XmlDocument.parse(message);
      final xAddrs = _firstElementText(document, 'XAddrs');
      if (xAddrs == null || xAddrs.trim().isEmpty) return null;

      final serviceUrl = xAddrs
          .split(RegExp(r'\s+'))
          .where((value) => value.startsWith('http'))
          .firstOrNull;
      if (serviceUrl == null) return null;

      final uri = Uri.tryParse(serviceUrl);
      final ipAddress = uri?.host;
      if (ipAddress == null || ipAddress.isEmpty) return null;

      final scopes = (_firstElementText(document, 'Scopes') ?? '')
          .split(RegExp(r'\s+'))
          .where((scope) => scope.trim().isNotEmpty)
          .map(Uri.decodeFull)
          .toList(growable: false);

      return OnvifDiscoveryResult(
        serviceUrl: serviceUrl,
        ipAddress: ipAddress,
        scopes: scopes,
        serialNumber: _extractSerialNumber(scopes),
        hardwareId: _firstElementText(document, 'Address'),
      );
    } catch (_) {
      return null;
    }
  }

  String? _firstElementText(XmlDocument document, String localName) {
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) return element.innerText.trim();
    }
    return null;
  }

  String? _extractSerialNumber(List<String> scopes) {
    final patterns = [
      RegExp(
        r'(?:serial|serialnumber|sn)[/:=_-]+([^/\s]+)',
        caseSensitive: false,
      ),
      RegExp(r'(?:SN|Serial):([^,\s]+)', caseSensitive: false),
    ];

    for (final scope in scopes) {
      for (final pattern in patterns) {
        final match = pattern.firstMatch(scope);
        if (match != null) return match.group(1);
      }
    }
    return null;
  }

  String _probeEnvelope() {
    final messageId = DateTime.now().microsecondsSinceEpoch;
    return '''
<?xml version="1.0" encoding="UTF-8"?>
<e:Envelope
  xmlns:e="http://www.w3.org/2003/05/soap-envelope"
  xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
  xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
  xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
  <e:Header>
    <w:MessageID>uuid:$messageId</w:MessageID>
    <w:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
    <w:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>
  </e:Header>
  <e:Body>
    <d:Probe>
      <d:Types>dn:NetworkVideoTransmitter</d:Types>
    </d:Probe>
  </e:Body>
</e:Envelope>
''';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}
