import 'package:flutter/material.dart';

import '../l10n/campus_strings.dart';

/// Opt-in styling for the local preview; never registered as an official theme.
class CampusDesign extends ThemeExtension<CampusDesign> {
  const CampusDesign({
    required this.paper,
    required this.ink,
    required this.accent,
    required this.rule,
  });

  factory CampusDesign.preview({bool dark = false}) => CampusDesign(
        paper: dark ? const Color(0xff1c211f) : const Color(0xfff8f7f2),
        ink: dark ? const Color(0xffe7e5d9) : const Color(0xff303d38),
        accent: dark ? const Color(0xffefa18c) : const Color(0xffb64d3b),
        rule: dark ? const Color(0xff657169) : const Color(0xffd6d8cf),
      );

  final Color paper;
  final Color ink;
  final Color accent;
  final Color rule;

  static const headingFamily = 'CampusMincho';

  static CampusDesign? maybeOf(BuildContext context) =>
      Theme.of(context).extension<CampusDesign>();

  static String weekdayName(int weekday) =>
      '${const ['月', '火', '水', '木', '金', '土', '日'][weekday - 1]}曜日';

  TextStyle heading(double size, {FontWeight weight = FontWeight.w600}) =>
      TextStyle(
        fontFamily: headingFamily,
        fontSize: size,
        fontWeight: weight,
        height: 1.3,
        color: ink,
      );

  // Interface labels only; course data never passes through this lookup.
  String label(String text) => CampusStrings.lookup(text);

  ThemeData applyTo(ThemeData base) => base.copyWith(
        scaffoldBackgroundColor: paper,
        extensions: [...base.extensions.values, this],
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: ink),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: accent),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: ink, foregroundColor: paper),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: BorderSide(color: rule),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? paper : null),
          trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected) ? ink : null),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: paper,
          modalBackgroundColor: paper,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          fillColor: paper,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: rule),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: accent),
          ),
        ),
        dialogTheme: base.dialogTheme.copyWith(backgroundColor: paper),
        cardTheme: base.cardTheme.copyWith(
          color: paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: rule, width: .7),
          ),
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
        ),
      );

  @override
  CampusDesign copyWith(
          {Color? paper, Color? ink, Color? accent, Color? rule}) =>
      CampusDesign(
        paper: paper ?? this.paper,
        ink: ink ?? this.ink,
        accent: accent ?? this.accent,
        rule: rule ?? this.rule,
      );

  @override
  CampusDesign lerp(covariant CampusDesign? other, double t) {
    if (other == null) return this;
    return CampusDesign(
      paper: Color.lerp(paper, other.paper, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      rule: Color.lerp(rule, other.rule, t)!,
    );
  }
}
