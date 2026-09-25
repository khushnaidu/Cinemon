import 'package:cinemon/screens/widgets/glass_panel.dart';
import 'package:cinemon/screens/widgets/liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a selected chip is lit edge to edge, in a scrolling row',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GlassChip(label: 'Season 2', selected: true, onTap: () {}),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final chip = tester.getSize(find.byType(GlassChip));
    final lens = tester.getSize(find.byType(GlassLens));
    // Inside the glass's hairline edge.
    expect(lens.width, closeTo(chip.width, 2));
    expect(lens.height, closeTo(chip.height, 2));
  });
}
