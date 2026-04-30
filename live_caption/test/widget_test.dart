import 'package:flutter_test/flutter_test.dart';

import 'package:live_caption/main.dart';

void main() {
  testWidgets('Live caption app builds', (tester) async {
    await tester.pumpWidget(const LiveCaptionApp());

    expect(find.byType(LiveCaptionApp), findsOneWidget);
  });
}
