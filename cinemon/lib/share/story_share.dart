import 'dart:io';

import 'package:flutter/services.dart';

/// Where a story can go straight to (ADR 0003, D2).
enum StoryTarget { instagram, facebook }

/// The iOS side lives in `AppDelegate.swift` (`StoryShareChannel`): it puts
/// the images on the pasteboard under Instagram's or Facebook's keys and
/// opens their story composer, or saves an image to Photos.
class StoryShare {
  StoryShare._();

  static const _channel = MethodChannel('app.35mm/story_share');

  /// The Meta app ID both story schemes require, from `dart_defines.json`.
  /// Without it the Instagram and Facebook buttons stay hidden.
  static const metaAppId = String.fromEnvironment('META_APP_ID');

  static bool get _supported => Platform.isIOS;

  /// Whether the app for [target] is installed and we have an app ID.
  static Future<bool> canShare(StoryTarget target) async {
    if (!_supported || metaAppId.isEmpty) return false;
    try {
      return await _channel
              .invokeMethod<bool>('canShare', {'target': target.name}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Opens the story composer. Give [background] for a full-screen card, or
  /// [sticker] with [top] and [bottom] for a card on a gradient. [link]
  /// rides along on the pasteboard for the link sticker (ADR 0003, D3).
  static Future<bool> share(
    StoryTarget target, {
    Uint8List? background,
    Uint8List? sticker,
    Color? top,
    Color? bottom,
    Uri? link,
  }) async {
    if (!_supported || metaAppId.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('share', {
            'target': target.name,
            'appId': metaAppId,
            'background': background,
            'sticker': sticker,
            'top': top == null ? null : _hex(top),
            'bottom': bottom == null ? null : _hex(bottom),
            'link': link?.toString(),
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Saves a PNG to Photos. Asks for permission the first time.
  static Future<SaveResult> saveImage(Uint8List png) async {
    if (!_supported) return SaveResult.failed;
    try {
      final r = await _channel.invokeMethod<String>('saveImage', {'png': png});
      return switch (r) {
        'saved' => SaveResult.saved,
        'denied' => SaveResult.denied,
        _ => SaveResult.failed,
      };
    } on PlatformException {
      return SaveResult.failed;
    }
  }

  static String _hex(Color c) {
    int ch(double v) => (v * 255).round().clamp(0, 255);
    return '#${[
      ch(c.r),
      ch(c.g),
      ch(c.b)
    ].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}';
  }
}

enum SaveResult { saved, denied, failed }
