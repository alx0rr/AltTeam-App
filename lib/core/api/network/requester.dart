import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../helpers/generator.dart';
import 'exceptions.dart';
import '../constants.dart';
import 'package:flutter/foundation.dart';

class Requester {
  final String userAgent;
  final String deviceId;
  String language;
  String? sid;
  String? userId;
  late final Dio _dio;

  Future<String?> Function()? refreshSession;

  void Function()? onSessionExpired;

  Future<String?>? _refreshInFlight;
  String get baseUrl => _dio.options.baseUrl;
  set baseUrl(String v) => _dio.options.baseUrl = v;

  Requester({
    required this.deviceId,
    this.userAgent = UserAgent,
    this.language = 'en',
    this.sid,
    this.userId,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: apiUrl,
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ));
  }

  Map<String, String> _buildHeaders({dynamic data, Map<String, String>? extraHeaders}) {
    final headers = Map<String, String>.from(basicHeaders);

    if (language.isNotEmpty){
      headers['Accept-Language'] = language;
      headers['NDCLANG'] = language;
    }
    headers['User-Agent'] = userAgent;
    headers['NDCDEVICEID'] = deviceId;

    if (data != null) {
      if (data is Uint8List) {
        headers['Content-Length'] = data.length.toString();
        headers['NDC-MSG-SIG'] = Generator.signature(data);
      } else {
        final encoded = data is String ? data : jsonEncode(data);
        headers['NDC-MSG-SIG'] = Generator.signature(encoded);
        headers['Content-Length'] = utf8.encode(encoded).length.toString();
      }
    }

    if (sid != null) {
      if (userId != null) {
        headers['AUID'] = userId ?? "";
      }
      headers['NDCAUTH'] = 'sid=$sid';
    }

    if (extraHeaders != null) headers.addAll(extraHeaders);
    return headers;
  }

  Future<Map<String, dynamic>> request(
    String method,
    String endpoint, {
    dynamic body,
    Map<String, String>? extraHeaders,
    List<int> allowedCodes = const [200],
    bool retryOnAuthFail = true,
  }) async {
    final response = await _send(method, endpoint, body: body, extraHeaders: extraHeaders);

    if (_isSessionExpired(response) && retryOnAuthFail && refreshSession != null) {
      final newSid = await _refreshOnce();

      if (newSid != null) {
        sid = newSid;

        return request(
          method,
          endpoint,
          body: body,
          extraHeaders: extraHeaders,
          allowedCodes: allowedCodes,
          retryOnAuthFail: false,
        );
      }

      onSessionExpired?.call();
      _checkException(response);
    }

    if (!allowedCodes.contains(response.statusCode)) {
      _checkException(response);
    }

    return response.data is Map<String, dynamic>
        ? response.data
        : {'data': response.data};
  }

  Future<Response> _send(
    String method,
    String endpoint, {
    dynamic body,
    Map<String, String>? extraHeaders,
  }) async {
    final bool isBinary = body is Uint8List || body is List<int>;

    dynamic preparedBody = body;
    if (!isBinary && preparedBody is Map<String, dynamic>) {
      preparedBody = {
        ...preparedBody,
        'timestamp': Generator.reqTime(),
      };
    }

    final dynamic encodedBody = isBinary
        ? (preparedBody is Uint8List ? preparedBody : Uint8List.fromList(preparedBody as List<int>))
        : preparedBody is String
            ? preparedBody
            : preparedBody != null
                ? jsonEncode(preparedBody)
                : null;

    final headers = _buildHeaders(data: encodedBody, extraHeaders: extraHeaders);

    return _dio.request(
      endpoint,
      data: encodedBody,
      options: Options(method: method, headers: headers),
    );
  }

  bool _isSessionExpired(Response response) {
    if (response.statusCode != 440) return false;
    final data = response.data;
    if (data is! Map<String, dynamic>) return false;
    return '${data['api:statuscode']}' == '105';
  }

  Future<String?> _refreshOnce() {
    return _refreshInFlight ??= _doRefresh();
  }

  Future<String?> _doRefresh() async {
    try {
      return await refreshSession!();
    } catch (e) {
      debugPrint('Session refresh failed: $e');
      return null;
    } finally {
      _refreshInFlight = null;
    }
  }

  void _checkException(Response response) {
    final data = response.data;

    String code = 'unknown';
    String message = 'Unknown error';

    if (data is Map<String, dynamic>) {
      code = data['api:statuscode']?.toString() ?? 'unknown';
      message = data['api:message']?.toString() ?? 'Unknown error';
    } else if (data != null) {
      message = data.toString();
    }

    if (response.statusCode == 401) {
      throw UnauthorizedException(code: code, message: message);
    }

    throw ApiException(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? headers}) =>
      request('GET', endpoint, extraHeaders: headers);

  Future<Map<String, dynamic>> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) {
    if (body is Uint8List || body is List<int>) {
      return request('POST', endpoint, body: body, extraHeaders: headers);
    }

    if (body is String) {
      return request('POST', endpoint, body: body, extraHeaders: headers);
    }

    final Map<String, dynamic> requestBody =
        body is Map<String, dynamic> ? Map<String, dynamic>.from(body) : {};

    requestBody['timestamp'] = Generator.reqTime();
    return request('POST', endpoint, body: requestBody, extraHeaders: headers);
  }

  Future<Map<String, dynamic>> delete(String endpoint, {dynamic body, Map<String, String>? headers}) =>
      request('DELETE', endpoint, body: body, extraHeaders: headers);
}