import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';
import 'spacing.dart';

class GariTheme {
  GariTheme._();

  static ThemeData light(Locale locale, {bool driverChrome = false}) {
    final isAm = locale.languageCode == 'am';
    final textTheme = isAm
        ? GoogleFonts.notoSansEthiopicTextTheme()
        : GoogleFonts.manropeTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: GariColors.cream,
      primaryColor: GariColors.nightBlue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: GariColors.nightBlue,
        primary: GariColors.nightBlue,
        secondary: GariColors.amber,
        tertiary: GariColors.emerald,
        error: GariColors.crimson,
        surface: GariColors.cream,
      ),
      textTheme: textTheme.apply(
        bodyColor: GariColors.nightBlue,
        displayColor: GariColors.nightBlue,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: GariColors.cream,
        foregroundColor: GariColors.nightBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: (isAm
                ? GoogleFonts.notoSansEthiopic
                : GoogleFonts.manrope)(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: GariColors.nightBlue,
        ),
        iconTheme: const IconThemeData(color: GariColors.nightBlue),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: GariColors.cream.withValues(alpha: 0.96),
        indicatorColor: GariColors.nightBlue,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return (isAm ? GoogleFonts.notoSansEthiopic : GoogleFonts.manrope)(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: selected ? GariColors.nightBlue : GariColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? GariColors.amber400 : GariColors.muted,
            size: 22,
          );
        }),
      ),
      dividerColor: GariColors.border,
      cardTheme: CardThemeData(
        color: GariColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GariSpacing.radiusLg),
          side: const BorderSide(color: GariColors.border, width: 1.5),
        ),
      ),
    );
  }
}
