import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/theme/app_theme.dart';
import 'waveform.dart';

/// Whoever is currently playing.
///
/// The feed can have any number of these on screen at once, and two spoken
/// reviews talking over each other is never what anyone meant to do. Starting
/// one stops the last, without every player having to know about every other.
final ValueNotifier<Object?> _nowPlaying = ValueNotifier<Object?>(null);

/// A spoken review: its waveform, with playback running through it.
///
/// The waveform doubles as the progress bar — bars already played are lit —
/// which is why there's no scrubber. At ten seconds a scrubber would be a
/// control for moving between two points three centimetres apart.
class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.url,
    required this.durationMs,
    required this.waveform,
    required this.tint,
  });

  final String url;
  final int durationMs;
  final List<double> waveform;

  /// The film's colour, so a playing note lights up in it.
  final Color tint;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  /// Created on first play, not on build.
  ///
  /// A feed card is built long before anyone decides to listen to it, and an
  /// AudioPlayer per card means an audio session and a platform player for
  /// every post scrolled past.
  AudioPlayer? _player;

  StreamSubscription<Duration>? _positions;
  StreamSubscription<PlayerState>? _states;

  bool _playing = false;
  bool _loading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _nowPlaying.addListener(_yieldToOthers);
  }

  @override
  void dispose() {
    _nowPlaying.removeListener(_yieldToOthers);
    if (_nowPlaying.value == this) _nowPlaying.value = null;
    _positions?.cancel();
    _states?.cancel();
    _player?.dispose();
    super.dispose();
  }

  void _yieldToOthers() {
    if (_nowPlaying.value != this && _playing) {
      _player?.pause();
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player?.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }

    _nowPlaying.value = this;

    if (_player == null) {
      setState(() => _loading = true);
      final player = AudioPlayer();
      try {
        await player.setUrl(widget.url);
      } catch (_) {
        player.dispose();
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (!mounted) {
        player.dispose();
        return;
      }

      _player = player;
      final total = player.duration?.inMilliseconds ?? widget.durationMs;

      _positions = player.positionStream.listen((position) {
        if (!mounted || total <= 0) return;
        setState(() {
          _progress = (position.inMilliseconds / total).clamp(0.0, 1.0);
        });
      });

      _states = player.playerStateStream.listen((state) {
        if (!mounted) return;
        if (state.processingState == ProcessingState.completed) {
          // Back to the start rather than leaving it parked at the end, so the
          // next tap plays instead of doing nothing.
          player.pause();
          player.seek(Duration.zero);
          setState(() {
            _playing = false;
            _progress = 0;
          });
        }
      });

      setState(() => _loading = false);
    }

    await _player!.play();
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (widget.durationMs / 1000).ceil();

    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: widget.tint.withValues(alpha: _playing ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: widget.tint.withValues(alpha: _playing ? 0.5 : 0.25),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(widget.tint),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.tint.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _playing
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        size: 13,
                        color: AppColors.canvas,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: SizedBox(
                height: 26,
                child: Waveform(
                  samples: widget.waveform.isEmpty
                      // A row of stubs still says "this is audio" — better than
                      // an empty pill for a note recorded before waveforms were
                      // stored, or one whose levels didn't come through.
                      ? const [0.35, 0.6, 0.4, 0.75, 0.5, 0.3, 0.65, 0.45]
                      : widget.waveform,
                  color: widget.tint.withValues(alpha: 0.35),
                  playedColor: widget.tint,
                  progress: _progress,
                  barWidth: 2,
                  gap: 2,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              '0:${seconds.toString().padLeft(2, '0')}',
              style: AppText.footnote.copyWith(
                color: AppColors.inkSecondary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AppSpace.xs),
          ],
        ),
      ),
    );
  }
}
