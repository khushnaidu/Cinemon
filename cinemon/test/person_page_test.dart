import 'package:cinemon/models/person_page.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> credit(int id, String type, {String? character, String? job, String? department, String? date, int votes = 0, List<int> genres = const [], String? poster = '/p.jpg', int? episodes}) => {
      'id': id,
      'media_type': type,
      if (type == 'movie') 'title': 'Film $id' else 'name': 'Show $id',
      if (type == 'movie') 'release_date': date ?? '' else 'first_air_date': date ?? '',
      if (character != null) 'character': character,
      if (job != null) 'job': job,
      if (department != null) 'department': department,
      'vote_count': votes,
      'genre_ids': genres,
      'poster_path': poster,
      if (episodes != null) 'episode_count': episodes,
    };

void main() {
  final page = PersonPage.fromTmdb({
    'id': 525,
    'name': 'Director Person',
    'known_for_department': 'Directing',
    'birthday': '1970-07-30',
    'place_of_birth': '',
    'combined_credits': {
      'cast': [
        credit(1, 'movie', character: 'Cameo', date: '2010-01-01', votes: 50),
        credit(900, 'tv', character: 'Self', date: '1990-01-01', votes: 99999, genres: [10767], episodes: 3),
        credit(901, 'tv', character: 'Himself', date: '2000-01-01', votes: 88888),
      ],
      'crew': [
        credit(2, 'movie', job: 'Director', department: 'Directing', date: '2014-11-05', votes: 5000),
        credit(2, 'movie', job: 'Screenplay', department: 'Writing', date: '2014-11-05', votes: 5000),
        credit(2, 'movie', job: 'Producer', department: 'Production', date: '2014-11-05', votes: 5000),
        credit(3, 'movie', job: 'Director', department: 'Directing', date: '2010-07-16', votes: 9000),
        credit(3, 'movie', job: 'Writer', department: 'Writing', date: '2010-07-16', votes: 9000),
        credit(3, 'movie', job: 'Story', department: 'Writing', date: '2010-07-16', votes: 9000),
        credit(4, 'movie', job: 'Director', department: 'Directing', date: '2099-01-01', votes: 10),
        credit(5, 'movie', job: 'Director', department: 'Directing', votes: 0),
        credit(6, 'movie', job: 'Sound', department: 'Sound', date: '2001-01-01'),
      ],
    },
  });

  test('blank place of birth becomes null', () {
    expect(page.placeOfBirth, isNull);
    expect(page.birthday, DateTime(1970, 7, 30));
  });

  test('jobs on one title merge within a department', () {
    final writing = page.credits.where((c) => c.department == 'Writing' && c.filmId == 3);
    expect(writing.single.roleLabel, 'Writer, Story');
  });

  test('tabs: only the four departments that have credits, known-for first by default', () {
    expect(page.availableDepartments, ['Acting', 'Directing', 'Writing', 'Production']);
    expect(page.defaultDepartment, 'Directing');
  });

  test('known for skips talk shows and playing themselves, one per title', () {
    expect(page.knownFor.map((c) => c.filmId), [3, 2, 1]);
  });

  test('filmography: undated and future first, then years newest first', () {
    final f = page.filmography('Directing', now: DateTime(2026, 9, 23));
    expect(f.upcoming.map((c) => c.filmId), [4, 5]);
    expect(f.years.map((y) => y.year), [2014, 2010]);
  });

  test('titles cover every credit once', () {
    expect(page.titles.length, 8);
  });
}
