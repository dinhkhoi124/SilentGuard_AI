import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/injection_container.dart';
import 'package:mobile/main.dart';

void main() {
  setUpAll(init);

  testWidgets('renders the loaded smart home screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('My Home'), findsOneWidget);
    expect(find.text('20°C'), findsOneWidget);
    expect(find.text('No Devices'), findsOneWidget);
    expect(find.text('Living Room'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });
}
