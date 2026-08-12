import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/theme/app_theme.dart';
import 'waveform.dart';

/// Longest spoken review we'll take.
///
/// Short enough that listening to one is never a commitment, which is the
/// whole point — a feed of ten-second takes gets played, a feed of two-minute
/// ones gets scrolled past.
const Duration kMaxVoiceNote = Duration(seconds: 10);

/// How often the recorder is asked for its level. Ten samples a second is a
/// hundred across the cap, which is more shape than any bar count will use.
const Duration _kSamplePeriod = Duration(milliseconds: 100);

/// Quietest level that still draws a bar, in dBFS.
///
/// The recorder reports roughly -60 for a silent room and 0 for clipping, but
/// speech at arm's length sits around -25. Mapping the full range would leave
/// an ordinary voice as a flat line near the bottom, so the floor is set close
/// to the noise floor and everything below it flattens out.
const double _kSilenceFloorDb = -45;

/// Most photos one review can carry — matches the database constraint and is
/// as many as the stack on the card back can show before the ones underneath
/// stop being visible.
const int kMaxReviewPhotos = 4;

/// What the composer hands back.
@immutable
class ReviewMediaDraft {
  const ReviewMediaDraft({
    this.voiceNote,
    this.voiceNoteDurationMs = 0,
    this.waveform = const [],
    this.photos = const [],
  });

  final File? voiceNote;
  final int voiceNoteDurationMs;
  final List<double> waveform;
  final List<File> photos;

  bool get isEmpty => voiceNote == null && photos.isEmpty;
}

/// Record a spoken review and take photos to go with it.
class ReviewMediaComposer extends StatefulWidget {
  const ReviewMediaComposer({super.key, required this.onChanged});

  final ValueChanged<ReviewMediaDraft> onChanged;

  @override
  State<ReviewMediaComposer> createState() => _ReviewMediaComposerState();
}

class _ReviewMediaComposerState extends State<ReviewMediaComposer> {
  final _recorder = AudioRecorder();
  final _picker = ImagePicker();

  bool _recording = false;
  bool _busy = false;
  String? _error;

  /// Levels for the take in progress. Kept separate from [_waveform] so
  /// abandoning a recording can't half-overwrite the one already captured.
  final List<double> _live = [];
  StreamSubscription<Amplitude>? _levels;
  Timer? _cap;
  DateTime? _startedAt;

  File? _voiceNote;
  int _durationMs = 0;
  List<double> _waveform = const [];
  final List<File> _photos = [];

  @override
  void dispose() {
    _levels?.cancel();
    _cap?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _publish() {
    widget.onChanged(ReviewMediaDraft(
      voiceNote: _voiceNote,
      voiceNoteDurationMs: _durationMs,
      waveform: _waveform,
      photos: List.unmodifiable(_photos),
    ));
  }

  // ── Recording ─────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (!await _recorder.hasPermission()) {
        setState(() {
          _busy = false;
          _error = 'Microphone access is off. Turn it on in Settings.';
        });
        return;
      }

      // Into the temp directory: this file only has to survive until it's
      // uploaded, and anything the OS reclaims afterwards is a file we would
      // have had to delete ourselves.
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          // AAC in an m4a container: plays natively on both platforms without
          // a decoder, and ten seconds lands around 20KB.
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      _live.clear();
      _startedAt = DateTime.now();

      _levels =
          _recorder.onAmplitudeChanged(_kSamplePeriod).listen((amplitude) {
        if (!mounted) return;
        setState(() => _live.add(_normalise(amplitude.current)));
      });

      // A hard stop at the cap, rather than trusting the user to stop in time.
      _cap = Timer(kMaxVoiceNote, () {
        if (mounted && _recording) _stopRecording();
      });

      setState(() {
        _recording = true;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _recording = false;
        _error = 'Could not start recording.';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;

    _cap?.cancel();
    await _levels?.cancel();
    _levels = null;

    final elapsed = _startedAt == null
        ? Duration.zero
        : DateTime.now().difference(_startedAt!);

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      path = null;
    }

    if (!mounted) return;

    // Under a second is a misfire — a tap that started and stopped the
    // recorder — and keeping it would put an empty bar on the card forever.
    if (path == null || elapsed.inMilliseconds < 700) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      setState(() {
        _recording = false;
        _live.clear();
      });
      return;
    }

    setState(() {
      _recording = false;
      _voiceNote = File(path!);
      // Clamped because the encoder can overrun the cap by a few frames, and
      // the row has a check constraint on this.
      _durationMs = math.min(
        elapsed.inMilliseconds,
        kMaxVoiceNote.inMilliseconds,
      );
      _waveform = List<double>.unmodifiable(_live);
      _live.clear();
    });
    _publish();
  }

  Future<void> _discardRecording() async {
    final file = _voiceNote;
    setState(() {
      _voiceNote = null;
      _durationMs = 0;
      _waveform = const [];
    });
    _publish();
    if (file != null) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  /// dBFS to 0..1.
  double _normalise(double db) {
    if (!db.isFinite) return 0;
    return ((db - _kSilenceFloorDb) / -_kSilenceFloorDb).clamp(0.0, 1.0);
  }

  // ── Photos ────────────────────────────────────────────────

  Future<void> _takePhoto() async {
    if (_photos.length >= kMaxReviewPhotos) return;

    try {
      final shot = await _picker.pickImage(
        // Camera only, never the library. A review photo is meant to be of the
        // room you watched it in — a picker would turn it into a place to
        // paste a still off the internet, which is what the poster already is.
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (shot == null || !mounted) return;
      setState(() => _photos.add(File(shot.path)));
      _publish();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the camera.');
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
    _publish();
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'VOICE & PHOTOS',
              style: AppText.footnote.copyWith(
                color: AppColors.inkTertiary,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (_photos.isNotEmpty)
              Text(
                '${_photos.length}/$kMaxReviewPhotos',
                style: AppText.footnote.copyWith(color: AppColors.inkTertiary),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.md),

        if (_recording)
          _RecordingStrip(
            samples: _live,
            startedAt: _startedAt ?? DateTime.now(),
            onStop: _stopRecording,
          )
        else if (_voiceNote != null)
          _RecordedStrip(
            samples: _waveform,
            durationMs: _durationMs,
            onDiscard: _discardRecording,
          )
        else
          _IdleActions(
            onRecord: _startRecording,
            onPhoto: _photos.length < kMaxReviewPhotos ? _takePhoto : null,
            busy: _busy,
          ),

        // Once a recording exists the idle row is gone, so the camera needs its
        // own way back.
        if (!_recording && _voiceNote != null) ...[
          const SizedBox(height: AppSpace.sm),
          _CameraButton(
            onTap: _photos.length < kMaxReviewPhotos ? _takePhoto : null,
            expanded: true,
          ),
        ],

        if (_photos.isNotEmpty) ...[
          const SizedBox(height: AppSpace.md),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
              itemBuilder: (_, i) => _PhotoThumb(
                file: _photos[i],
                onRemove: () => _removePhoto(i),
              ),
            ),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(
            _error!,
            style: AppText.footnote.copyWith(color: AppColors.destructive),
          ),
        ],
      ],
    );
  }
}

class _IdleActions extends StatelessWidget {
  const _IdleActions({
    required this.onRecord,
    required this.onPhoto,
    required this.busy,
  });

  final VoidCallback onRecord;
  final VoidCallback? onPhoto;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Action(
            icon: CupertinoIcons.mic_fill,
            label: busy ? 'Starting…' : 'Record 10s',
            onTap: busy ? null : onRecord,
          ),
        ),
        const SizedBox(width: AppSpace.sm),
        Expanded(child: _CameraButton(onTap: onPhoto)),
      ],
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap, this.expanded = false});

  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = _Action(
      icon: CupertinoIcons.camera_fill,
      label: onTap == null ? 'Photo limit reached' : 'Take a photo',
      onTap: onTap,
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final colour = enabled ? AppColors.ink : AppColors.inkTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.separator, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: colour),
            const SizedBox(width: AppSpace.sm),
            Flexible(
              child: Text(
                label,
                style: AppText.label.copyWith(color: colour),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The live take: bars arriving as you speak, and a bar draining toward the
/// cap so the ten seconds are visible rather than a surprise.
class _RecordingStrip extends StatefulWidget {
  const _RecordingStrip({
    required this.samples,
    required this.startedAt,
    required this.onStop,
  });

  final List<double> samples;

  /// When recording began, rather than how long it's been going.
  ///
  /// An elapsed Duration would be frozen at whatever the parent last built,
  /// and the parent only rebuilds ten times a second when a level arrives —
  /// the countdown has to derive its own now() on every tick to move smoothly.
  final DateTime startedAt;

  final VoidCallback onStop;

  @override
  State<_RecordingStrip> createState() => _RecordingStripState();
}

class _RecordingStripState extends State<_RecordingStrip>
    with SingleTickerProviderStateMixin {
  // Ticks the countdown independently of the level stream, which only fires
  // ten times a second and would make the timer visibly stutter.
  late final Ticker _ticker = Ticker((_) => setState(() {}))..start();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final remaining = kMaxVoiceNote - elapsed;
    final left = remaining.isNegative ? Duration.zero : remaining;
    final progress =
        (elapsed.inMilliseconds / kMaxVoiceNote.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.destructive.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.circle_fill,
                size: 10,
                color: AppColors.destructive,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: Waveform(
                    samples:
                        widget.samples.isEmpty ? const [0] : widget.samples,
                    color: AppColors.destructive,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                '0:${left.inSeconds.toString().padLeft(2, '0')}',
                style: AppText.caption.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              GestureDetector(
                onTap: widget.onStop,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: AppColors.destructive,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.stop_fill,
                    size: 13,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: AppColors.destructive.withValues(alpha: 0.25),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.destructive),
            ),
          ),
        ],
      ),
    );
  }
}

/// A take that's been kept: its shape, its length, and a way to bin it.
class _RecordedStrip extends StatelessWidget {
  const _RecordedStrip({
    required this.samples,
    required this.durationMs,
    required this.onDiscard,
  });

  final List<double> samples;
  final int durationMs;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final seconds = (durationMs / 1000).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.waveform,
            size: 17,
            color: AppColors.inkSecondary,
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: SizedBox(
              height: 34,
              child: Waveform(samples: samples, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Text(
            '0:${seconds.toString().padLeft(2, '0')}',
            style: AppText.caption.copyWith(
              color: AppColors.inkSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          GestureDetector(
            onTap: onDiscard,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(AppSpace.sm),
              child: Icon(
                CupertinoIcons.trash,
                size: 16,
                color: AppColors.inkSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.file, required this.onRemove});

  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.separator, width: 0.5),
              ),
              child: const Icon(
                CupertinoIcons.xmark,
                size: 11,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
