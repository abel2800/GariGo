import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

class AppText {
  AppText._();

  static bool _isAm(Locale? l) => l?.languageCode == 'am';

  static TextStyle _base(Locale? locale, TextStyle style) {
    if (_isAm(locale)) return GoogleFonts.notoSansEthiopic(textStyle: style);
    return GoogleFonts.manrope(textStyle: style);
  }

  static TextStyle display(BuildContext c, {Color? color}) => _base(
        Localizations.localeOf(c),
        TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          height: 1.15,
          color: color ?? GariColors.nightBlue,
        ),
      );

  static TextStyle title(BuildContext c, {Color? color}) => _base(
        Localizations.localeOf(c),
        TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: color ?? GariColors.nightBlue,
        ),
      );

  static TextStyle headline(BuildContext c, {Color? color}) => _base(
        Localizations.localeOf(c),
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: color ?? GariColors.nightBlue,
        ),
      );

  static TextStyle body(BuildContext c, {Color? color}) => _base(
        Localizations.localeOf(c),
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: color ?? GariColors.slate,
        ),
      );

  static TextStyle label(BuildContext c, {Color? color}) => _base(
        Localizations.localeOf(c),
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color ?? GariColors.nightBlue,
        ),
      );

  static TextStyle caption(BuildContext c, {Color? color}) => _base(
        Localizations.localeOf(c),
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color ?? GariColors.slate,
        ),
      );

  static TextStyle money(BuildContext c, {Color? color, double size = 28}) =>
      GoogleFonts.manrope(
        textStyle: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: color ?? GariColors.amber,
        ),
      );
}
