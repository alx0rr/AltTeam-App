import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../core/api/network/api.dart'; 
import '../../core/api/constants.dart'; 
import '../../core/api/helpers/generator.dart'; 
import '../../core/l10n/app_localizations.dart';
import '../../core/storage.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  static const _timeout = Duration(seconds: 5);
  static const _replyWait = Duration(seconds: 3);
  static const _pings = 4;

  static String get _defaultSocketUrl => wsUrl;

  PackageInfo? _pkg;

  final _host = TextEditingController(text: Uri.parse(Api.baseUrl).authority);
  final _socketUrl = TextEditingController(text: _defaultSocketUrl);

  bool _pinging = false;
  bool _socketChecking = false;
  String? _pingResult;
  String? _socketResult;
  bool? _pingOk;
  bool? _socketOk;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _pkg = p);
    });
  }

  @override
  void dispose() {
    _host.dispose();
    _socketUrl.dispose();
    super.dispose();
  }

  Map<String, Map<String, String>> _sections() {
    final p = _pkg;
    return {
      'App': {
        'Package': p?.packageName ?? '—',
        'Version': p?.version ?? '—',
        'Build': p?.buildNumber ?? '—',
        'Debug mode': kDebugMode.toString(),
      },
      'Session': {
        'User ID': Storage.userId ?? '—',
        'Amino ID': Storage.aminoId ?? '—',
        'Role': '${Storage.role ?? '—'}',
        'Email': '${Storage.email ?? '-'}',
        'Device ID': '${Storage.deviceId ?? '-'}',
        'Secret': '${Storage.secret ?? '-'}',
        'SID': '${Storage.sid ?? '-'}',
      },
      'Settings': {
        'Locale': Storage.locale,
        'Theme mode': Storage.themeMode.name,
      },
      'Device': {
        'OS': Platform.operatingSystem,
        'OS version': Platform.operatingSystemVersion,
        'Dart': Platform.version.split(' ').first,
      },
    };
  }

  String _report() {
    final b = StringBuffer();
    _sections().forEach((title, rows) {
      b.writeln('[$title]');
      rows.forEach((k, v) => b.writeln('$k: $v'));
      b.writeln();
    });
    b.writeln('[Network]');
    b.writeln('API: ${Api.baseUrl}');
    b.writeln('Socket: ${_socketUrl.text.trim()}');
    return b.toString().trim();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
      );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast(AppLocalizations.t('common.copied'));
  }

  void _clearImageCache() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    _toast('Image cache cleared');
  }

  Future<void> _reloadLocale() async {
    await AppLocalizations.load(Storage.locale);
    if (mounted) _toast('Locale reloaded');
  }

  
  String _cleanHost() {
    var h = _host.text.trim();
    h = h.replaceFirst(RegExp(r'^[a-zA-Z]+://'), '');
    final slash = h.indexOf('/');
    if (slash != -1) h = h.substring(0, slash);
    return h;
  }

  String _cleanSocketUrl() {
    var u = _socketUrl.text.trim();
    if (u.isEmpty) return '';
    if (!RegExp(r'^[a-zA-Z]+://').hasMatch(u)) u = 'wss://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<int?> _pingOnce(Uri uri) async {
    final client = HttpClient()..connectionTimeout = _timeout;
    final sw = Stopwatch()..start();
    try {
      final req = await client.getUrl(uri);
      final res = await req.close().timeout(_timeout);
      await res.drain<void>();
      sw.stop();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

Future<void> _ping() async {
  final host = _cleanHost();
  if (host.isEmpty) return;

  setState(() {
    _pinging = true;
    _pingResult = null;
    _pingOk = null;
  });

  final uri = Uri.parse('https://$host/');
  final times = <int>[];

  for (var i = 0; i < _pings; i++) {
    final ms = await _pingOnce(uri);
    if (ms != null) times.add(ms);
  }

  if (!mounted) return;

  setState(() {
    _pinging = false;

    if (times.isEmpty) {
      _pingOk = false;
      _pingResult = 'Unavailable ($_pings/$_pings failed)';
    } else {
      final avg = times.reduce((a, b) => a + b) ~/ times.length;
      final min = times.reduce((a, b) => a < b ? a : b);
      final max = times.reduce((a, b) => a > b ? a : b);

      _pingOk = true;
      _pingResult = 'min $min / avg $avg / max $max ms  '
          '(${times.length}/$_pings successful)\n'
          'All: ${times.map((t) => '$t').join(', ')} ms';
    }
  });
}

void _setSocket(bool ok, String text) {
  if (!mounted) return;

  setState(() {
    _socketOk = ok;
    _socketResult = text;
  });
}

Future<void> _checkSocket() async {
  final base = _cleanSocketUrl();
  if (base.isEmpty) return;

  final sid = Storage.sid;
  final deviceId = Storage.deviceId;
  final userId = Storage.userId;

  setState(() {
    _socketChecking = true;
    _socketResult = null;
    _socketOk = null;
  });

  if (sid == null || sid.isEmpty || deviceId == null || deviceId.isEmpty) {
    _setSocket(
      false,
      'No sid or deviceId (not authenticated?)\n$base',
    );

    if (mounted) {
      setState(() => _socketChecking = false);
    }
    return;
  }

  final signBody = '$deviceId|${Generator.reqTime()}';
  final url = '$base/?signbody=${signBody.replaceAll('|', '%7C')}';

  final headers = <String, dynamic>{
    'User-Agent': UserAgent,
    'AUID': userId ?? '',
    'NDCAUTH': 'sid=$sid',
    'NDCLANG': Storage.locale,
    'NDCDEVICEID': deviceId,
    'NDC-MSG-SIG': Generator.signature(signBody),
  };

  final sw = Stopwatch()..start();
  WebSocket? ws;
  StreamSubscription? sub;

  try {
    ws = await WebSocket.connect(
      url,
      headers: headers,
    ).timeout(_timeout);

    final connectMs = sw.elapsedMilliseconds;

    final first = Completer<String>();
    final socket = ws;

    sub = socket.listen(
      (_) {
        if (!first.isCompleted) {
          first.complete('data');
        }
      },
      onError: (Object e) {
        if (!first.isCompleted) {
          first.complete('error: $e');
        }
      },
      onDone: () {
        if (!first.isCompleted) {
          first.complete(
            'closed:${socket.closeCode ?? '-'} '
            '${socket.closeReason ?? ''}',
          );
        }
      },
    );

    socket.add(jsonEncode({
      't': 116,
      'o': {
        'threadChannelUserInfoList': [],
      },
    }));

    final reply = await first.future.timeout(
      _replyWait,
      onTimeout: () => 'silent',
    );

    sw.stop();

    if (reply == 'data') {
      _setSocket(
        true,
        'Connected in $connectMs ms, server responded\n$base',
      );
    } else if (reply == 'silent') {
      _setSocket(
        true,
        'Connected in $connectMs ms, no response within '
        '${_replyWait.inSeconds}s (connection is open)\n$base',
      );
    } else {
      _setSocket(
        false,
        'Connected in $connectMs ms, but the server closed the connection '
        'or returned an error:\n$reply\n$base',
      );
    }
  } on TimeoutException {
    _setSocket(
      false,
      'Timeout after ${_timeout.inSeconds}s\n$base',
    );
  } on WebSocketException catch (e) {
    _setSocket(
      false,
      '${e.message}\n$base',
    );
  } catch (e) {
    _setSocket(
      false,
      '$e\n$base',
    );
  } finally {
    await sub?.cancel();
    await ws?.close();

    if (mounted) {
      setState(() => _socketChecking = false);
    }
  }
}

  void _applyToApi(String base) => Api.setBaseUrl(base);

  void _apply() {
    final host = _cleanHost();
    if (host.isEmpty) return;
    final base = 'https://$host/api/v1';
    _applyToApi(base);
    _toast('API: $base');
  }

  void _reset() {
    Api.resetBaseUrl();
    _host.text = Uri.parse(Api.baseUrl).authority;
    _socketUrl.text = _defaultSocketUrl;
    _toast('API: ${Api.baseUrl}');
  }


  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sections = _sections();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: colors.glassFill,
                  border: Border(bottom: BorderSide(color: colors.glassBorder)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: colors.textPrimary, size: 20),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        AppLocalizations.t('drawer.debug'),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy report',
                      icon: Icon(Icons.copy_all_rounded,
                          color: colors.textPrimary, size: 20),
                      onPressed: () => _copy(_report()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final e in sections.entries) ...[
                      _title(colors, e.key),
                      _card(colors, e.value),
                      const SizedBox(height: 20),
                    ],
                    _title(colors, 'Network'),
                    _networkCard(colors),
                    const SizedBox(height: 20),
                    _title(colors, 'Actions'),
                    _action(colors, Icons.image_not_supported_rounded,
                        'Clear image cache', _clearImageCache),
                    _action(colors, Icons.translate_rounded, 'Reload locale',
                        _reloadLocale),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _networkCard(AppPalette colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current API: ${Api.baseUrl}',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _field(colors, _host, 'API Domain', 'dev-service.altamino.top'),
          const SizedBox(height: 10),
          _field(colors, _socketUrl, 'Socket URL', _defaultSocketUrl),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _btn(colors, Icons.network_ping_rounded, 'Ping', _ping,
                  busy: _pinging),
              _btn(colors, Icons.cable_rounded, 'Socket', _checkSocket,
                  busy: _socketChecking),
              _btn(colors, Icons.swap_horiz_rounded, 'Apply', () {
                _apply();
                setState(() {});
              }),
              _btn(colors, Icons.restore_rounded, 'Reset', () {
                _reset();
                setState(() {});
              }),
            ],
          ),
          if (_pingResult != null) ...[
            const SizedBox(height: 12),
            _result(colors, 'Ping', _pingResult!, _pingOk),
          ],
          if (_socketResult != null) ...[
            const SizedBox(height: 8),
            _result(colors, 'Socket', _socketResult!, _socketOk),
          ],
        ],
      ),
    );
  }

  Widget _field(
      AppPalette colors, TextEditingController c, String label, String hint) {
    return TextField(
      controller: c,
      autocorrect: false,
      keyboardType: TextInputType.url,
      style: TextStyle(color: colors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle: TextStyle(color: colors.textMuted),
        hintStyle: TextStyle(color: colors.textMuted.withValues(alpha: 0.6)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _btn(AppPalette colors, IconData icon, String label, VoidCallback onTap,
      {bool busy = false}) {
    return OutlinedButton.icon(
      onPressed: busy ? null : onTap,
      icon: busy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: colors.accentPrimary),
            )
          : Icon(icon, size: 16, color: colors.accentPrimary),
      label: Text(label, style: TextStyle(color: colors.textPrimary)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colors.glassBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _result(AppPalette colors, String title, String text, bool? ok) {
    final c = ok == null
        ? colors.textMuted
        : ok
            ? Colors.green
            : colors.error;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _copy(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: c, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(text,
                style: TextStyle(color: colors.textPrimary, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _title(AppPalette colors, String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _card(AppPalette colors, Map<String, String> rows) {
    final entries = rows.entries.toList();
    return Container(
      decoration: BoxDecoration(
        color: colors.glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.glassBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _copy(entries[i].value),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      entries[i].key,
                      style: TextStyle(color: colors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        entries[i].value,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != entries.length - 1)
              Divider(height: 1, color: colors.glassBorder),
          ],
        ],
      ),
    );
  }

  Widget _action(
      AppPalette colors, IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.glassBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.accentPrimary),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}