import 'package:flutter/material.dart';

abstract final class StyleConstants {
  static const double cardSpace = 8;
  static const double safeSpace = 12;
  static const double pageMaxWidth = 1000;
  static const double pagePadding = 16;
  static const double sectionSpacing = 24;
  static const double cardRadius = 16;
  static const double tileRadius = 12;
  static const double chipRadius = 8;
  static BorderRadius mdRadius = BorderRadius.circular(10);
  static const Radius imgRadius = Radius.circular(12);
  static const double aspectRatio = 16 / 10;
}

double cardRadiusFor(BuildContext context) {
  final shape = Theme.of(context).cardTheme.shape;
  if (shape is RoundedRectangleBorder) {
    return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
  }
  return StyleConstants.cardRadius;
}
