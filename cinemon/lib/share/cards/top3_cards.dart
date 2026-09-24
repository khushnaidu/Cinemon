import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/film_model.dart';
import '../share_subject.dart';
import '../story_canvas.dart';

/// T1: the Top 3 from your profile, lifted out as it is. The TOP 3 orb, a
/// large poster for number one, and the outlined 1, 2 and 3 badges half on
/// and half off each poster (`top3_films_section.dart`).
class PodiumTop3Card extends StatelessWidget {
  const PodiumTop3Card({super.key, required this.top3});

  final Top3Share top3;

  @override
  Widget build(BuildContext context) {
    final films = top3.films;
    FilmModel? at(int i) => i < films.length ? films[i] : null;

    Widget poster(FilmModel f, double w, double h) => SizedBox(
          width: w,
          height: h,
          child: StoryPoster(url: top3.posterOf(f), width: w, radius: 3.u),
        );
    Widget badge(int rank, double size) => Image.asset(
          'assets/share/top3_rank$rank.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );

    return StoryCanvas(
      children: [
        Opacity(
          opacity: 0.55,
          child: Image.asset(
            'assets/share/sparkle.png',
            repeat: ImageRepeat.repeatY,
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
          ),
        ),
        const StoryGrain(),
        Positioned(
          left: 7.u,
          top: 21.u,
          child: StoryAuthor(
            username: top3.username,
            photoUrl: top3.userPhotoUrl,
            caption: top3.isTv ? 'top 3 shows' : 'top 3 films',
          ),
        ),
        Positioned(
          left: 2.u,
          right: 2.u,
          top: 30.u,
          child: Image.asset('assets/share/top3_orb.png', fit: BoxFit.contain),
        ),
        // The shelf. Second and third first, so number one sits on top.
        if (at(1) != null)
          Positioned(
            left: 0,
            top: 68.u,
            width: 39.5.u,
            height: 46.u,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(left: 8.5.u, child: poster(at(1)!, 31.u, 46.u)),
                Positioned(left: 0, top: 18.4.u, child: badge(2, 17.u)),
              ],
            ),
          ),
        if (at(2) != null)
          Positioned(
            right: 0,
            top: 68.u,
            width: 39.5.u,
            height: 46.u,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(right: 8.5.u, child: poster(at(2)!, 31.u, 46.u)),
                Positioned(right: 0, top: 18.4.u, child: badge(3, 17.u)),
              ],
            ),
          ),
        if (at(0) != null)
          Positioned(
            left: 31.u,
            top: 74.u,
            width: 38.u,
            height: 68.u,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                poster(at(0)!, 38.u, 57.u),
                Positioned(
                  left: 9.u,
                  bottom: 0,
                  child: badge(1, 20.u),
                ),
              ],
            ),
          ),
        Positioned(
          left: 7.u,
          right: 7.u,
          top: 145.u,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < films.length; i++) ...[
                if (i > 0) SizedBox(width: 2.u),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${i + 1}  ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: films[i].displayTitle,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75)),
                      ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: kHelvetica,
                      fontSize: 3.u,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 17.u,
          child: const Center(child: StoryBrand()),
        ),
      ],
    );
  }
}

/// T2: a photographer's contact sheet. A strip for each film, number one
/// circled in red grease pencil, the ranks written by hand.
class ContactSheetTop3Card extends StatelessWidget {
  const ContactSheetTop3Card({super.key, required this.top3});

  final Top3Share top3;

  static const _paper = Color(0xFFEBE7DF);
  static const _pencil = Color(0xFFD0261B);

  TextStyle _hand(double size) => TextStyle(
        fontFamily: 'ReenieBeanie',
        fontSize: size,
        height: 0.9,
        color: _pencil,
      );

  @override
  Widget build(BuildContext context) {
    final films = top3.films.take(3).toList();
    const bandPitch = 38.8; // band height plus gap, in units
    const sheetTop = 32.0;

    return StoryCanvas(
      background: _paper,
      children: [
        // Paper tooth: the grain, darkened.
        Opacity(
          opacity: 0.35,
          child: ColorFiltered(
            colorFilter:
                const ColorFilter.mode(Color(0xFF6B6458), BlendMode.srcIn),
            child: Image.asset(
              'assets/share/grain.png',
              repeat: ImageRepeat.repeat,
              scale: 1.4,
              fit: BoxFit.none,
              alignment: Alignment.topLeft,
            ),
          ),
        ),
        Positioned(
          left: 8.u,
          right: 8.u,
          top: 19.u,
          child: Transform.rotate(
            angle: -3 * math.pi / 180,
            alignment: Alignment.centerLeft,
            child: Text(
              top3.isTv ? 'my top 3 shows, ever.' : 'my top 3, ever.',
              style: _hand(10.u),
            ),
          ),
        ),
        Positioned(
          left: 5.u,
          right: 5.u,
          top: sheetTop.u,
          child: Column(
            children: [
              for (var i = 0; i < films.length; i++) ...[
                if (i > 0) SizedBox(height: 3.u),
                _Band(
                  url: top3.backdropOf(films[i]).isNotEmpty
                      ? top3.backdropOf(films[i])
                      : top3.posterOf(films[i]),
                  frame: 12 + i,
                  paper: _paper,
                ),
              ],
            ],
          ),
        ),
        // Grease pencil: the circle round number one, then the ranks.
        if (films.isNotEmpty)
          Positioned(
            left: 5.u,
            top: (sheetTop + 1).u,
            width: 58.u,
            height: 34.u,
            child: Transform.rotate(
              angle: -4 * math.pi / 180,
              child: const CustomPaint(painter: _Circle(color: _pencil)),
            ),
          ),
        for (var i = 0; i < films.length; i++)
          Positioned(
            right: 9.u,
            top: (sheetTop + 5 + i * bandPitch).u,
            child: Text('${i + 1}', style: _hand(16.u)),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 17.u,
          child: Center(
            child: StoryBrand(
              dark: true,
              label: '@${top3.username} on 35mm',
            ),
          ),
        ),
      ],
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.url, required this.frame, required this.paper});

  final String url;
  final int frame;
  final Color paper;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      padding: EdgeInsets.symmetric(horizontal: 3.u, vertical: 4.4.u),
      child: CustomPaint(
        painter: _Perforations(paper: paper, frame: frame),
        child: Row(
          children: [
            SizedBox(
              width: 48.u,
              height: 27.u,
              child: StoryImage(url),
            ),
            SizedBox(width: 2.u),
            Expanded(
              child: SizedBox(
                height: 27.u,
                child: Opacity(
                  opacity: 0.35,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.5, 0.4, 0.1, 0, 0, //
                      0.3, 0.6, 0.1, 0, 0, //
                      0.3, 0.4, 0.3, 0, 0, //
                      0, 0, 0, 1, 0,
                    ]),
                    child: Transform.flip(flipX: true, child: StoryImage(url)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sprocket holes along the top and bottom of a strip, and its edge code.
class _Perforations extends CustomPainter {
  _Perforations({required this.paper, required this.frame});

  final Color paper;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = Paint()..color = paper;
    final w = 1.8.u;
    final h = 1.6.u;
    for (final y in [-3.1.u, size.height + 1.5.u]) {
      for (var x = -1.4.u; x < size.width + 1.4.u; x += 3.4.u) {
        canvas.drawRect(Rect.fromLTWH(x, y, w, h), hole);
      }
    }
    final code = TextPainter(
      text: TextSpan(
        text: '▸ $frame        KODAK 5219        ▸ ${frame}A',
        style: TextStyle(
          fontFamily: 'IBMPlexMono',
          fontWeight: FontWeight.w600,
          fontSize: 1.8.u,
          letterSpacing: 0.36.u,
          color: const Color(0xFFFF9B3D),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    code.paint(canvas, Offset(3.u, -1.4.u - code.height / 2));
  }

  @override
  bool shouldRepaint(_Perforations old) =>
      old.frame != frame || old.paper != paper;
}

/// A hand-drawn loop: an ellipse drawn twice, slightly off, like one pass of
/// a grease pencil going round and overlapping itself.
class _Circle extends CustomPainter {
  const _Circle({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8.u
      ..strokeCap = StrokeCap.round;
    final r = Offset.zero & size;
    canvas.drawArc(r, -0.2, 2 * math.pi - 0.1, false, paint);
    canvas.drawArc(r.inflate(0.6.u).shift(Offset(0.8.u, -0.4.u)), -0.5, 0.9,
        false, paint..strokeWidth = 0.6.u);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
