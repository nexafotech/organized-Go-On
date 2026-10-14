import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/core/theme/app_theme.dart';
import 'package:attendance_marker_mobile/models/student_model.dart';
import 'package:attendance_marker_mobile/widgets/avatar/user_avatar_widget.dart';
import 'package:attendance_marker_mobile/widgets/avatar/avatar_picker_sheet.dart';

void main() {
  group('Avatar System - Model & Logic Tests', () {
    test('AvatarItemModel catalog contains exactly 16 items', () {
      expect(AvatarItemModel.catalog.length, equals(16));
    });

    test('Catalog items have non-empty attributes and valid categories', () {
      final validCategories = {'masculine', 'feminine', 'neutral'};
      for (final item in AvatarItemModel.catalog) {
        expect(item.id.isNotEmpty, isTrue);
        expect(item.name.isNotEmpty, isTrue);
        expect(item.assetPath.startsWith('assets/avatars/'), isTrue);
        expect(validCategories.contains(item.category), isTrue);
      }
    });

    test('Category breakdowns match specification: 8 masculine, 8 feminine, 6 neutral', () {
      final masculine = AvatarItemModel.catalog.where((a) => a.category == 'masculine').toList();
      final feminine = AvatarItemModel.catalog.where((a) => a.category == 'feminine').toList();
      final neutral = AvatarItemModel.catalog.where((a) => a.isNeutral).toList();

      expect(masculine.length, equals(8));
      expect(feminine.length, equals(8));
      expect(neutral.length, equals(6));
    });

    test('Deterministic avatar assignment is stable across identical seeds', () {
      final res1 = AvatarItemModel.resolveAsset(null, fallbackSeed: 'CS2021001');
      final res2 = AvatarItemModel.resolveAsset(null, fallbackSeed: 'CS2021001');
      expect(res1, equals(res2));

      final resFaculty1 = AvatarItemModel.resolveAsset('', fallbackSeed: 'FACULTY_JOHN');
      final resFaculty2 = AvatarItemModel.resolveAsset('', fallbackSeed: 'FACULTY_JOHN');
      expect(resFaculty1, equals(resFaculty2));
    });

    test('Explicit valid avatarId overrides seed fallback', () {
      final res = AvatarItemModel.resolveAsset('avatar_f3', fallbackSeed: 'CS2021001');
      expect(res, equals('assets/avatars/avatar_f3.png'));
    });

    test('Invalid avatarId safely falls back to deterministic seed assignment', () {
      final fallbackSeed = 'CS2021099';
      final resInvalid = AvatarItemModel.resolveAsset('non_existent_avatar', fallbackSeed: fallbackSeed);
      final resFallback = AvatarItemModel.resolveAsset(null, fallbackSeed: fallbackSeed);
      expect(resInvalid, equals(resFallback));
      expect(resInvalid.startsWith('assets/avatars/'), isTrue);
    });
  });

  group('UserAvatarWidget & AvatarPickerSheet Widget Tests', () {
    Widget buildHarness(Widget child) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(child: child),
        ),
      );
    }

    testWidgets('UserAvatarWidget renders with avatarId', (WidgetTester tester) async {
      await tester.pumpWidget(buildHarness(
        const UserAvatarWidget(
          avatarId: 'avatar_m1',
          radius: 30,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatarWidget), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('UserAvatarWidget displays edit badge when showEditBadge is true', (WidgetTester tester) async {
      bool editTapped = false;
      await tester.pumpWidget(buildHarness(
        UserAvatarWidget(
          avatarId: 'avatar_m2',
          radius: 35,
          showEditBadge: true,
          onEditTap: () {
            editTapped = true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();
      expect(editTapped, isTrue);
    });

    testWidgets('AvatarPickerSheet renders tabs, previews, and responds to save', (WidgetTester tester) async {
      String? savedAvatarId;

      await tester.pumpWidget(buildHarness(
        AvatarPickerSheet(
          currentAvatarId: 'avatar_m1',
          userSeed: 'CS2021001',
          onSave: (id) async {
            savedAvatarId = id;
            return true;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Check header and tabs
      expect(find.text('Choose Your Avatar'), findsOneWidget);
      expect(find.text('All (16)'), findsOneWidget);
      expect(find.text('Masculine (8)'), findsOneWidget);
      expect(find.text('Feminine (8)'), findsOneWidget);
      expect(find.text('Neutral (6)'), findsOneWidget);

      // Verify active preview has default avatar name
      expect(find.text('Curly Cream Hoodie'), findsOneWidget);

      // Filter to Feminine category
      await tester.tap(find.text('Feminine (8)'));
      await tester.pumpAndSettle();

      // Tap on an avatar image in the filtered grid
      final gridImages = find.byType(Image);
      expect(gridImages, findsWidgets);
      await tester.tap(gridImages.at(1), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Check Save button and tap it
      expect(find.text('Save Avatar'), findsOneWidget);
      await tester.tap(find.text('Save Avatar'));
      await tester.pumpAndSettle();

      expect(savedAvatarId, isNotNull);
    });
  });
}
