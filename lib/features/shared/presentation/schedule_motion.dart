import 'package:flutter/material.dart';

abstract final class ScheduleMotion {
  static Duration durationOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180);

  static AnimationStyle sheetStyleOf(BuildContext context) => AnimationStyle(
        duration: durationOf(context),
        reverseDuration: durationOf(context),
      );
}
