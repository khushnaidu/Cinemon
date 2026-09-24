import 'package:cinemon/models/list_model.dart';
import 'package:cinemon/providers/lists/list_provider.dart';
import 'package:flutter_test/flutter_test.dart';

ListItem item(int id, double pos) => ListItem(
    listId: 'l', filmId: id, mediaType: 'movie', title: '$id', position: pos);

void main() {
  final items = [item(1, 1), item(2, 2), item(3, 3), item(4, 4)];

  test('down, to the middle: one new position, the midpoint', () {
    final r = planMove(items, 0, 2);
    expect(r.order.map((i) => i.filmId), [2, 3, 1, 4]);
    expect(r.order[2].position, 3.5);
    expect(r.renumbered, isFalse);
  });

  test('to the end and the start', () {
    expect(planMove(items, 1, 3).order.last.position, 5);
    expect(planMove(items, 3, 0).order.first.position, 0);
  });

  test('positions stay sorted over many moves', () {
    var order = items;
    for (var i = 0; i < 30; i++) {
      order = planMove(order, order.length - 1, 1).order;
      final positions = order.map((i) => i.position).toList();
      expect(positions, [...positions]..sort());
    }
  });

  test('renumbers when the gap is too small to split', () {
    final tight = [item(1, 1), item(2, 1 + 1e-10), item(3, 3)];
    final r = planMove(tight, 2, 1);
    expect(r.renumbered, isTrue);
    expect(r.order.map((i) => i.position), [1, 2, 3]);
    expect(r.order.map((i) => i.filmId), [1, 3, 2]);
  });
}
