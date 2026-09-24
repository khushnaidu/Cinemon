import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Material;

import '../../core/theme/app_theme.dart';

/// The app's one search field.
///
/// There were three hand-rolled versions before this — a pill with an outline
/// on user search, a borderless one inside a rounded `Container` on film
/// search, another variant on friends — with radii of 25 and 30, different
/// fills, Material glyphs, and a clear button reimplemented each time. That
/// inconsistency is what made search look off from screen to screen.
///
/// This wraps [CupertinoSearchTextField], so the metrics, the magnifier, the
/// clear button and its show/hide behaviour are Apple's rather than
/// approximations of them. iOS search fields are a rounded rectangle at
/// radius ~10, not a pill — the pill is the single biggest reason the old
/// ones read as Android.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.placeholder = 'Search',
    this.autofocus = false,
    this.onSubmitted,
    this.onGlass = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String placeholder;
  final bool autofocus;

  /// Inside a glass panel there is no canvas to sit on: the Material behind
  /// the field goes transparent and the fill lightens so it reads as a well
  /// in the pane rather than a dark slab pasted onto it.
  final bool onGlass;

  @override
  Widget build(BuildContext context) {
    // CupertinoSearchTextField's clear button uses a Cupertino tap target that
    // expects a Material ancestor when hosted in a Material app route.
    return Material(
      color: onGlass ? Colors.transparent : AppColors.canvas,
      child: CupertinoSearchTextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        placeholder: placeholder,
        backgroundColor:
            onGlass ? Colors.white.withValues(alpha: 0.10) : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        itemColor: AppColors.inkSecondary,
        style: AppText.body.copyWith(color: AppColors.ink),
        placeholderStyle: AppText.body.copyWith(color: AppColors.inkTertiary),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.sm + 2,
        ),
      ),
    );
  }
}
