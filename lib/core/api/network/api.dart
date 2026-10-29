import '../helpers/generator.dart';
import 'requester.dart';
import '../../storage.dart';
import '../constants.dart';

class Api {
  static late final Requester _requester;

  static void Function()? onSessionExpired;

  static bool _sessionExpiredFired = false;

  static Future<void> init() async {
    var deviceId = Storage.deviceId;
    if (deviceId == null) {
      deviceId = Generator.genDeviceId();
      await Storage.setDeviceId(deviceId);
    }

    _requester = Requester(
      userAgent: UserAgent,
      deviceId: deviceId,
      language: Storage.locale
    );

    _requester.refreshSession = _refreshSession;
    _requester.onSessionExpired = () {
      if (_sessionExpiredFired) return;
      _sessionExpiredFired = true;
      clearSession();
      onSessionExpired?.call();
    };

    final sid = Storage.sid;
    final userId = Storage.userId;
    if (sid != null && userId != null) {
      _requester.sid = sid;
      _requester.userId = userId;
    }
  }

  static Future<String?> _refreshSession() async {
    final email = Storage.email;
    final secret = Storage.secret;
    if (email == null || email.isEmpty || secret == null || secret.isEmpty) {
      return null;
    }

    final res = await _requester.request(
      'POST',
      '/g/s/auth/login',
      body: {
        'email': email,
        'secret': secret,
        'deviceID': _requester.deviceId,
        'clientType': 100,
      },
      retryOnAuthFail: false,
    );

    final newSid = res['sid']?.toString();
    if (newSid == null || newSid.isEmpty) return null;

    _applyLoginResponse(res);
    return newSid;
  }

 
  static void _applyLoginResponse(Map<String, dynamic> res) {
    final sid = res['sid']?.toString();
    if (sid == null || sid.isEmpty) return;

    final profile = (res['userProfile'] as Map?)?.cast<String, dynamic>();

    setSid(
      sid,
      res['auid'],
      profile?['role'],
      profile?['aminoId'],
      profile?['telegramId'],
    );

  
    final newSecret = res['secret']?.toString();
    if (newSecret != null && newSecret.isNotEmpty) {
      Storage.setSecret(newSecret);
    }
  }

  static void saveLoginResult(String email, Map<String, dynamic> res) {
    Storage.setEmail(email);
    _applyLoginResponse(res);
  }


static String get baseUrl => _requester.baseUrl;

static void setBaseUrl(String url) {
  _requester.baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
}

static void resetBaseUrl() => _requester.baseUrl = apiUrl;


  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
  }) =>
      _requester.get(endpoint, headers: headers);

  static Future<Map<String, dynamic>> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) =>
      _requester.post(endpoint, body: body, headers: headers);

  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) =>
      _requester.delete(endpoint, body: body, headers: headers);

  static void setSid(String sid, userId, role, aminoId, telegramId) {
    _sessionExpiredFired = false;
    Storage.setSid(sid);
    Storage.setUserId(userId);
    Storage.setRole(role is int ? role : int.tryParse('$role') ?? 0);
    Storage.setAminoId(aminoId?.toString() ?? '');
    Storage.setTelegramId(telegramId is int ? telegramId : int.tryParse('$telegramId'));
    _requester.sid = sid;
    _requester.userId = userId?.toString();
  }

  static void editLocale(String lang){
    _requester.language = lang;
  }

  static String getDeviceId() {
    return _requester.deviceId;
  }

  static void clearSession() {
    _requester.sid = null;
    _requester.userId = null;
    Storage.clearSession();
  }
}