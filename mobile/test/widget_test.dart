import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/main.dart';
import 'package:attendance_marker_mobile/auth/screens/splash_screen.dart';

void main() {
  testWidgets('App renders new branded splash screen initially', (WidgetTester tester) async {
    await tester.pumpWidget(const AttendanceMarkerApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Go-On'), findsNothing); // Old text lockup removed in favor of authoritative Image 2
  });
}
