import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  /// Global theme mode notifier — toggle anywhere, rebuilds the whole app.
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.dark);

  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const Color bg0 = Color(0xFF0D1117); // page background (GitHub dark)
  static const Color bg1 = Color(0xFF161B22); // card surface
  static const Color bg2 = Color(0xFF21262D); // elevated card / dialog
  static const Color border = Color(0xFF30363D); // subtle dividers

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFE6EDF3); // headings
  static const Color textSecondary = Color(0xFF8B949E); // meta info
  static const Color textMuted = Color(0xFF484F58); // placeholder

  // ── Semantic / Dev-centric accents ──────────────────────────────────────────
  static const Color accentCyan = Color(0xFF39C5CF); // primary CTA, links
  static const Color accentGreen = Color(
    0xFF3FB950,
  ); // clean, staged, success, main branch
  static const Color accentYellow = Color(
    0xFFD29922,
  ); // modified, warnings, unstaged
  static const Color accentRed = Color(
    0xFFF85149,
  ); // conflicts, errors, deleted
  static const Color accentBlue = Color(0xFF58A6FF); // info, staged indicator
  static const Color accentPurple = Color(0xFFBC8CFF); // graph lane, branch 2
  static const Color accentOrange = Color(0xFFE3B341); // stash, pending

  // ── Legacy aliases (keep for backward compat) ───────────────────────────────
  static const Color primaryNavy = Color(0xFF0B1223);
  static const Color backgroundBlack = bg0;
  static const Color surfaceSlate = bg1;
  static const Color textLight = textPrimary;
  static const Color textDim = textSecondary;

  // ── Gradients ────────────────────────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D1117), Color(0xFF161B22), Color(0xFF0D1117)],
  );

  static const LinearGradient cardBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF39C5CF), Color(0xFFBC8CFF)],
  );

  // ── Status color helpers ─────────────────────────────────────────────────────
  static Color statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('conflict')) return accentRed;
    if (s.contains('deleted')) return accentRed;
    if (s.contains('modified')) return accentYellow;
    if (s.contains('untracked')) return accentBlue;
    if (s.contains('staged') || s.contains('new')) return accentGreen;
    return textSecondary;
  }

  static IconData statusIcon(String status) {
    final s = status.toLowerCase();
    if (s.contains('conflict')) return Icons.error_outline_rounded;
    if (s.contains('deleted')) return Icons.remove_circle_outline_rounded;
    if (s.contains('modified')) return Icons.edit_rounded;
    if (s.contains('untracked')) return Icons.fiber_new_rounded;
    if (s.contains('staged') || s.contains('new')) {
      return Icons.add_circle_outline_rounded;
    }
    return Icons.help_outline_rounded;
  }

  static String statusLabel(String status) {
    final s = status.toLowerCase();
    if (s.contains('conflict')) return 'C';
    if (s.contains('deleted')) return 'D';
    if (s.contains('modified')) return 'M';
    if (s.contains('untracked')) return 'U';
    if (s.contains('staged') || s.contains('new')) return 'A';
    return '?';
  }

  // ── Theme ────────────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: bg0,
      primaryColor: accentCyan,

      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        onPrimary: Colors.black,
        secondary: accentGreen,
        onSecondary: Colors.black,
        tertiary: accentPurple,
        surface: bg1,
        onSurface: textPrimary,
        error: accentRed,
        onError: Colors.black,
        outline: border,
        surfaceContainerHighest: bg2,
      ),

      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: textSecondary, fontSize: 13),
        bodySmall: GoogleFonts.firaMono(color: textSecondary, fontSize: 12),
        labelLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: GoogleFonts.firaMono(color: textSecondary, fontSize: 12),
        labelSmall: GoogleFonts.firaMono(color: textMuted, fontSize: 11),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: bg0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: border,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textSecondary, size: 22),
        actionsIconTheme: const IconThemeData(color: textSecondary, size: 22),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: bg1,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentCyan.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentCyan, size: 22);
          }
          return const IconThemeData(color: textSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              color: accentCyan,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return GoogleFonts.inter(color: textSecondary, fontSize: 12);
        }),
        height: 64,
      ),

      cardTheme: CardThemeData(
        color: bg1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bg2,
        hintStyle: GoogleFonts.inter(color: textMuted, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentCyan, width: 1.5),
        ),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minLeadingWidth: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: bg2,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: border),
        ),
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: bg2,
        side: const BorderSide(color: border),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentCyan,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: bg2,
        contentTextStyle: GoogleFonts.inter(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: accentCyan,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: bg2,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: border),
        ),
        textStyle: GoogleFonts.inter(color: textPrimary, fontSize: 14),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentCyan,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentCyan,
          foregroundColor: Colors.black,
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  // ── Light Theme ─────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const Color lBg0 = Color(0xFFFFFFFF);
    const Color lBg1 = Color(0xFFF6F8FA);
    const Color lBg2 = Color(0xFFEAEEF2);
    const Color lBorder = Color(0xFFD0D7DE);
    const Color lTextPrimary = Color(0xFF1F2328);
    const Color lTextSecondary = Color(0xFF636C76);
    const Color lTextMuted = Color(0xFF8C959F);

    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: lBg0,
      primaryColor: accentCyan,

      colorScheme: const ColorScheme.light(
        primary: accentCyan,
        onPrimary: Colors.white,
        secondary: accentGreen,
        onSecondary: Colors.white,
        tertiary: accentPurple,
        surface: lBg1,
        onSurface: lTextPrimary,
        error: accentRed,
        onError: Colors.white,
        outline: lBorder,
        surfaceContainerHighest: lBg2,
      ),

      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
            color: lTextPrimary, fontSize: 32, fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.inter(
            color: lTextPrimary, fontSize: 24, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.inter(
            color: lTextPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.inter(
            color: lTextPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(
            color: lTextPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(
            color: lTextPrimary, fontSize: 15, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.inter(color: lTextPrimary, fontSize: 15),
        bodyMedium: GoogleFonts.inter(color: lTextSecondary, fontSize: 13),
        bodySmall: GoogleFonts.firaMono(color: lTextSecondary, fontSize: 12),
        labelLarge: GoogleFonts.inter(
            color: lTextPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium:
            GoogleFonts.firaMono(color: lTextSecondary, fontSize: 12),
        labelSmall: GoogleFonts.firaMono(color: lTextMuted, fontSize: 11),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: lBg0,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: lBorder,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
            color: lTextPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        iconTheme:
            const IconThemeData(color: lTextSecondary, size: 22),
        actionsIconTheme:
            const IconThemeData(color: lTextSecondary, size: 22),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lBg1,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentCyan.withValues(alpha: 0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentCyan, size: 22);
          }
          return const IconThemeData(color: lTextSecondary, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
                color: accentCyan, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return GoogleFonts.inter(color: lTextSecondary, fontSize: 12);
        }),
        height: 64,
      ),

      cardTheme: CardThemeData(
        color: lBg1,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lBorder, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lBg2,
        hintStyle:
            GoogleFonts.inter(color: lTextMuted, fontSize: 14),
        labelStyle:
            GoogleFonts.inter(color: lTextSecondary, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentCyan, width: 1.5),
        ),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minLeadingWidth: 24,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      dividerTheme:
          const DividerThemeData(color: lBorder, thickness: 1, space: 1),

      dialogTheme: DialogThemeData(
        backgroundColor: lBg2,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lBorder),
        ),
        titleTextStyle: GoogleFonts.inter(
            color: lTextPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        contentTextStyle:
            GoogleFonts.inter(color: lTextSecondary, fontSize: 14),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: lBg2,
        side: const BorderSide(color: lBorder),
        labelStyle:
            GoogleFonts.inter(color: lTextSecondary, fontSize: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentCyan,
        foregroundColor: Colors.white,
        elevation: 4,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: lBg2,
        contentTextStyle:
            GoogleFonts.inter(color: lTextPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: lBorder),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: accentCyan,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: lBg2,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: lBorder),
        ),
        textStyle:
            GoogleFonts.inter(color: lTextPrimary, fontSize: 14),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentCyan,
          textStyle: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentCyan,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  // ── Utility text styles (use anywhere) ──────────────────────────────────────
  static TextStyle get monoSmall =>
      GoogleFonts.firaMono(color: textSecondary, fontSize: 12);

  static TextStyle get monoBadge => GoogleFonts.firaMono(
    color: accentCyan,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get monoHash =>
      GoogleFonts.firaMono(color: accentCyan, fontSize: 12);
}
