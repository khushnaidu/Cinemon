import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'liquid_glass.dart';

/// A floating pane of glass that hovers over the screen, inset from every
/// edge, instead of a sheet welded to the bottom.
///
/// Every menu and picker in the app used to be a `showModalBottomSheet` with
/// its own handle, radius, and colours. This is the one replacement: a route
/// on the root navigator (so the shell's native chrome unmounts underneath
/// it — see `shellChromeVisible`), a blurred and dimmed scrim, and a
/// [LiquidGlass] pane that scales and fades in from just below centre.
///
/// [tall] panels fill the safe area and expect their child to size itself
/// with `Expanded` (search + list pickers, editors). Fitted panels wrap their
/// content and sit in the middle of the screen (menus, confirmations).
Future<T?> showGlassPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool tall = false,
  bool dismissible = true,
}) {
  HapticFeedback.lightImpact();
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: dismissible,
    barrierLabel: 'Dismiss',
    // The scrim is drawn by the page itself so it can blur, not just tint.
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (context, animation, secondary) => _GlassPanelRoute(
      animation: animation,
      tall: tall,
      dismissible: dismissible,
      child: Builder(builder: builder),
    ),
    transitionBuilder: (context, animation, secondary, child) => child,
  );
}

class _GlassPanelRoute extends StatelessWidget {
  const _GlassPanelRoute({
    required this.animation,
    required this.tall,
    required this.dismissible,
    required this.child,
  });

  final Animation<double> animation;
  final bool tall;
  final bool dismissible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Scrim: blur and darken whatever is behind, so the glass has
            // something soft to refract and the content beneath stops
            // competing with it.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: dismissible ? () => Navigator.of(context).pop() : null,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18 * t, sigmaY: 18 * t),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18 * t),
                ),
              ),
            ),
            // The pane. Insets are from the safe area, never the screen edge,
            // and the keyboard pushes it up rather than covering it.
            Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: SafeArea(
                minimum: const EdgeInsets.all(AppSpace.lg),
                child: Align(
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 28 * (1 - t)),
                      child: Transform.scale(
                        scale: 0.94 + 0.06 * t,
                        child: tall
                            ? SizedBox.expand(child: GlassPanel(child: child))
                            : GlassPanel(child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The pane itself, without the route. Use directly to float glass inside a
/// screen; use [showGlassPanel] to present it modally.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 28,
    this.tint = 0.22,
  });

  final Widget child;
  final double radius;
  final double tint;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(radius),
      blur: 30,
      tint: tint,
      saturation: 1.8,
      // Material is what gives text fields their selection overlays and rows
      // their press states inside a route that has none of its own.
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Confirmations and toasts
// ─────────────────────────────────────────────────────────────

/// A two-button glass confirmation. Resolves true on confirm.
///
/// Replaces every Material `AlertDialog`: same floating pane as the rest of
/// the app, actions as pills side by side rather than text links in a row.
Future<bool> showGlassConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showGlassPanel<bool>(
    context,
    builder: (panelContext) => Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.sm),
          Text(
            message,
            style: AppText.body.copyWith(color: AppColors.inkSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: GlassPillButton(
                  label: cancelLabel,
                  expand: true,
                  onTap: () => Navigator.of(panelContext).pop(false),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: GlassPillButton(
                  label: confirmLabel,
                  expand: true,
                  prominent: true,
                  destructive: destructive,
                  onTap: () => Navigator.of(panelContext).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// A glass capsule that drops in under the status bar, says one thing, and
/// leaves. The app's replacement for `SnackBar`.
///
/// Lives in the root overlay so it shows above panels and sheets, and
/// survives the screen that raised it being popped — which is why callers
/// can fire it right after `Navigator.pop`.
void showGlassToast(
  BuildContext context,
  String message, {
  IconData? icon,
  bool destructive = false,
  Duration duration = const Duration(milliseconds: 2400),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _GlassToastController.instance.show(
    overlay,
    message: message,
    icon: icon ??
        (destructive
            ? CupertinoIcons.exclamationmark_circle_fill
            : CupertinoIcons.checkmark_circle_fill),
    destructive: destructive,
    duration: duration,
  );
}

/// One toast at a time: a new one replaces whatever is showing.
class _GlassToastController {
  _GlassToastController._();
  static final instance = _GlassToastController._();

  OverlayEntry? _entry;
  Timer? _timer;
  final _key = GlobalKey<_GlassToastState>();

  void show(
    OverlayState overlay, {
    required String message,
    required IconData icon,
    required bool destructive,
    required Duration duration,
  }) {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;

    if (destructive) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    final entry = OverlayEntry(
      builder: (_) => _GlassToast(
        key: _key,
        message: message,
        icon: icon,
        destructive: destructive,
        onDismissed: () {
          _entry?.remove();
          _entry = null;
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, () => _key.currentState?.hide());
  }
}

class _GlassToast extends StatefulWidget {
  const _GlassToast({
    super.key,
    required this.message,
    required this.icon,
    required this.destructive,
    required this.onDismissed,
  });

  final String message;
  final IconData icon;
  final bool destructive;
  final VoidCallback onDismissed;

  @override
  State<_GlassToast> createState() => _GlassToastState();
}

class _GlassToastState extends State<_GlassToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 260),
  );
  bool _hiding = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  Future<void> hide() async {
    if (_hiding) return;
    _hiding = true;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    final tint = widget.destructive ? AppColors.destructive : AppColors.ink;

    return Positioned(
      top: MediaQuery.of(context).padding.top + AppSpace.sm,
      left: AppSpace.lg,
      right: AppSpace.lg,
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) {
            final t = curved.value;
            return Opacity(
              opacity: _controller.value.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -24 * (1 - t)),
                child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
              ),
            );
          },
          child: Center(
            child: GestureDetector(
              onTap: hide,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < 0) hide();
              },
              child: Material(
                type: MaterialType.transparency,
                child: LiquidGlass(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  blur: 22,
                  tint: 0.42,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.md, AppSpace.xl, AppSpace.md),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, size: 18, color: tint),
                        const SizedBox(width: AppSpace.sm + 2),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: AppText.label.copyWith(
                              fontSize: 15,
                              color: AppColors.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Headers, labels, inputs
// ─────────────────────────────────────────────────────────────

/// iOS sheet header: a leading action, a centred title, a trailing action.
///
/// The trailing action is bold, the way "Done" is in every system sheet; the
/// leading one is regular weight so the eye lands on the commit.
class GlassPanelHeader extends StatelessWidget {
  const GlassPanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingLabel,
    this.onLeading,
    this.trailingLabel,
    this.onTrailing,
    this.trailingEnabled = true,
    this.trailingBusy = false,
  });

  final String title;
  final String? subtitle;
  final String? leadingLabel;
  final VoidCallback? onLeading;
  final String? trailingLabel;
  final VoidCallback? onTrailing;
  final bool trailingEnabled;

  /// Swap the trailing label for a spinner while its action runs.
  final bool trailingBusy;

  /// Width reserved on each side for an action, so the title column is the
  /// same width whichever actions exist and never collides with them.
  static const double _gutter = 84;

  @override
  Widget build(BuildContext context) {
    // Set well below the pane's top edge: the 28pt corner radius eats into
    // the first ~20pt visually, so a title centred in a 56pt strip read as
    // jammed against the ceiling. Extra room above, a little below.
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xs),
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
          child: Row(
            children: [
              SizedBox(
                width: _gutter,
                child: leadingLabel == null
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: _HeaderAction(
                            label: leadingLabel!, onTap: onLeading),
                      ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: AppText.headline,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: AppText.caption
                            .copyWith(color: AppColors.inkSecondary),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(
                width: _gutter,
                child: trailingLabel == null
                    ? null
                    : Align(
                        alignment: Alignment.centerRight,
                        child: trailingBusy
                            ? const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: AppSpace.md),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _HeaderAction(
                                label: trailingLabel!,
                                onTap: trailingEnabled ? onTrailing : null,
                                bold: true,
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, this.onTap, this.bold = false});

  final String label;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GlassPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.sm),
        child: Text(
          label,
          style: (bold ? AppText.label : AppText.body).copyWith(
            fontSize: 17,
            color: enabled ? AppColors.ink : AppColors.inkTertiary,
          ),
        ),
      ),
    );
  }
}

/// Small tracked uppercase label above a form section: RATING, REVIEW.
class GlassSectionLabel extends StatelessWidget {
  const GlassSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: AppText.footnote.copyWith(
            color: AppColors.inkTertiary,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

/// The decoration for anything set *into* glass: text wells, strips, thumbs.
/// A faint lightening with a hairline, never a dark slab.
BoxDecoration glassWellDecoration({double radius = AppRadius.lg}) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.07),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.13), width: 0.8),
  );
}

/// A multi-line text well on glass with a quiet character count.
class GlassTextWell extends StatefulWidget {
  const GlassTextWell({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLength,
    this.minLines = 4,
    this.maxLines = 8,
    this.onChanged,
    this.autofocus = false,
    this.style,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String hint;

  /// Overrides the 16pt body style — the Explore composer sets its text in
  /// the style the finished post will use.
  final TextStyle? style;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  State<GlassTextWell> createState() => _GlassTextWellState();
}

class _GlassTextWellState extends State<GlassTextWell> {
  final _focus = FocusNode();

  TextEditingController get controller => widget.controller;
  int? get maxLength => widget.maxLength;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) return;
    // The keyboard takes ~250ms to arrive and the pane shrinks with it; only
    // then does scrolling the well into view land it in the right place.
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted || !_focus.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glassWellDecoration(),
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.sm, AppSpace.lg, AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            focusNode: _focus,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            maxLength: maxLength,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            scrollPadding: const EdgeInsets.only(bottom: 160),
            textCapitalization: widget.textCapitalization,
            cursorColor: AppColors.ink,
            style: widget.style ??
                AppText.body.copyWith(fontSize: 16, color: AppColors.ink),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: (widget.style ?? AppText.body.copyWith(fontSize: 16))
                  .copyWith(color: AppColors.inkTertiary),
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
              // Material's counter sits under the field like a form error.
              // Ours is drawn below by hand, only once there's something to count.
              counterText: '',
            ),
          ),
          if (maxLength != null)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, __) {
                final n = value.text.characters.length;
                if (n == 0) return const SizedBox(height: 2);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '$n / $maxLength',
                    style: AppText.footnote.copyWith(
                      color: n >= maxLength!
                          ? AppColors.destructive
                          : AppColors.inkTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Buttons and selection
// ─────────────────────────────────────────────────────────────

/// A capsule button on glass.
///
/// [prominent] is the primary action: a brighter glass lens — the same
/// treatment as the native tab bar's indicator — never a solid fill. The
/// default is a darker translucent pill for secondary actions and the
/// "edit" / "add" affordances on profile sections.
class GlassPillButton extends StatelessWidget {
  const GlassPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.prominent = false,
    this.destructive = false,
    this.compact = false,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool prominent;
  final bool destructive;

  /// Small form for section headers.
  final bool compact;

  /// Stretch to the parent's width.
  final bool expand;

  /// Show a spinner in place of the label.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final height = compact ? 30.0 : 44.0;
    final fg = destructive
        ? AppColors.destructive
        : (enabled ? AppColors.ink : AppColors.inkTertiary);

    final content = busy
        ? SizedBox(
            width: compact ? 12 : 18,
            height: compact ? 12 : 18,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 13 : 17, color: fg),
                SizedBox(width: compact ? 5 : 7),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppText.label.copyWith(
                    fontSize: compact ? 13 : 15,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final padding = EdgeInsets.symmetric(
      horizontal: compact ? AppSpace.md : AppSpace.lg + AppSpace.xs,
    );
    final radius = BorderRadius.circular(height / 2);

    final body = LiquidGlass(
      borderRadius: radius,
      blur: 16,
      tint: prominent ? 0.40 : 0.18,
      shadow: !compact,
      child: SizedBox(
        height: height,
        width: expand ? double.infinity : null,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (prominent)
              Positioned.fill(
                child: Opacity(
                  opacity: enabled ? 1 : 0.4,
                  child: GlassLens(radius: radius),
                ),
              ),
            // Alignment only when stretching: a Container with alignment
            // grows to fill its constraints, which turned every "fit the
            // label" pill into a full-width bar.
            Container(
              padding: padding,
              alignment: expand ? Alignment.center : null,
              child: content,
            ),
          ],
        ),
      ),
    );

    return GlassPressable(onTap: enabled ? onTap : null, child: body);
  }
}

/// A small selectable capsule: season numbers and the like. Selected is the
/// glass lens, unselected the darker pill.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const height = 32.0;
    final radius = BorderRadius.circular(height / 2);
    return GlassPressable(
      onTap: () {
        if (!selected) HapticFeedback.selectionClick();
        onTap();
      },
      child: LiquidGlass(
        borderRadius: radius,
        blur: 12,
        tint: 0.30,
        shadow: false,
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              // Filled to the chip's edges. Unpositioned in a passthrough
              // Stack, the lens got the row's unbounded width and, having no
              // child, shrank to nothing but its border: a sliver at one end.
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: selected ? 1 : 0,
                  child: GlassLens(radius: radius),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppText.label.copyWith(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AppColors.ink
                          : AppColors.ink.withValues(alpha: 0.6),
                    ),
                    child: Text(label),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A capsule switch with a travelling glass lens — the native tab bar's
/// construction, in Flutter, for places a platform view can't go (inside
/// scrolling content, under panels).
class GlassSegmentedControl extends StatefulWidget {
  const GlassSegmentedControl({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.height = 34,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;

  @override
  State<GlassSegmentedControl> createState() => _GlassSegmentedControlState();
}

class _GlassSegmentedControlState extends State<GlassSegmentedControl>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late Animation<double> _position =
      AlwaysStoppedAnimation(widget.index.toDouble());
  double _from = 0, _to = 0;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.index.toDouble();
  }

  @override
  void didUpdateWidget(GlassSegmentedControl old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = _position.value;
      _to = widget.index.toDouble();
      _position = Tween<double>(begin: _from, end: _to).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.height;
    const inset = 4.0;
    return LiquidGlass(
      borderRadius: BorderRadius.circular(height / 2),
      blur: 16,
      tint: 0.40,
      shadow: false,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, c) {
            final n = widget.labels.length;
            final slot = c.maxWidth / n;
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final pos = _position.value;
                // The lens stretches as it travels and settles back, like the
                // native indicator's extra bounce.
                final phase = math_sin(_controller.value);
                final travel = (_to - _from).abs().clamp(0.0, 2.0);
                final stretch = 1 + phase * 0.18 * travel;
                return Stack(
                  children: [
                    Positioned(
                      left: slot * pos + inset,
                      top: inset,
                      width: slot - inset * 2,
                      height: height - inset * 2,
                      child: Transform.scale(
                        scaleX: stretch,
                        child: GlassLens(height: height - inset * 2),
                      ),
                    ),
                    Row(
                      children: List.generate(n, (i) {
                        final selected = i == widget.index;
                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (i != widget.index) {
                                HapticFeedback.selectionClick();
                                widget.onChanged(i);
                              }
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: AppText.label.copyWith(
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppColors.ink
                                      : AppColors.ink.withValues(alpha: 0.6),
                                ),
                                child: Text(widget.labels[i]),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// sin(πt) without importing dart:math into a widget file for one call.
double math_sin(double t) {
  // Bhaskara's approximation of sin(πt) on [0,1]: within 0.2% and plenty
  // for a stretch curve.
  final x = t.clamp(0.0, 1.0);
  return 16 * x * (1 - x) / (5 - 4 * x * (1 - x));
}

// ─────────────────────────────────────────────────────────────
// Menu rows
// ─────────────────────────────────────────────────────────────

/// One row of a glass menu, at iOS proportions: a 44pt minimum target, a
/// 22pt glyph in a fixed gutter, a fading press state, and a chevron when it
/// leads somewhere.
class GlassMenuRow extends StatelessWidget {
  const GlassMenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.chevron = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool destructive;
  final bool chevron;

  /// Drawn at the end in place of the chevron: a checkmark on the chosen
  /// option, say.
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = destructive ? AppColors.destructive : AppColors.ink;

    return GlassPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Icon(icon, color: tint, size: 22),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppText.body.copyWith(fontSize: 17, color: tint),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppText.caption
                          .copyWith(color: AppColors.inkSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (chevron)
              const Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: AppColors.inkTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

/// The hairline between glass menu rows, indented past the glyph gutter.
class GlassMenuDivider extends StatelessWidget {
  const GlassMenuDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: AppSpace.lg + 36 + AppSpace.sm),
      child: Divider(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Portraits and badges
// ─────────────────────────────────────────────────────────────

/// A person or poster in a pill: a portrait-orientation capsule.
///
/// Circles crop faces badly and posters worse. A 2:3-ish capsule keeps the
/// headroom and reads as the same shape as every other button on glass.
class PillPortrait extends StatelessWidget {
  const PillPortrait({
    super.key,
    required this.imageUrl,
    this.width = 56,
    this.height = 80,
    this.placeholderIcon = CupertinoIcons.person_fill,
    this.dim = false,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final IconData placeholderIcon;

  /// Faded, for results that can no longer be selected.
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(width / 2);
    final url = imageUrl;
    final placeholder = Container(
      color: Colors.white.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(placeholderIcon,
          color: AppColors.inkTertiary, size: width * 0.42),
    );

    return Opacity(
      opacity: dim ? 0.4 : 1,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.16),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: url == null || url.isEmpty
              ? placeholder
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholder,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder,
                ),
        ),
      ),
    );
  }
}

/// A small numeral badge for ranked selections: a glass lens with the number.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: LiquidGlass(
        borderRadius: BorderRadius.circular(11),
        blur: 8,
        tint: 0.45,
        child: GlassLens(
          radius: BorderRadius.circular(11),
          child: Center(
            child: Text(
              '$rank',
              style: AppText.footnote.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small "×" that removes a selection, sitting on the pill's shoulder.
class RemoveBadge extends StatelessWidget {
  const RemoveBadge({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 22,
        height: 22,
        child: LiquidGlass(
          borderRadius: BorderRadius.circular(11),
          blur: 8,
          tint: 0.5,
          child: const Center(
            child: Icon(CupertinoIcons.xmark, size: 11, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// "S2 E5" in a glass lens capsule.
class GlassTag extends StatelessWidget {
  const GlassTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return LiquidGlass(
      borderRadius: radius,
      blur: 10,
      tint: 0.4,
      shadow: false,
      child: GlassLens(
        radius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            text,
            style: AppText.footnote.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

/// Press feedback the iOS way: the target dims while held instead of
/// rippling. Shared by every tappable thing in this file.
class GlassPressable extends StatefulWidget {
  const GlassPressable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<GlassPressable> createState() => _GlassPressableState();
}

class _GlassPressableState extends State<GlassPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 110),
        opacity: _down ? 0.55 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          scale: _down ? 0.97 : 1,
          child: widget.child,
        ),
      ),
    );
  }
}
