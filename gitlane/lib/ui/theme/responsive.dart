import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  static bool isMedium(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 900;

  static double horizontalPadding(double width) {
    if (width >= 1200) return 40;
    if (width >= 900) return 28;
    if (width >= 600) return 24;
    return 16;
  }

  static double maxContentWidth(double width) {
    if (width >= 1200) return 1024;
    if (width >= 900) return 860;
    if (width >= 600) return 760;
    return width;
  }
}
