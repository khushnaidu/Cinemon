import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// A single-line field set into glass (ADR 0004 D8): the auth screens,
/// onboarding, and anywhere a form needs one line.
///
/// Focus brightens the well and its rim instead of drawing a white outline.
/// An error shows as a line of text under the field, not a toast, and tints
/// the rim.
class GlassTextField extends StatefulWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.icon,
    this.obscure = false,
    this.errorText,
    this.helper,
    this.trailing,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController controller;
  final String placeholder;

  /// A leading SF-style glyph.
  final IconData? icon;

  /// A password: hidden, with a show/hide toggle at the end.
  final bool obscure;

  /// Shown under the field in red when set.
  final String? errorText;

  /// Shown under the field when there's no error: a checklist, a hint.
  final Widget? helper;

  /// Anything at the end of the field, such as a spinner or a tick.
  final Widget? trailing;

  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  bool _hidden = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(GlassTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final error = widget.errorText;
    final rim = error != null
        ? AppColors.destructive.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: focused ? 0.34 : 0.13);
    final text = widget.style ??
        AppText.body.copyWith(fontSize: 17, color: AppColors.ink);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: focused ? 0.11 : 0.07),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: rim, width: focused ? 1 : 0.8),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 19,
                  color: focused ? AppColors.ink : AppColors.inkTertiary,
                ),
                const SizedBox(width: AppSpace.md),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  obscureText: widget.obscure && _hidden,
                  enableSuggestions: !widget.obscure,
                  autocorrect: false,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  textCapitalization: widget.textCapitalization,
                  autofillHints: widget.autofillHints,
                  inputFormatters: [
                    if (widget.maxLength != null)
                      LengthLimitingTextInputFormatter(widget.maxLength),
                    ...?widget.inputFormatters,
                  ],
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  textAlign: widget.textAlign,
                  cursorColor: AppColors.ink,
                  style: text,
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: text.copyWith(color: AppColors.inkTertiary),
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: AppSpace.sm),
                widget.trailing!,
              ],
              if (widget.obscure)
                GestureDetector(
                  onTap: () => setState(() => _hidden = !_hidden),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpace.sm),
                    child: Icon(
                      _hidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                      size: 19,
                      color: AppColors.inkTertiary,
                      semanticLabel:
                          _hidden ? 'Show password' : 'Hide password',
                    ),
                  ),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: error != null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.xs, AppSpace.sm, AppSpace.xs, 0),
                  child: Text(
                    error,
                    style: AppText.caption.copyWith(
                      color: AppColors.destructive,
                    ),
                  ),
                )
              : widget.helper != null
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.xs, AppSpace.sm, AppSpace.xs, 0),
                      child: widget.helper,
                    )
                  : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The password rules as a live checklist under the field: each line ticks
/// as it's met.
class ChecklistLine extends StatelessWidget {
  const ChecklistLine({super.key, required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AppColors.success : AppColors.inkTertiary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              met
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              key: ValueKey(met),
              size: 14,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: AppText.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}
