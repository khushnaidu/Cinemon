import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/legal.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_panel.dart';

/// The age gate and terms agreement shared by sign-up and the agree screen.
///
/// The age question is neutral, the way the FTC's COPPA guidance asks: a
/// plain date of birth, nothing suggesting what the answer should be, and no
/// mention of a minimum until after it's answered. Only the outcome is kept
/// (whether the person is under 18), never the date.

const _blockedKey = 'age_gate_blocked';

/// Whether someone on this device has already answered under 13. Once they
/// have, sign-up stays closed here, so going back to pick an older date
/// doesn't work.
Future<bool> ageGateBlocked() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_blockedKey) ?? false;
  } catch (_) {
    return false;
  }
}

Future<void> blockAgeGate() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blockedKey, true);
  } catch (_) {}
}

/// "Date of birth", as a glass field that opens a date wheel.
class DateOfBirthField extends StatelessWidget {
  const DateOfBirthField(
      {super.key, required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    var picked = value ?? DateTime(now.year, now.month, now.day);
    final done = await showGlassPanel<bool>(
      context,
      builder: (panelContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassPanelHeader(
            title: 'Date of birth',
            leadingLabel: 'Cancel',
            onLeading: () => Navigator.of(panelContext).pop(false),
            trailingLabel: 'Done',
            onTrailing: () => Navigator.of(panelContext).pop(true),
          ),
          SizedBox(
            height: 216,
            child: CupertinoTheme(
              data: const CupertinoThemeData(brightness: Brightness.dark),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: picked,
                minimumDate: DateTime(now.year - 120),
                maximumDate: DateTime(now.year, now.month, now.day),
                onDateTimeChanged: (d) => picked = d,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
        ],
      ),
    );
    if (done == true) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    return GlassPressable(
      onTap: () => _pick(context),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        decoration: glassWellDecoration(radius: AppRadius.md + 2),
        child: Row(
          children: [
            const Icon(CupertinoIcons.calendar,
                size: 20, color: AppColors.inkSecondary),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                v == null
                    ? 'Date of birth'
                    : '${_months[v.month - 1]} ${v.day}, ${v.year}',
                style: AppText.body.copyWith(
                  fontSize: 17,
                  color: v == null ? AppColors.inkTertiary : AppColors.ink,
                ),
              ),
            ),
            const Icon(CupertinoIcons.chevron_down,
                size: 14, color: AppColors.inkTertiary),
          ],
        ),
      ),
    );
  }
}

/// "I agree to the Terms of Use and Privacy Policy", with the links, as a
/// checkbox that must be ticked.
class TermsCheckbox extends StatefulWidget {
  const TermsCheckbox(
      {super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<TermsCheckbox> createState() => _TermsCheckboxState();
}

class _TermsCheckboxState extends State<TermsCheckbox> {
  late final _terms = TapGestureRecognizer()..onTap = () => _open(kTermsUrl);
  late final _privacy = TapGestureRecognizer()
    ..onTap = () => _open(kPrivacyUrl);

  static Future<void> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(
      color: AppColors.ink,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.inkTertiary,
    );
    return Semantics(
      checked: widget.value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onChanged(!widget.value),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                child: Icon(
                  widget.value
                      ? CupertinoIcons.checkmark_square_fill
                      : CupertinoIcons.square,
                  key: ValueKey(widget.value),
                  size: 22,
                  color: widget.value ? AppColors.ink : AppColors.inkTertiary,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: AppText.caption
                      .copyWith(color: AppColors.inkSecondary, height: 1.45),
                  children: [
                    const TextSpan(text: 'I agree to 35mm\'s '),
                    TextSpan(
                        text: 'Terms of Use', style: link, recognizer: _terms),
                    const TextSpan(text: ' and '),
                    TextSpan(
                        text: 'Privacy Policy',
                        style: link,
                        recognizer: _privacy),
                    const TextSpan(
                        text: '. There\'s no tolerance for objectionable '
                            'content or abusive users.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of the form once someone on this device is under 13.
class AgeGateClosed extends StatelessWidget {
  const AgeGateClosed({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xl),
      child: Column(
        children: [
          const Icon(CupertinoIcons.hand_raised,
              size: 32, color: AppColors.inkTertiary),
          const SizedBox(height: AppSpace.md),
          Text('Sorry, you can\'t use 35mm',
              style: AppText.headline, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.sm),
          Text(
            'Based on the date of birth you gave, you\'re not able to create '
            'an account.',
            style: AppText.body.copyWith(color: AppColors.inkSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
