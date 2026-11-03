import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_manga_reader/features/reader/presentation/widgets/reader_settings_sheet.dart';

void main() {
  group('ReaderSettingsSheet Widget Tests', () {
    testWidgets('renders all settings options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderSettingsSheet(
              isWebtoonMode: true,
              isRtlMode: false,
              isAutoScrolling: false,
              autoScrollSpeed: 1.0,
              hideMiniProgressBar: false,
              onWebtoonModeChanged: (_) {},
              onRtlModeChanged: (_) {},
              onAutoScrollChanged: (_) {},
              onAutoScrollSpeedChanged: (_) {},
              onHideMiniProgressBarChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Reading Settings'), findsOneWidget);
      expect(find.text('Reading Mode'), findsOneWidget);
      expect(find.text('Auto Scroll'), findsOneWidget);
      expect(find.text('Hide Mini Progress Bar'), findsOneWidget);
    });

    testWidgets('tapping Hide Mini Progress Bar row triggers callback with inverted value', (tester) async {
      bool? toggledVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderSettingsSheet(
              isWebtoonMode: true,
              isRtlMode: false,
              isAutoScrolling: false,
              autoScrollSpeed: 1.0,
              hideMiniProgressBar: false,
              onWebtoonModeChanged: (_) {},
              onRtlModeChanged: (_) {},
              onAutoScrollChanged: (_) {},
              onAutoScrollSpeedChanged: (_) {},
              onHideMiniProgressBarChanged: (val) => toggledVal = val,
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.text('Hide Mini Progress Bar'));
      expect(toggledVal, isTrue);
    });

    testWidgets('tapping Hide Mini Progress Bar switch triggers callback', (tester) async {
      bool? toggledVal;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderSettingsSheet(
              isWebtoonMode: true,
              isRtlMode: false,
              isAutoScrolling: false,
              autoScrollSpeed: 1.0,
              hideMiniProgressBar: true,
              onWebtoonModeChanged: (_) {},
              onRtlModeChanged: (_) {},
              onAutoScrollChanged: (_) {},
              onAutoScrollSpeedChanged: (_) {},
              onHideMiniProgressBarChanged: (val) => toggledVal = val,
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the second Switch (Hide Mini Progress Bar)
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));
      await tester.tap(switches.last);
      expect(toggledVal, isFalse);
    });
  });
}
