/// The app's design tokens and the single [ThemeData] built from them.
///
/// Before this existed, `main.dart` declared `ThemeData(brightness: dark)` and
/// nothing else, so every screen picked its own colours — five different dark
/// backgrounds were in use — and Flutter fell back to Material's Roboto, which
/// is why the app read as Android rather than iOS.
///
/// The target is a native-feeling iOS app: San Francisco throughout, Apple's
/// own label and separator opacities, generously rounded corners, no ink
/// ripples, and right-to-left page pushes. The palette is monochrome so the
/// only colour on screen comes from poster artwork.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flat palette. Deliberately small — if a colour isn't here it shouldn't be
/// in the app.
abstract final class AppColors {
  // Neutral greys, not tinted ones. The old palette ran everything through a
  // navy/purple cast, which reads as cheap next to poster artwork — the tint
  // fights whatever colour is in the still. These are Apple's own dark-mode
  // background and grey ramp, so surfaces sit at exactly the weight they do
  // in the system UI and the accent is the only colour on screen.

  /// Page background. True black, as iOS uses in dark mode — posters and
  /// stills sit on it without a halo, and it's free on OLED.
  static const canvas = Color(0xFF000000);

  /// Cards, sheets, inputs. systemGray6 (dark).
  static const surface = Color(0xFF1C1C1E);

  /// Menus and anything stacked on a surface. systemGray5 (dark).
  static const surfaceElevated = Color(0xFF2C2C2E);

  /// Pressed state fill. systemGray4 (dark).
  static const surfacePressed = Color(0xFF3A3A3C);

  /// Primary text and icons.
  static const ink = Color(0xFFFFFFFF);

  /// Apple's own dark-mode label opacities, rather than invented greys.
  /// Using the real values is what makes secondary text sit at the same
  /// visual weight it does in Settings or Messages.
  static const inkSecondary = Color(0x99EBEBF5); // secondaryLabel, 60%
  static const inkTertiary = Color(0x4DEBEBF5); // tertiaryLabel, 30%
  static const inkQuaternary = Color(0x2EEBEBF5); // quaternaryLabel, 18%

  /// iOS separator. Hairlines this faint are a large part of why the system
  /// UI looks calm.
  static const separator = Color(0x99545458);

  /// The accent.
  ///
  /// Monochrome: white, not a hue. With poster artwork as the content, any
  /// chromatic tint competes with whatever colour is in the still — which is
  /// how the old lavender ended up looking cheap once the surfaces behind it
  /// went neutral. Apple TV and Music take the same approach on dark.
  ///
  /// Swapping in a tint is a one-line change here; systemIndigo (0xFF5E5CE6)
  /// or systemBlue (0xFF0A84FF) both work if colour is wanted back.
  static const accent = Color(0xFFFFFFFF);

  /// Category/semantic blue, for the places that need a colour distinct from
  /// gold and green (badge groups) rather than an accent.
  static const info = Color(0xFF0A84FF);

  /// systemRed (dark). Destructive actions, likes, unread badges.
  static const destructive = Color(0xFFFF453A);

  /// systemYellow (dark). Star ratings only.
  static const gold = Color(0xFFFFD60A);

  /// systemGreen (dark). Success states.
  static const success = Color(0xFF30D158);
}

/// Spacing scale. Multiples of 4, named so layouts stop inventing numbers.
abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Corner radii. iOS leans rounder than Material almost everywhere.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const sheet = 12.0;
  static const pill = 999.0;
}

/// Type scale, following iOS's own sizes and weights.
///
/// Apple ships two optical sizes of San Francisco and switches at 20pt:
/// `.SF Pro Display` above it, `.SF Pro Text` below. Using the wrong one is
/// subtle but it's a real part of why type can look "off" on iOS — Display
/// has tighter spacing and smaller apertures suited to headlines.
abstract final class AppText {
  static const _display = '.SF Pro Display';
  static const _text = '.SF Pro Text';

  /// Non-Apple platforms fall back gracefully rather than rendering blank.
  static const _fallback = <String>['.SF UI Display', 'Helvetica Neue', 'Roboto'];

  /// Navigation bar large titles.
  static const largeTitle = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _fallback,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.37,
    height: 1.2,
  );

  /// Screen and sheet titles.
  static const title = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _fallback,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.26,
    height: 1.2,
  );

  /// Navigation bar titles, section headers.
  static const headline = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.41,
    height: 1.3,
  );

  /// Reviews, comments — the default reading size on iOS is 17, but this is
  /// dense social content so it sits one step down.
  static const body = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.24,
    height: 1.4,
  );

  /// Buttons and field labels.
  static const label = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
    height: 1.3,
  );

  /// Timestamps, counts, captions.
  static const caption = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.08,
    height: 1.3,
  );

  /// Tab bar labels and the smallest metadata.
  static const footnote = TextStyle(
    fontFamily: _text,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.06,
    height: 1.2,
  );
}

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      surface: AppColors.canvas,
      onSurface: AppColors.ink,
      surfaceContainer: AppColors.surface,
      primary: AppColors.accent,
      onPrimary: AppColors.canvas,
      secondary: AppColors.accent,
      onSecondary: AppColors.canvas,
      error: AppColors.destructive,
      onError: AppColors.ink,
      outline: AppColors.separator,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: AppText._text,
      fontFamilyFallback: AppText._fallback,

      // The Material ink ripple is the single most Android-feeling default in
      // Flutter. iOS fades opacity on press instead of expanding a circle.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: AppColors.surfacePressed,

      // Right-to-left push with the edge-swipe back gesture, rather than
      // Material's bottom-up fade.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      textTheme: const TextTheme(
        displayLarge: AppText.largeTitle,
        titleLarge: AppText.title,
        titleMedium: AppText.headline,
        bodyMedium: AppText.body,
        bodySmall: AppText.caption,
        labelLarge: AppText.label,
        labelSmall: AppText.footnote,
      ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),

      // iOS nav bars: centred title, no shadow, translucent-dark background.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.headline,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.canvas,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.inkTertiary,
        selectedLabelStyle: AppText.footnote,
        unselectedLabelStyle: AppText.footnote,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.separator,
        thickness: 0.5, // iOS hairlines are sub-pixel
        space: 0.5,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.inkTertiary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: AppText.headline,
        contentTextStyle: AppText.body,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: AppText.body,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md,
        ),
        hintStyle: AppText.body.copyWith(color: AppColors.inkTertiary),
        labelStyle: AppText.label.copyWith(color: AppColors.inkSecondary),
        // Borderless filled fields, the way iOS search and compose look.
        border: _field(Colors.transparent),
        enabledBorder: _field(Colors.transparent),
        focusedBorder: _field(AppColors.accent),
        errorBorder: _field(AppColors.destructive),
        focusedErrorBorder: _field(AppColors.destructive),
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x55FFFFFF),
        selectionHandleColor: AppColors.accent,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppText.label,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.canvas,
          textStyle: AppText.label,
          elevation: 0,
          minimumSize: const Size.fromHeight(50), // iOS min tap target
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: AppText.label,
          side: const BorderSide(color: AppColors.separator),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: AppText.body,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.ink),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.success // iOS switches are green when on
              : AppColors.surfacePressed,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
    );
  }

  static OutlineInputBorder _field(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: 1.5),
      );
}
