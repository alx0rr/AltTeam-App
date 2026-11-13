import 'package:flutter/material.dart';

import '../../core/api/repositories/altacm.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/user_avatar.dart';

class ModerationHistoryTab extends StatefulWidget {
  const ModerationHistoryTab({
    super.key,
    required this.uid,
    required this.ndcId,
  });

  final String uid;
  final int ndcId;

  @override
  State<ModerationHistoryTab> createState() => _ModerationHistoryTabState();
}

class _ModerationHistoryTabState extends State<ModerationHistoryTab> {
  static const int _pageSize = 25;

  final _repo = AltACMRepository();
  final List<Map<String, dynamic>> _items = [];

  String? _nextToken;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.getObjectModerationHistory(
        widget.ndcId,
        widget.uid,
        _nextToken,
        size: _pageSize,
      );
      final list = (res['adminLogList'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final next = (res['paging'] as Map?)?['nextPageToken'] as String?;
      if (!mounted) return;
      setState(() {
        _items.addAll(list);
        _nextToken = next;
        _hasMore = next != null && next.isNotEmpty && list.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    String p(int v) => v.toString().padLeft(2, '0');
    return '${p(d.day)}.${p(d.month)}.${d.year} ${p(d.hour)}:${p(d.minute)}';
  }

  Color _levelColor(String? level, AppPalette colors) {
    switch (level) {
      case 'danger':
        return colors.error;
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      default:
        return colors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_items.isEmpty && !_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Center(
          child: Text(
            _error ?? AppLocalizations.t('admin.history.empty'),
            style: TextStyle(color: colors.textMuted),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final log in _items) _tile(log, colors),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, style: TextStyle(color: colors.error)),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_hasMore)
          TextButton(
            onPressed: _load,
            child: Text(
              AppLocalizations.t('admin.history.load_more'),
              style: TextStyle(color: colors.accentPrimary),
            ),
          ),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> log, AppPalette colors) {
    const radius = BorderRadius.all(Radius.circular(16));
    final author = (log['author'] as Map?) ?? const {};
    final extData = (log['extData'] as Map?) ?? const {};
    final color = _levelColor(log['operationLevel'] as String?, colors);

    final detail = ((log['operationDetail'] as String?)?.trim().isNotEmpty ??
            false)
        ? log['operationDetail'] as String
        : (extData['message'] as String? ?? '');

    final icon = author['icon'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.glassFill,
          borderRadius: radius,
          border: Border.all(color: colors.glassBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(
              nickname: '${author['nickname'] ?? '-'}',
              iconUrl: icon is String && icon.startsWith('http') ? icon : null,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log['operationName'] ?? ''}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    '${author['nickname'] ?? '-'} · ${_fmt(log['createdTime'] as String?)}',
                    style: TextStyle(color: colors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}