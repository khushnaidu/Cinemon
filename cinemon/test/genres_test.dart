import 'package:cinemon/models/film_model.dart' show MediaType;
import 'package:cinemon/models/genres.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final type in MediaType.values) {
    test('$type: the buttons are genres the database asks about', () {
      final popular = popularGenresFor(type);
      expect(popular, hasLength(8));
      expect(popular.every(genresFor(type).contains), isTrue);
    });
  }

  test('a genre only carries over where the other type has it', () {
    expect(genreById(MediaType.tv, 35)?.name, 'Comedy');
    expect(genreById(MediaType.tv, 27), isNull); // Horror
    expect(genreById(MediaType.movie, null), isNull);
  });
}
