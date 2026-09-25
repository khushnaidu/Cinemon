import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../models/explore_post_model.dart';
import '../widgets/glass_panel.dart' show GlassPressable;
import 'critique_colors.dart';
import 'critique_reader.dart';

/// A full page to write a critique on, set the way it will be read: the
/// headline in Instrument Serif, the body in the reader's book face, one
/// scroll for both. The composer keeps the controllers; this only edits
/// them, so Done just goes back to it to tag the film and post.
Future<void> showCritiqueWriter(
  BuildContext context, {
  required TextEditingController headline,
  required TextEditingController body,
  required int maxLength,
  ExploreSubject? subject,
  required ExplorePost Function() preview,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CritiqueWriter(
        headline: headline,
        body: body,
        maxLength: maxLength,
        subject: subject,
        preview: preview,
      ),
    ),
  );
}

class CritiqueWriter extends StatefulWidget {
  const CritiqueWriter({
    super.key,
    required this.headline,
    required this.body,
    required this.maxLength,
    required this.preview,
    this.subject,
  });

  final TextEditingController headline;
  final TextEditingController body;
  final int maxLength;
  final ExploreSubject? subject;
  final ExplorePost Function() preview;

  @override
  State<CritiqueWriter> createState() => _CritiqueWriterState();
}

class _CritiqueWriterState extends State<CritiqueWriter> {
  final _headlineFocus = FocusNode();
  final _bodyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.headline.addListener(_refresh);
    widget.body.addListener(_refresh);
    // Straight to wherever the writing left off.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target =
          widget.headline.text.trim().isEmpty ? _headlineFocus : _bodyFocus;
      target.requestFocus();
      if (target == _bodyFocus) {
        widget.body.selection =
            TextSelection.collapsed(offset: widget.body.text.length);
      }
    });
  }

  @override
  void dispose() {
    widget.headline.removeListener(_refresh);
    widget.body.removeListener(_refresh);
    _headlineFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  int get _words {
    final t = widget.body.text.trim();
    return t.isEmpty ? 0 : t.split(RegExp(r'\s+')).length;
  }

  void _preview() {
    FocusScope.of(context).unfocus();
    showCritiqueReader(context, widget.preview(), preview: true);
  }

  // The page takes the film's colours as soon as it's tagged, the same ones
  // the preview (id 'preview') and the posted piece will have.
  @override
  Widget build(BuildContext context) => CritiqueColorScope(
        subject: widget.subject,
        seed: 'preview',
        builder: _page,
      );

  Widget _page(BuildContext context) {
    final c = CritiqueColors.of(context);
    final words = _words;
    final chars = widget.body.text.characters.length;
    final nearLimit = chars > widget.maxLength * 0.85;
    final canPreview = widget.headline.text.trim().isNotEmpty && words > 0;
    final subject = widget.subject;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.ground,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                child: Row(
                  children: [
                    _BarButton(
                      label: 'Preview',
                      icon: CupertinoIcons.book,
                      onTap: canPreview ? _preview : null,
                    ),
                    Expanded(
                      child: Text(
                        nearLimit
                            ? '$chars / ${widget.maxLength}'
                            : words == 0
                                ? 'CRITIQUE'
                                : '$words WORD${words == 1 ? '' : 'S'}  ·  ${(words / 230).ceil()} MIN',
                        textAlign: TextAlign.center,
                        style: critiqueMonoStyle(11, alpha: 0.55).copyWith(
                          color: nearLimit && chars >= widget.maxLength
                              ? AppColors.destructive
                              : null,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    _BarButton(
                      label: 'Done',
                      prominent: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  children: [
                    Text(
                      subject == null
                          ? 'CRITIQUE'
                          : 'CRITIQUE  ·  ON ${subject.title.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: critiqueMonoStyle(11, alpha: 1)
                          .copyWith(color: c.accent),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: widget.headline,
                      focusNode: _headlineFocus,
                      minLines: 1,
                      maxLines: null,
                      maxLength: 120,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\n')),
                      ],
                      onSubmitted: (_) => _bodyFocus.requestFocus(),
                      cursorColor: c.accent,
                      style: const TextStyle(
                        fontFamily: 'InstrumentSerif',
                        fontSize: 40,
                        height: 1.02,
                        color: Colors.white,
                      ),
                      decoration: _bare('Headline').copyWith(
                        hintStyle: TextStyle(
                          fontFamily: 'InstrumentSerif',
                          fontSize: 40,
                          height: 1.02,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 18),
                      height: 0.6,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    TextField(
                      controller: widget.body,
                      focusNode: _bodyFocus,
                      minLines: 14,
                      maxLines: null,
                      maxLength: widget.maxLength,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: c.accent,
                      // Keep the line being typed well clear of the keyboard.
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      style: critiqueBodyStyle(color: c.ink),
                      decoration: _bare(
                        'Make your argument.\n\n'
                        'Return starts a new paragraph. The first one opens '
                        'with a drop cap.',
                      ).copyWith(
                        hintMaxLines: 6,
                        hintStyle: critiqueBodyStyle().copyWith(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static InputDecoration _bare(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        counterText: '',
      );
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.prominent = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GlassPressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.35,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: prominent ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: prominent
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppText.label.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: prominent
                      ? CritiqueColors.of(context).ground
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The unposted critique, kept on the phone so a long piece survives the
/// app closing. One draft: a new critique picks it up.
class CritiqueDraft {
  static const _key = 'explore.critique_draft.v1';

  static Future<({String headline, String body})?> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_key);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final headline = m['headline'] as String? ?? '';
      final body = m['body'] as String? ?? '';
      if (headline.trim().isEmpty && body.trim().isEmpty) return null;
      return (headline: headline, body: body);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(String headline, String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (headline.trim().isEmpty && body.trim().isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(
            _key, jsonEncode({'headline': headline, 'body': body}));
      }
    } catch (_) {}
  }

  static Future<void> clear() => save('', '');
}

/// Saves a draft a moment after the typing stops.
class CritiqueDraftSaver {
  Timer? _timer;

  void schedule(String headline, String body) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700),
        () => CritiqueDraft.save(headline, body));
  }

  void flush(String headline, String body) {
    _timer?.cancel();
    CritiqueDraft.save(headline, body);
  }

  void cancel() => _timer?.cancel();
}
