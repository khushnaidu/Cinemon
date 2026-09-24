import 'package:cinemon/core/utils/auth_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('password', () {
    test('needs 8 characters, a letter and a number', () {
      expect(passwordOk('abc12345'), isTrue);
      expect(passwordOk('abcdefgh'), isFalse);
      expect(passwordOk('12345678'), isFalse);
      expect(passwordOk('abc1234'), isFalse);
      expect(passwordOk('Pässwörd 2 long!'), isTrue);
    });

    test('the checklist ticks each rule on its own', () {
      final met = [for (final r in passwordRules) r.test('abc')];
      expect(met, [false, true, false]);
    });
  });

  group('username', () {
    test('matches the server rule in migration 015', () {
      expect(usernameProblem('bob'), isNull);
      expect(usernameProblem('bob.films_2'), isNull);
      expect(usernameProblem('a' * 24), isNull);
      expect(usernameProblem(''), isNotNull);
      expect(usernameProblem('ab'), isNotNull);
      expect(usernameProblem('a' * 25), isNotNull);
      expect(usernameProblem('Bob'), isNotNull);
      expect(usernameProblem('has space'), isNotNull);
      expect(usernameProblem('.bob'), isNotNull);
      expect(usernameProblem('bob.'), isNotNull);
      expect(usernameProblem('bob-films'), isNotNull);
    });

    test('typing is normalised as you go', () {
      expect(normaliseUsername('Bob Films!'), 'bob_films');
      expect(normaliseUsername('a.b_c'), 'a.b_c');
    });

    test('suggestions come from the name first, then the email', () {
      expect(
          suggestUsername(name: 'Carol King', email: 'ck@x.com'), 'carol_king');
      expect(suggestUsername(email: 'j.doe+films@gmail.com'), 'j.doefilms');
      expect(suggestUsername(email: 'ab@x.com'), '');
      expect(suggestUsername(name: '  ', email: '.dots.@x.com'), 'dots');
      expect(suggestUsername(email: '${'x' * 30}@x.com').length, 24);
    });
  });
}
