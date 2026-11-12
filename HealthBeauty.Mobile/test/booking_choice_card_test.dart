import 'package:app_doancunhan/widgets/booking_choice_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'card selects and stays usable with large text on a narrow phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => BookingChoiceCard(
                  title: 'Dịch vụ chăm sóc da chuyên sâu thời gian dài',
                  duration: '1 giờ',
                  price: '300.000 đ',
                  selected: selected,
                  onTap: () => setState(() => selected = !selected),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Chưa có ảnh'), findsOneWidget);
      await tester.tap(find.text('300.000 đ'));
      await tester.pump();
      expect(selected, isTrue);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
