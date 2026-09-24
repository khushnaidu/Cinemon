import 'dart:io';

import 'package:flutter/services.dart';

/// Where a card can go straight to (ADR 0003, D2).
enum StoryTarget { instagram, facebook, snapchat, messages }

/// The iOS side lives in `AppDelegate.swift` (`StoryShareChannel`): it puts
/// the images on the pasteboard under Instagram's, Facebook's or Snapchat's
/// keys and opens their composer, opens the message composer, or saves an
/// image to Photos.
class StoryShare {
  StoryShare._();

  static const _channel = MethodChannel('app.35mm/story_share');

  /// The Meta app ID both story schemes require, from `dart_defines.json`.
  /// Without it the Instagram and Facebook buttons stay hidden.
  static const metaAppId = String.fromEnvironment('META_APP_ID');

  /// Snap's Creative Kit client ID, from `dart_defines.json`. Without it the
  /// Snapchat button stays hidden.
  static const snapClientId = String.fromEnvironment('SNAP_CLIENT_ID');

  static bool get _supported => Platform.isIOS;

  static bool _configured(StoryTarget target) => switch (target) {
        StoryTarget.instagram || StoryTarget.facebook => metaAppId.isNotEmpty,
        StoryTarget.snapchat => snapClientId.isNotEmpty,
        StoryTarget.messages => true,
      };

  /// Whether [target] can be used here: the app is installed (or the phone
  /// can send messages with attachments) and we have its ID.
  static Future<bool> canShare(StoryTarget target) async {
    if (!_supported || !_configured(target)) return false;
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

  /// Opens Snapchat's preview with [png] as the Snap and [caption] (the
  /// link) over it.
  static Future<bool> snapchat(Uint8List png, {String? caption}) async {
    if (!_supported || snapClientId.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('snapchat', {
            'clientId': snapClientId,
            'background': png,
            'caption': caption,
          }) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Opens the message composer with [png] attached and [body] as the text.
  static Future<MessageResult> message(Uint8List png, {String? body}) async {
    if (!_supported) return MessageResult.failed;
    try {
      final r = await _channel
          .invokeMethod<String>('message', {'png': png, 'body': body});
      return switch (r) {
        'sent' => MessageResult.sent,
        'cancelled' => MessageResult.cancelled,
        _ => MessageResult.failed,
      };
    } on PlatformException {
      return MessageResult.failed;
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

enum MessageResult { sent, cancelled, failed }
