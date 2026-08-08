import 'dart:math' show pi;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Custom clipper for arch/cathedral window shape with semicircular top
class ArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final radius = size.width / 2;

    // Start from bottom left
    path.moveTo(0, size.height);

    // Left side up to where the arch begins
    path.lineTo(0, radius);

    // Semicircular arch at top - arcTo connects to current path
    path.arcTo(
      Rect.fromLTWH(0, 0, size.width, size.width),
      pi, // Start from left (180 degrees)
      pi, // Sweep 180 degrees to right
      false, // Don't force moveTo - connect to path
    );

    // Right side down
    path.lineTo(size.width, size.height);

    // Close path
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Custom painter for glow effect behind the frame
class GlowPainter extends CustomPainter {
  final Color glowColor;
  final double blurRadius;

  GlowPainter({
    this.glowColor = const Color(0xFFFFD54F),
    this.blurRadius = 40,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = glowColor.withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

    // Draw the glow shape (same semicircular arch)
    final radius = size.width / 2;
    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, radius);
    path.arcTo(
      Rect.fromLTWH(0, 0, size.width, size.width),
      pi,
      pi,
      false,
    );
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Arch-shaped profile frame with glow effect and username overlay
class ArchProfileFrame extends StatelessWidget {
  final String? photoUrl;
  final String username;
  final double width;
  final double height;
  final Color glowColor;
  final bool showUsername;

  const ArchProfileFrame({
    super.key,
    required this.photoUrl,
    required this.username,
    this.width = 200,
    this.height = 260,
    this.glowColor = const Color(0xFFFFD54F),
    this.showUsername = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height + (showUsername ? 60 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Glow effect behind
          Positioned(
            top: 0,
            child: CustomPaint(
              size: Size(width + 20, height + 10),
              painter: GlowPainter(
                glowColor: glowColor,
                blurRadius: 35,
              ),
            ),
          ),

          // Profile image with arch clip
          Positioned(
            top: 0,
            child: ClipPath(
              clipper: ArchClipper(),
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                ),
                child: photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white54),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.white54,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.white54,
                      ),
              ),
            ),
          ),

          // Username overlay - positioned to spill onto photo
          if (showUsername)
            Positioned(
              bottom: -20,
              child: WavyUsername(username: username),
            ),
        ],
      ),
    );
  }
}

/// Stylized username text with Siberian font
class WavyUsername extends StatelessWidget {
  final String username;
  final double fontSize;
  final Color color;

  const WavyUsername({
    super.key,
    required this.username,
    this.fontSize = 72,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      username,
      style: TextStyle(
        fontFamily: 'Siberian',
        fontSize: fontSize,
        color: color,
      ),
    );
  }
}
