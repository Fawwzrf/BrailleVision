import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:braillevision/main.dart';

void main() {
  testWidgets('BrailleVisionApp renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BrailleVisionApp()),
    );
  });
}
