import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/user/verified_provider.dart';

/// The seal beside a verified account's username. Nothing for anyone else,
/// so it can sit after every username without a check at each call site.
class VerifiedMark extends ConsumerWidget {
  const VerifiedMark({
    super.key,
    required this.userId,
    this.size = 14,
    this.gap = 4,
  });

  final String? userId;

  /// About the cap height of the username beside it.
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = ref.watch(verifiedUsersProvider).valueOrNull;
    if (userId == null || verified == null || !verified.contains(userId)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(left: gap),
      child: Semantics(
        label: 'Verified',
        child: Icon(
          CupertinoIcons.checkmark_seal_fill,
          size: size,
          color: Colors.white,
        ),
      ),
    );
  }
}
