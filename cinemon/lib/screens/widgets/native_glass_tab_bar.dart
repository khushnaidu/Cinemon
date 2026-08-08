import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'liquid_glass.dart';

/// A tab bar backed by Apple's real Liquid Glass.
///
/// On iOS this embeds a SwiftUI control as a platform view (see
/// `ios/Runner/LiquidGlassTabBar.swift`). That is the only way to get genuine
/// refraction: [BackdropFilter] can blur and recolour the backdrop but cannot
/// displace it, and refraction *is* displacement. Everywhere else this falls
/// back to [LiquidGlassTabBar], which gets the colour right and the warping
/// not at all.
///
/// Selection and compact state are pushed to the native view over the method
/// channel — the SwiftUI side owns its own state and will otherwise drift out
/// of sync with Flutter's routing.
class NativeGlassTabBar extends StatefulWidget {
  const NativeGlassTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.compact = false,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassTabItem> items;
  final bool compact;

  static const double barHeight = 56;
  static const double compactHeight = 44;

  @override
  State<NativeGlassTabBar> createState() => _NativeGlassTabBarState();
}

class _NativeGlassTabBarState extends State<NativeGlassTabBar> {
  MethodChannel? _channel;

  static bool get _useNative => !kIsWeb && Platform.isIOS;

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('cinemon/liquid_glass_tab_bar_$id')
      ..setMethodCallHandler((call) async {
        if (call.method == 'onSelect') {
          widget.onTap(call.arguments as int);
        }
      });
    // The view was created with the index it had at construction time; if the
    // route changed in between, correct it now.
    _channel!.invokeMethod('setIndex', widget.currentIndex);
    _channel!.invokeMethod('setCompact', widget.compact);
  }

  @override
  void didUpdateWidget(NativeGlassTabBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _channel?.invokeMethod('setIndex', widget.currentIndex);
    }
    if (old.compact != widget.compact) {
      _channel?.invokeMethod('setCompact', widget.compact);
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
      return LiquidGlassTabBar(
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        compact: widget.compact,
        items: widget.items
            .map((i) => LiquidGlassTabItem(
                  icon: i.fallbackIcon,
                  activeIcon: i.fallbackActiveIcon,
                  label: i.label,
                ))
            .toList(),
      );
    }

    // Constant height: the compact transition happens inside SwiftUI. Driving
    // the platform view's height from Flutter resizes the underlying UIView
    // every frame, which stutters.
    return SizedBox(
      height: NativeGlassTabBar.barHeight,
      child: UiKitView(
        viewType: 'cinemon/liquid_glass_tab_bar',
        creationParams: <String, dynamic>{
          'initialIndex': widget.currentIndex,
          'items': widget.items
              .map((i) => <String, dynamic>{
                    'icon': i.symbol,
                    'activeIcon': i.activeSymbol,
                    'label': i.label,
                  })
              .toList(),
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

/// A destination, described once for both the native and fallback bars.
class GlassTabItem {
  const GlassTabItem({
    required this.symbol,
    required this.activeSymbol,
    required this.label,
    required this.fallbackIcon,
    required this.fallbackActiveIcon,
  });

  /// SF Symbol names, used by the native control.
  final String symbol;
  final String activeSymbol;

  final String label;

  /// Flutter icons, used only when the native bar isn't available.
  final IconData fallbackIcon;
  final IconData fallbackActiveIcon;
}
