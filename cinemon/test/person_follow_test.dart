import 'package:cinemon/models/notification_model.dart';
import 'package:cinemon/models/person_follow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a new-work alert parses with no acting user', () {
    final n = NotificationModel.fromRow({
      'id': 'n1',
      'recipient_id': 'u1',
      'actor_id': null,
      'actor': null,
      'type': 'personNewCredit',
      'film_title': 'Project Hail Mary',
      'film_poster_path': '/p.jpg',
      'comment_preview': 'as Ryland · Director',
      'person_id': 500,
      'person_name': 'Florence Pugh',
      'person_profile_path': '/fp.jpg',
      'film_id': 2,
      'media_type': 'movie',
      'is_read': false,
      'created_at': '2026-09-24T10:00:00Z',
    });
    expect(n.type, NotificationType.personNewCredit);
    expect(n.actorId, isNull);
    expect(n.actorUsername, '');
    expect(n.personName, 'Florence Pugh');
    expect(n.filmId, 2);
    expect(n.message, 'is in Project Hail Mary');
  });

  test('older rows with an actor still read the joined username', () {
    final n = NotificationModel.fromRow({
      'id': 'n2',
      'recipient_id': 'u1',
      'actor_id': 'u2',
      'actor': {'username': 'bob', 'photo_url': null},
      'type': 'like',
      'created_at': '2026-09-24T10:00:00Z',
    });
    expect(n.actorUsername, 'bob');
    expect(n.personId, isNull);
  });

  test('a follow row', () {
    final f = PersonFollow.fromRow({
      'person_id': 500,
      'person_name': 'Florence Pugh',
      'profile_path': null,
      'created_at': '2026-09-24T10:00:00Z',
    });
    expect(f.personId, 500);
    expect(f.profileUrl, isEmpty);
  });
}
