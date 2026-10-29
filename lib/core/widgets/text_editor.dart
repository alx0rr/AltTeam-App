import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import '../widgets/app_snackbar.dart';
import '../api/repositories/links.dart';

class AminoTextEditor extends StatefulWidget {
  final TextEditingController controller;
  final List<dynamic> mediaList;
  final String? hint;
  final int minLines;
  final double maxHeight;
  final bool enabled;

  const AminoTextEditor({
    super.key,
    required this.controller,
    required this.mediaList,
    this.hint,
    this.minLines = 4,
    this.maxHeight = 320,
    this.enabled = true,
  });

  
  static List<dynamic> pruneMediaList(String content, List<dynamic> mediaList) {
    return mediaList.where((e) {
      if (e is List && e.length >= 4 && e[3] is String) {
        return content.contains('[IMG=${e[3]}]');
      }
      return true;
    }).toList();
  }

  @override
  State<AminoTextEditor> createState() => _AminoTextEditorState();
}

class _AminoTextEditorState extends State<AminoTextEditor> {
  static final _lineMarker = RegExp(r'^\[([BIUSCbiusc]+)\]');
  static const _flagOrder = ['B', 'I', 'U', 'S', 'C'];

  final _picker = ImagePicker();
  bool _uploading = false;

  TextEditingController get _c => widget.controller;


  void _toggleLineFlag(String flag) {
    final text = _c.text;
    var sel = _c.selection;
    if (!sel.isValid) sel = TextSelection.collapsed(offset: text.length);
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);

    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    var lineEnd = text.indexOf('\n', end);
    if (lineEnd == -1) lineEnd = text.length;

    final block = text.substring(lineStart, lineEnd);
    final lines = block.split('\n');

    final allHave = lines.every((l) {
      final m = _lineMarker.firstMatch(l);
      return m != null && m.group(1)!.toUpperCase().contains(flag);
    });

    final newLines = lines.map((l) {
      var flags = <String>{};
      var rest = l;
      final m = _lineMarker.firstMatch(l);
      if (m != null) {
        flags = m.group(1)!.toUpperCase().split('').toSet();
        rest = l.substring(m.end);
      }
      allHave ? flags.remove(flag) : flags.add(flag);
      if (flags.isEmpty) return rest;
      final ordered = _flagOrder.where(flags.contains).join();
      return '[$ordered]$rest';
    }).join('\n');

    final newText = text.replaceRange(lineStart, lineEnd, newLines);
    final delta = newLines.length - block.length;
    _c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (end + delta).clamp(0, newText.length)),
    );
    setState(() {});
  }

  bool _flagActiveAtCursor(String flag) {
    final text = _c.text;
    var pos = _c.selection.isValid ? _c.selection.start : text.length;
    pos = pos.clamp(0, text.length);
    final lineStart = pos == 0 ? 0 : text.lastIndexOf('\n', pos - 1) + 1;
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd == -1) lineEnd = text.length;
    final m = _lineMarker.firstMatch(text.substring(lineStart, lineEnd));
    return m != null && m.group(1)!.toUpperCase().contains(flag);
  }


  void _insertAtCursor(String snippet) {
    final text = _c.text;
    final sel = _c.selection;
    final pos = (sel.isValid ? sel.start : text.length).clamp(0, text.length);
    final endPos = (sel.isValid ? sel.end : text.length).clamp(0, text.length);
    final newText = text.replaceRange(pos, endPos, snippet);
    _c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + snippet.length),
    );
    setState(() {});
  }

  Future<void> _insertLink() async {
    final colors = AppColors.of(context);
    final urlController = TextEditingController(text: 'https://');

    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.glassFillStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.t('editor.link_dialog_title'),
          style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: urlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: AppLocalizations.t('editor.link_url_hint'),
            hintStyle: TextStyle(color: colors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.t('common.cancel'), style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(urlController.text.trim()),
            child: Text(
              AppLocalizations.t('editor.insert'),
              style: TextStyle(color: colors.accentPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty || url == 'https://') return;
    _insertAtCursor(url);
  }

  String _genRef() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    String ref;
    do {
      ref = List.generate(4, (_) => chars[rnd.nextInt(chars.length)]).join();
    } while (widget.mediaList.any((e) => e is List && e.length >= 4 && e[3] == ref));
    return ref;
  }

  Future<void> _insertImage() async {
    XFile? image;
    try {
      image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, e.toString(), type: SnackType.error);
      return;
    }
    if (image == null) return;

    setState(() => _uploading = true);
    try {
      final res = await LinksRepository().uploadMedia(file: image);
      final url = res['mediaValue'];
      final ref = _genRef();
      widget.mediaList.add([100, url, null, ref]);
      _insertAtCursor('\n[IMG=$ref]\n');
    } catch (e) {
      if (mounted) AppSnackbar.show(context, e.toString(), type: SnackType.error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeImage(List media) {
    final ref = media.length >= 4 ? media[3] : null;
    setState(() {
      widget.mediaList.remove(media);
      if (ref is String) {
        _c.text = _c.text
            .replaceAll('\n[IMG=$ref]\n', '\n')
            .replaceAll('[IMG=$ref]', '');
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final inlineImages = widget.mediaList
        .whereType<List>()
        .where((e) => e.length >= 4 && e[3] is String)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildToolbar(colors),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: TextFormField(
            controller: widget.controller,
            enabled: widget.enabled,
            minLines: widget.minLines,
            maxLines: null,
            onChanged: (_) => setState(() {}),
            onTap: () => setState(() {}),
            style: TextStyle(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: colors.textMuted),
            ),
          ),
        ),
        if (inlineImages.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            AppLocalizations.t('editor.attached_images'),
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: inlineImages.map((m) => _imageThumb(colors, m)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildToolbar(AppPalette colors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _toolButton(colors, Icons.format_bold_rounded, 'editor.format_bold',
              active: _flagActiveAtCursor('B'), onTap: () => _toggleLineFlag('B')),
          _toolButton(colors, Icons.format_italic_rounded, 'editor.format_italic',
              active: _flagActiveAtCursor('I'), onTap: () => _toggleLineFlag('I')),
          _toolButton(colors, Icons.format_underlined_rounded, 'editor.format_underline',
              active: _flagActiveAtCursor('U'), onTap: () => _toggleLineFlag('U')),
          _toolButton(colors, Icons.strikethrough_s_rounded, 'editor.format_strike',
              active: _flagActiveAtCursor('S'), onTap: () => _toggleLineFlag('S')),
          _toolButton(colors, Icons.format_align_center_rounded, 'editor.format_center',
              active: _flagActiveAtCursor('C'), onTap: () => _toggleLineFlag('C')),
          Container(
            width: 1,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: colors.textMuted.withOpacity(0.3),
          ),
          _toolButton(colors, Icons.link_rounded, 'editor.insert_link', onTap: _insertLink),
          _uploading
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colors.accentPrimary),
                  ),
                )
              : _toolButton(colors, Icons.image_rounded, 'editor.insert_image', onTap: _insertImage),
        ],
      ),
    );
  }

  Widget _toolButton(
    AppPalette colors,
    IconData icon,
    String tooltipKey, {
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: AppLocalizations.t(tooltipKey),
      child: InkWell(
        onTap: widget.enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(7),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? colors.accentPrimary.withOpacity(0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? colors.accentPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _imageThumb(AppPalette colors, List media) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            media[1].toString(),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 64,
              height: 64,
              color: colors.textMuted.withOpacity(0.2),
              child: Icon(Icons.broken_image_rounded, color: colors.textMuted, size: 20),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => _removeImage(media),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.85),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}