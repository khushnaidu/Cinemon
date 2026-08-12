import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A recording drawn as bars.
///
/// The samples are peak amplitudes captured while recording, 0..1, and there
/// are however many of them the recorder produced — usually far more than
/// there are bars to draw. Resampling happens at paint time against the width
/// actually available, which is what lets the same recording render as 40 bars
/// on a feed card and 100 in the composer without storing it twice.
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.samples,
    required this.color,
    this.playedColor,
    this.progress = 0,
    this.barWidth = 2.5,
    this.gap = 2,
  });

  /// Peak amplitude per slice, 0..1.
  final List<double> samples;

  /// Bars not yet played.
  final Color color;

  /// Bars already played. Falls back to [color] — pass a brighter one and the
  /// waveform doubles as the progress bar, which is the only reason a voice
  /// note doesn't also need a scrubber next to it.
  final Color? playedColor;

  /// 0..1 through the recording.
  final double progress;

  final double barWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _WaveformPainter(
        samples: samples,
        color: color,
        playedColor: playedColor ?? color,
        progress: progress,
        barWidth: barWidth,
        gap: gap,
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.samples,
    required this.color,
    required this.playedColor,
    required this.progress,
    required this.barWidth,
    required this.gap,
  });

  final List<double> samples;
  final Color color;
  final Color playedColor;
  final double progress;
  final double barWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0) return;

    final slot = barWidth + gap;
    final bars = math.max(1, (size.width + gap) ~/ slot);
    final centre = size.height / 2;

    // A bar is never shorter than its own width, so silence reads as a dotted
    // line rather than disappearing — a waveform with gaps in it looks broken,
    // where a flat run of dots obviously means nobody was talking.
    final minHeight = barWidth;
    final maxHeight = size.height;

    for (var i = 0; i < bars; i++) {
      final value = _sampleAt(i, bars);
      final height = (minHeight + value * (maxHeight - minHeight))
          .clamp(minHeight, maxHeight);
      final x = i * slot;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centre - height / 2, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        Paint()..color = (i + 0.5) / bars <= progress ? playedColor : color,
      );
    }
  }

  /// The peak across the slice of the recording this bar stands for.
  ///
  /// Peak rather than mean: averaging a window of amplitudes flattens exactly
  /// the transients that give a waveform its shape, and a voice note averaged
  /// down to a smooth lozenge tells you nothing about what's in it.
  double _sampleAt(int bar, int bars) {
    final start = (bar * samples.length / bars).floor();
    final end =
        math.max(start + 1, ((bar + 1) * samples.length / bars).floor());

    var peak = 0.0;
    for (var i = start; i < end && i < samples.length; i++) {
      if (samples[i] > peak) peak = samples[i];
    }
    return peak.clamp(0.0, 1.0);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.playedColor != playedColor ||
      !identical(old.samples, samples) ||
      old.samples.length != samples.length;
}
