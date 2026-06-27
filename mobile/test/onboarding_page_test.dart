import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/onboarding/presentation/pages/onboarding_page.dart';

void main() {
  for (final size in const [Size(320, 568), Size(360, 640)]) {
    testWidgets(
      'OnboardingPage has no overflow at ${size.width}x${size.height}',
      (tester) async {
        final errors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = errors.add;

        addTearDown(() {
          FlutterError.onError = previousOnError;
        });

        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final overflowErrors = errors.where(
          (details) => details.exceptionAsString().contains('overflowed by'),
        );
        expect(overflowErrors, isEmpty);
      },
    );
  }
}
