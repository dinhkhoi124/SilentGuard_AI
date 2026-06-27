import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class FirebaseAuthHttpClient extends http.BaseClient {
  FirebaseAuthHttpClient({
    required FirebaseAuth firebaseAuth,
    http.Client? innerClient,
  }) : _firebaseAuth = firebaseAuth,
       _innerClient = innerClient ?? http.Client();

  final FirebaseAuth _firebaseAuth;
  final http.Client _innerClient;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final snapshot = await _RequestSnapshot.from(request);
    final token = await _getIdToken();
    final response = await _innerClient.send(
      snapshot.toRequest(authorizationToken: token),
    );

    if (response.statusCode != 401) return response;

    final refreshedToken = await _getIdToken(forceRefresh: true);
    if (refreshedToken == null || refreshedToken.isEmpty) return response;

    await response.stream.drain<void>();
    return _innerClient.send(
      snapshot.toRequest(authorizationToken: refreshedToken),
    );
  }

  Future<String?> _getIdToken({bool forceRefresh = false}) {
    return _firebaseAuth.currentUser?.getIdToken(forceRefresh) ??
        Future.value();
  }

  @override
  void close() {
    _innerClient.close();
    super.close();
  }
}

class _RequestSnapshot {
  const _RequestSnapshot({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyBytes,
    required this.contentLength,
    required this.followRedirects,
    required this.maxRedirects,
    required this.persistentConnection,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final List<int> bodyBytes;
  final int? contentLength;
  final bool followRedirects;
  final int maxRedirects;
  final bool persistentConnection;

  static Future<_RequestSnapshot> from(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();
    return _RequestSnapshot(
      method: request.method,
      url: request.url,
      headers: Map<String, String>.of(request.headers),
      bodyBytes: bodyBytes,
      contentLength: request.contentLength,
      followRedirects: request.followRedirects,
      maxRedirects: request.maxRedirects,
      persistentConnection: request.persistentConnection,
    );
  }

  http.StreamedRequest toRequest({String? authorizationToken}) {
    final request = http.StreamedRequest(method, url)
      ..headers.addAll(headers)
      ..followRedirects = followRedirects
      ..maxRedirects = maxRedirects
      ..persistentConnection = persistentConnection;

    if (authorizationToken != null && authorizationToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $authorizationToken';
    }

    request.contentLength = contentLength ?? bodyBytes.length;
    request.sink.add(bodyBytes);
    request.sink.close();
    return request;
  }
}
