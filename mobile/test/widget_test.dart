import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_marker_mobile/main.dart';

void main() {
  testWidgets('App renders splash screen initially', (WidgetTester tester) async {
    await tester.pumpWidget(const AttendanceMarkerApp());
    expect(find.text('Go-On'), findsOneWidget);
  });
}
