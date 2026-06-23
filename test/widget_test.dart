import 'package:flutter_test/flutter_test.dart';
import 'package:ota_cheshire_management_platform/main.dart';

void main() {
  testWidgets('welcome screen displays its primary actions', (tester) async {
    await tester.pumpWidget(const OTAApp());

    expect(find.text('WELCOME'), findsOneWidget);
    expect(find.text('Olympic Taekwondo Academy'), findsOneWidget);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('SIGN UP'), findsOneWidget);
  });
}
