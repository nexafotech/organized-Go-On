import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/widgets/widgets.dart';

void main() {
  group('Go-On branding', () {
    test('brand name uses exact capitalisation', () {
      expect(GoOnBrand.name, 'Go-On');
      expect(GoOnBrand.logoSemanticLabel, 'Go-On logo');
    });

    testWidgets('official logo asset is bundled and is a valid image', (tester) async {
      final data = await rootBundle.load(GoOnBrand.logoAsset);
      expect(data.lengthInBytes, greaterThan(1000));
      // PNG signature
      expect(data.getUint8(1), 0x50);
      expect(data.getUint8(2), 0x4E);
      expect(data.getUint8(3), 0x47);
    });

    testWidgets('vertical lockup renders logo + Go-On, never wraps, at 2x text', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: const Scaffold(
                body: Center(
                  child: SizedBox(width: 160, child: GoOnLockup(logoSize: 104, fontSize: 30)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Go-On'), findsOneWidget);
        expect(find.bySemanticsLabel('Go-On logo'), findsOneWidget);
        final text = tester.widget<Text>(find.text('Go-On'));
        expect(text.maxLines, 1);
        expect(text.softWrap, false);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('logo keeps its square aspect ratio (never stretched)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: Center(child: GoOnLogo(size: 64))),
        ),
      );
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(Image));
      expect(size.width, size.height);
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
    });

    testWidgets('badge (cream surfaces) and horizontal lockup render without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                GoOnLogoBadge(size: 30),
                GoOnLockup(axis: GoOnLockupAxis.horizontal, logoSize: 32, fontSize: 18),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Go-On'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
