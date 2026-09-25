import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/glass_panel.dart';

const _site = 'https://35mm.contact';

/// The fonts bundled with the app, each with the licence it ships under.
const _fontLicences = {
  '3D Isometric': 'assets/fonts/OFL-3disometric.txt',
  'IBM Plex Mono': 'assets/fonts/share/OFL-ibmplexmono.txt',
  'Instrument Serif': 'assets/fonts/share/OFL-instrumentserif.txt',
  'Big Shoulders Display': 'assets/fonts/share/OFL-bigshouldersdisplay.txt',
  'Reenie Beanie': 'assets/fonts/share/OFL-reeniebeanie.txt',
  'Brafesuit': 'assets/fonts/username/1001fonts-brafesuit-eula.txt',
};

/// Adds the bundled fonts' licences to the ones Flutter and the packages
/// register, so Licences lists everything the app ships. Called once at
/// start-up.
void registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final entry in _fontLicences.entries) {
      yield LicenseEntryWithLineBreaks(
          [entry.key], await rootBundle.loadString(entry.value));
    }
  });
}

Future<void> _open(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);

/// Settings → About: the terms, the privacy policy, how to reach us, and
/// credit to the services the app is built on.
Future<void> showAboutPanel(BuildContext context) {
  return showGlassPanel<void>(
    context,
    builder: (panelContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassPanelHeader(
          title: 'About 35mm',
          trailingLabel: 'Done',
          onTrailing: () => Navigator.of(panelContext).pop(),
        ),
        const SizedBox(height: AppSpace.xs),
        GlassMenuRow(
          icon: CupertinoIcons.doc_text,
          title: 'Terms of Use',
          chevron: true,
          onTap: () => _open('$_site/terms'),
        ),
        const GlassMenuDivider(),
        GlassMenuRow(
          icon: CupertinoIcons.lock_shield,
          title: 'Privacy Policy',
          chevron: true,
          onTap: () => _open('$_site/privacy'),
        ),
        const GlassMenuDivider(),
        GlassMenuRow(
          icon: CupertinoIcons.question_circle,
          title: 'Help and contact',
          subtitle: 'Questions, problems, or something to report',
          chevron: true,
          onTap: () => _open('$_site/support'),
        ),
        const GlassMenuDivider(),
        GlassMenuRow(
          icon: CupertinoIcons.book,
          title: 'Licences',
          subtitle: 'Fonts and open-source software',
          chevron: true,
          onTap: () {
            Navigator.of(panelContext).pop();
            showLicensePage(
              context: context,
              applicationName: '35mm',
              applicationLegalese: 'Film data from TMDB. Streaming '
                  'availability from JustWatch.',
            );
          },
        ),
        const SizedBox(height: AppSpace.lg),
        const _TmdbCredit(),
        const SizedBox(height: AppSpace.lg),
      ],
    ),
  );
}

/// TMDB's terms ask every app using its API to say so, with its logo, and
/// that it isn't endorsed by them.
class _TmdbCredit extends StatelessWidget {
  const _TmdbCredit();

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: () => _open('https://www.themoviedb.org'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        child: Column(
          children: [
            Image.asset(
              'assets/images/tmdb_logo.png',
              height: 14,
              errorBuilder: (_, __, ___) => Text(
                'TMDB',
                style: AppText.headline.copyWith(
                  color: const Color(0xFF01B4E4),
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'This product uses the TMDB API but is not endorsed or '
              'certified by TMDB. Streaming availability by JustWatch.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: AppColors.inkTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
