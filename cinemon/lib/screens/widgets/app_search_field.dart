import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material;

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
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String placeholder;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    // CupertinoSearchTextField's clear button uses a Cupertino tap target that
    // expects a Material ancestor when hosted in a Material app route.
    return Material(
      color: AppColors.canvas,
      child: CupertinoSearchTextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        placeholder: placeholder,
        backgroundColor: AppColors.surface,
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
