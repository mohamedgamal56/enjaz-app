import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Pure Dart utility to calculate WCAG 2.1 relative luminance and contrast ratio.
/// Complies with UI.md Section 3:
/// "A pure Dart contrast function plus a unit test: every text and background
/// pair of these tokens must reach 4.5:1 (3:1 for text of 24 px and above), in both themes."
class ColorContrast {
  ColorContrast._();

  /// Converts an 8-bit sRGB channel (0..255) to linear luminance value (0.0..1.0)
  /// per W3C WCAG 2.1 specification.
  static double channelToLinear(int channel) {
    final c = channel / 255.0;
    if (c <= 0.03928) {
      return c / 12.92;
    } else {
      return math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }
  }

  /// Calculates the relative luminance of a [Color] normalized to 0.0 for darkest black
  /// and 1.0 for lightest white.
  static double relativeLuminance(Color color) {
    final r = channelToLinear(color.red);
    final g = channelToLinear(color.green);
    final b = channelToLinear(color.blue);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Calculates the contrast ratio between two colors.
  /// Result ranges from 1.0 (no contrast, e.g. white on white) to 21.0 (black on white).
  static double calculateRatio(Color foreground, Color background) {
    final l1 = relativeLuminance(foreground);
    final l2 = relativeLuminance(background);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Checks whether contrast meets WCAG AA standard:
  /// - Normal body text (< 24px regular, < 18.5px bold): minimum 4.5:1
  /// - Large text (>= 24px regular, >= 18.5px bold) or graphical UI objects: minimum 3.0:1
  static bool meetsWcagAA(Color foreground, Color background, {bool isLargeText = false}) {
    final ratio = calculateRatio(foreground, background);
    return ratio >= (isLargeText ? 3.0 : 4.5);
  }
}
