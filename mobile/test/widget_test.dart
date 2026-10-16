import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/main.dart';
import 'package:attendance_marker_mobile/auth/screens/login_screen.dart';

void main() {
  testWidgets('App launches directly to LoginScreen on fresh start without splash', (WidgetTester tester) async {
    await tester.pumpWidget(const AttendanceMarkerApp());
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
