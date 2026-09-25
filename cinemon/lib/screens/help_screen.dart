import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/legal.dart';
import '../core/theme/app_theme.dart';
import 'shell/first_run_tour.dart' show tourRequests;
import 'widgets/glass_panel.dart';

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

class _Section {
  const _Section(this.title, this.items);
  final String title;
  final List<_Faq> items;
}

const _sections = [
  _Section('Getting started', [
    _Faq(
        'How do I log a film or show?',
        'Tap the plus in the tab bar, search for the title, then give it a '
            'rating. A review, photos and a short voice note are optional. '
            'For a show you can log single episodes from its page.'),
    _Faq(
        'What\'s the difference between Home and Explore?',
        'Home is the people you follow: their reviews and posts, one at a '
            'time. Explore is everyone on 35mm: hot takes, lists and posts you '
            'can agree or disagree with and reply to.'),
    _Faq(
        'How do I find friends?',
        'On Home, tap the people button in the top left, then Find people '
            'and search by username. Tap Follow on anyone you know.'),
    _Faq(
        'What are Trailers?',
        'A feed of new and trending trailers. Swipe up for the next one, '
            'tap Sound for audio, and the sideways-phone button to watch it '
            'full screen. Bookmark one to add it to your watchlist.'),
  ]),
  _Section('Lists', [
    _Faq(
        'What\'s the watchlist?',
        'Things you want to watch. Tap the bookmark on any film or show. '
            'When you log it, it comes off the list by itself.'),
    _Faq(
        'How do playlists work?',
        'Make one from any film\'s Add to… button, or from the Lists tab on '
            'your profile. Choose who can see it: everyone, your followers, '
            'or only you. Once it has films in it you can post it to '
            'Explore.'),
    _Faq('Where are playlists I\'ve saved?',
        'At the bottom of the Lists tab on your profile, under Saved.'),
  ]),
  _Section('Privacy and following', [
    _Faq(
        'Who can see what I post?',
        'If your account is public, anyone on 35mm can see your profile, '
            'reviews and Explore posts. If it\'s private, only people you '
            'approve see more than your name and photo, and that includes '
            'your Explore posts.'),
    _Faq(
        'How do I make my account private?',
        'Profile, then the gear, then Private account. People who already '
            'follow you keep following; new people have to ask.'),
    _Faq(
        'What does "Friends" on the Follow button mean?',
        'You follow each other. "Following" means you follow them but they '
            'don\'t follow you back.'),
    _Faq(
        'How do I remove a follower?',
        'Open People from Home, choose Followers, and tap Remove. They '
            'aren\'t told.'),
  ]),
  _Section('Safety', [
    _Faq(
        'How do I report something?',
        'Tap the ••• on any review, comment, post, reply or playlist, or on '
            'someone\'s profile, and choose Report. It disappears for you '
            'straight away, and we review every report within 24 hours.'),
    _Faq(
        'How do I block someone?',
        'Tap the ••• on their profile or on anything they posted and choose '
            'Block. You stop seeing each other everywhere, and any follows '
            'between you end. Unblock them from Settings, Blocked accounts.'),
    _Faq(
        'Why couldn\'t I post something?',
        '35mm refuses slurs, sexual content, graphic violence and anything '
            'telling someone to hurt themselves, in text and in photos. '
            'Swearing is fine. If you think we got it wrong, contact us.'),
  ]),
  _Section('Your account', [
    _Faq('How do I change my username or photo?',
        'Profile, then the gear, then Edit profile.'),
    _Faq('I forgot my password.',
        'On the login screen, tap Forgot password. We\'ll email you a code.'),
    _Faq(
        'How do I delete my account?',
        'Profile, then the gear, then Delete account. Everything you\'ve '
            'posted is removed for good, and it can\'t be undone.'),
  ]),
];

/// Settings → Help: short answers to the common questions, the tour again,
/// and how to reach us.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpace.xs, AppSpace.xs, AppSpace.lg, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(CupertinoIcons.chevron_back,
                        color: AppColors.ink),
                    tooltip: 'Back',
                  ),
                  const Expanded(child: Text('Help', style: AppText.title)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md,
                    AppSpace.lg, MediaQuery.paddingOf(context).bottom + 40),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GlassPillButton(
                          label: 'Replay the tour',
                          icon: CupertinoIcons.play_circle,
                          expand: true,
                          onTap: () {
                            context.go('/home');
                            tourRequests.value++;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Expanded(
                        child: GlassPillButton(
                          label: 'Contact us',
                          icon: CupertinoIcons.envelope,
                          expand: true,
                          onTap: () => launchUrl(Uri.parse(kSupportUrl),
                              mode: LaunchMode.inAppBrowserView),
                        ),
                      ),
                    ],
                  ),
                  for (final section in _sections) ...[
                    const SizedBox(height: AppSpace.xl),
                    GlassSectionLabel(section.title),
                    const SizedBox(height: AppSpace.sm),
                    Container(
                      decoration: glassWellDecoration(),
                      child: Column(
                        children: [
                          for (var i = 0; i < section.items.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  indent: AppSpace.lg,
                                  color: AppColors.separator),
                            _FaqTile(faq: section.items[i]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.faq});

  final _Faq faq;

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return GlassPressable(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg, vertical: AppSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.faq.question,
                      style: AppText.body.copyWith(
                          color: AppColors.ink, fontWeight: FontWeight.w600)),
                ),
                AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 160),
                  child: const Icon(CupertinoIcons.chevron_right,
                      size: 14, color: AppColors.inkTertiary),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(top: AppSpace.sm),
                      child: Text(widget.faq.answer,
                          style: AppText.body
                              .copyWith(color: AppColors.inkSecondary)),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}
