import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/screens/profile/help_support_screen.dart';

/// 18 Nov: the Help bottom bar lost its fixed height (to grow with the text size) and its
/// max-size columns then filled the whole screen, so the page showed only the bar.
void main() {
  testWidgets('the Help bottom bar sits at the bottom and the page shows its content', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
    await tester.pumpAndSettle();
    final home = find.text('Home').last;
    expect(tester.getTopLeft(home).dy, greaterThan(915 - 120));
    expect(find.byType(TextField), findsWidgets);
  });
}
