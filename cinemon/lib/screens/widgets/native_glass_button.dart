import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// A circular button made of Apple's real Liquid Glass.
///
/// On iOS this embeds a SwiftUI control as a platform view (see
/// `ios/Runner/LiquidGlassButton.swift`), for the same reason the tab bar
/// does: only the native material refracts what passes underneath it.
/// Elsewhere it falls back to a blurred circle, which gets the colour right
/// and the warping not at all.
///
/// Mount these only while [shellChromeVisible] holds — a platform view
/// composites above every Flutter layer, so one left mounted under a sheet
/// floats on top of it.
class NativeGlassButton extends StatefulWidget {
  const NativeGlassButton({
    super.key,
    required this.symbol,
    required this.label,
    required this.onTap,
    this.fallbackIcon,
    this.badge = 0,
    this.size = 52,
  });

  /// SF Symbol name, used by the native control.
  final String symbol;

  /// Accessibility label, and the tooltip on the fallback.
  final String label;

  final VoidCallback onTap;

  /// Used only when the native button isn't available.
  final IconData? fallbackIcon;

  /// Unread count. Drawn natively — a Flutter badge positioned over a platform
  /// view would render behind it.
  final int badge;

  /// Outer size. The circle itself is 10pt smaller; the gutter is where the
  /// badge sits, since the hosting view can clip.
  final double size;

  @override
  State<NativeGlassButton> createState() => _NativeGlassButtonState();
}

class _NativeGlassButtonState extends State<NativeGlassButton> {
  MethodChannel? _channel;

  static bool get _useNative => !kIsWeb && Platform.isIOS;

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('cinemon/liquid_glass_button_$id')
      ..setMethodCallHandler((call) async {
        if (call.method == 'onTap') widget.onTap();
      });
    // The view was created with the count it had at construction time; if it
    // changed in between, correct it now.
    _channel!.invokeMethod('setBadge', widget.badge);
  }

  @override
  void didUpdateWidget(NativeGlassButton old) {
    super.didUpdateWidget(old);
    if (old.badge != widget.badge) {
      _channel?.invokeMethod('setBadge', widget.badge);
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_useNative) {
      return _FallbackGlassButton(
        icon: widget.fallbackIcon ?? Icons.circle_outlined,
        label: widget.label,
        onTap: widget.onTap,
        badge: widget.badge,
        size: widget.size,
      );
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: UiKitView(
        viewType: 'cinemon/liquid_glass_button',
        creationParams: <String, dynamic>{
          'icon': widget.symbol,
          'label': widget.label,
          'badge': widget.badge,
        },
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        // The control owns its gestures; letting Flutter claim them first
        // swallows the presses and kills the interactive press response.
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      ),
    );
  }
}

class _FallbackGlassButton extends StatelessWidget {
  const _FallbackGlassButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.badge,
    required this.size,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final double size;

  @override
  Widget build(BuildContext context) {
    final d = size - 10;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: d,
                height: d,
                color: Colors.black.withValues(alpha: 0.35),
                child: Semantics(
                  label: label,
                  button: true,
                  child: IconButton(
                    icon: Icon(icon, color: AppColors.ink, size: d * 0.40),
                    onPressed: onTap,
                  ),
                ),
              ),
            ),
          ),
          if (badge > 0)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.destructive,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: AppText.footnote.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
