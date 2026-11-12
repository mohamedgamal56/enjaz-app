import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz/core/theme/app_colors.dart';
import 'package:enjaz/core/theme/color_contrast.dart';

void main() {
  group('Design Tokens Contrast Verification (UI.md Section 3 & PLAN.md Batch 4)', () {
    test('Pure Dart contrast function accurately computes known WCAG values', () {
      // Pure black on pure white must equal 21:1
      expect(
        ColorContrast.calculateRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21.0, 0.05),
      );
      // Same color on same color must equal 1:1
      expect(
        ColorContrast.calculateRatio(const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)),
        closeTo(1.0, 0.01),
      );
    });

    group('Light Mode Token Pairs Contrast', () {
      final lightSurfaces = {
        'background': AppColors.lightBackground,
        'card': AppColors.lightSurface,
        'inner surface': AppColors.lightSurfaceVariant,
      };

      for (final surfaceEntry in lightSurfaces.entries) {
        final surfaceName = surfaceEntry.key;
        final surfaceColor = surfaceEntry.value;

        test('Primary text on $surfaceName meets WCAG AA (>= 4.5:1)', () {
          final ratio = ColorContrast.calculateRatio(AppColors.lightText, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'lightText ($ratio:1) failed to reach 4.5:1 on $surfaceName',
          );
        });

        test('Text secondary (textMuted) on $surfaceName meets WCAG AA (>= 4.5:1)', () {
          final ratio = ColorContrast.calculateRatio(AppColors.lightTextMuted, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'lightTextMuted ($ratio:1) failed to reach 4.5:1 on $surfaceName',
          );
        });

        test('Warning text on $surfaceName meets WCAG AA (>= 4.5:1)', () {
          final ratio = ColorContrast.calculateRatio(AppColors.lightWarningText, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'lightWarningText ($ratio:1) failed to reach 4.5:1 on $surfaceName',
          );
        });

        test('Accent color on $surfaceName meets WCAG large text/component threshold (>= 3.0:1)', () {
          final ratio = ColorContrast.calculateRatio(AppColors.lightAccent, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: 'lightAccent ($ratio:1) failed to reach 3.0:1 on $surfaceName',
          );
        });
      }
    });

    group('Dark Mode Token Pairs Contrast', () {
      final darkSurfaces = {
        'background': AppColors.darkBackground,
        'card': AppColors.darkSurface,
        'inner surface': AppColors.darkSurfaceVariant,
      };

      for (final surfaceEntry in darkSurfaces.entries) {
        final surfaceName = surfaceEntry.key;
        final surfaceColor = surfaceEntry.value;

        test('Primary text on $surfaceName meets WCAG AA (>= 4.5:1)', () {
          final ratio = ColorContrast.calculateRatio(AppColors.darkText, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'darkText ($ratio:1) failed to reach 4.5:1 on $surfaceName',
          );
        });

        test('Text secondary (textMuted) on $surfaceName meets WCAG AA (>= 4.5:1)', () {
          final ratio = ColorContrast.calculateRatio(AppColors.darkTextMuted, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'darkTextMuted ($ratio:1) failed to reach 4.5:1 on $surfaceName',
          );
        });

        test('Warning text on $surfaceName meets WCAG AA (>= 4.5:1)', () {
          final ratio = ColorContrast.calculateRatio(AppColors.darkWarningText, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'darkWarningText ($ratio:1) failed to reach 4.5:1 on $surfaceName',
          );
        });

        test('Accent color on $surfaceName meets WCAG AA (>= 4.5:1)', () {
          final ratio = ColorContrast.calculateRatio(AppColors.darkAccent, surfaceColor);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: 'darkAccent ($ratio:1) failed to reach 4.5:1 on $surfaceName',
          );
        });
      }
    });
  });
}
