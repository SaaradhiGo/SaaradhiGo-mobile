// Owner decision D4 (2026-11-02): hold 2 seconds to send, sent at once, with a
// haptic. The audit raised a real SOS with one accidental tap.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saaradhigo_rider/widgets/hold_to_send_button.dart';

void main() {
  late int sent;
  late List<String> haptics;

  Future<void> pump(WidgetTester tester) async {
    sent = 0;
    haptics = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add('${call.arguments}');
        return null;
      },
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: HoldToSendButton(
              key: const Key('h'),
              label: 'Hold to send alert',
              onConfirmed: () => sent++,
            ),
          ),
        ),
      ),
    ));
  }

  Future<void> hold(WidgetTester tester, Duration d) async {
    final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('h'))));
    for (var t = Duration.zero; t < d; t += const Duration(milliseconds: 100)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('a tap sends nothing', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('h')));
    await tester.pump(const Duration(seconds: 3));
    expect(sent, 0);
  });

  testWidgets('letting go at 1.5 s sends nothing', (tester) async {
    await pump(tester);
    await hold(tester, const Duration(milliseconds: 1500));
    expect(sent, 0);
  });

  testWidgets('a full 2 s hold sends once, with a heavy haptic', (tester) async {
    await pump(tester);
    await hold(tester, const Duration(milliseconds: 2200));
    expect(sent, 1);
    expect(haptics, contains('HapticFeedbackType.heavyImpact'));
  });

  testWidgets('it tells a screen reader how it works', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(
      tester.getSemantics(find.byKey(const Key('h'))),
      matchesSemantics(
        label: 'Hold to send alert',
        hint: 'Press and hold for 2 seconds to send',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasLongPressAction: true,
      ),
    );
    handle.dispose();
  });
}
