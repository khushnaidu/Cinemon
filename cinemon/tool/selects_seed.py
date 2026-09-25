"""Builds supabase/seeds/selects.sql: 35mm Selects, with each film's
poster, backdrop and year looked up on TMDB now, so the seed is plain SQL.

    python3 tool/selects_seed.py

Edit SELECTS below, run it again, and paste the output into the Supabase
SQL editor. It needs the official account to exist with username 35mm.
Re-running replaces each Select's films; saves are kept.
"""
import json, os, sys, urllib.parse, urllib.request, uuid

KEY = '9b0096cbe7fa89cf7eabcba8c5ba5a91'  # The app's own TMDB key.
OUT = os.path.join(os.path.dirname(__file__), '..', 'supabase', 'seeds', 'selects.sql')

# (title, year) per film; cover = the film whose still is the cover.
SELECTS = [
    dict(
        title='Hong Kong, After Midnight',
        tagline='Neon, rain and heartbreak. Twelve films from the city that never sleeps.',
        description='Wong Kar-wai’s lonely hearts, John Woo’s gunfights and the cops and triads of the 2000s. Start with Chungking Express; stay for everything after.',
        moods=['late_night', 'neon'],
        cover=('Chungking Express', 1994),
        films=[('Chungking Express', 1994), ('Fallen Angels', 1995), ('In the Mood for Love', 2000),
               ('Days of Being Wild', 1990), ('Happy Together', 1997), ('2046', 2004),
               ('A Better Tomorrow', 1986), ('Hard Boiled', 1992), ('Infernal Affairs', 2002),
               ('Comrades: Almost a Love Story', 1996), ('Rouge', 1987), ('Election', 2005)],
    ),
    dict(
        title='The Best of British Cinema',
        tagline='From Powell and Pressburger to Jonathan Glazer: the island’s cinema at its best.',
        description='Not a canon, a conversation. Wartime longing, post-war paranoia, kitchen-sink rage and a Glasgow flat in 1996. Watch them in order if you can.',
        moods=['rainy_day'],
        cover=('The Third Man', 1949),
        films=[('Brief Encounter', 1945), ('A Matter of Life and Death', 1946), ('The Red Shoes', 1948),
               ('The Third Man', 1949), ('Kind Hearts and Coronets', 1949), ('The Ladykillers', 1955),
               ('Lawrence of Arabia', 1962), ('Kes', 1969), ("Don't Look Now", 1973),
               ('The Long Good Friday', 1980), ('Withnail & I', 1987), ('Secrets & Lies', 1996),
               ('Trainspotting', 1996), ('Sexy Beast', 2000), ('Under the Skin', 2013)],
    ),
    dict(
        title='Old Bollywood',
        tagline='Songs, stars and heartbreak, 1951–1975.',
        description='Raj Kapoor’s tramps, Guru Dutt’s poets, Madhubala’s Anarkali and the angry young man. The golden age, in fourteen films.',
        moods=['heartbreaking', 'epic'],
        cover=('Sholay', 1975),
        films=[('Awaara', 1951), ('Shree 420', 1955), ('Pyaasa', 1957), ('Mother India', 1957),
               ('Madhumati', 1958), ('Kaagaz Ke Phool', 1959), ('Mughal-E-Azam', 1960), ('Guide', 1965),
               ('Teesri Manzil', 1966), ('Aradhana', 1969), ('Anand', 1971), ('Pakeezah', 1972),
               ('Deewaar', 1975), ('Sholay', 1975)],
    ),
    dict(
        title='Slow-Burn Thrillers',
        tagline='Patience, rewarded.',
        description='Films that take their time and then take the floor out from under you. Best watched late, with your phone in another room.',
        moods=['slow_burn', 'unsettling'],
        cover=('Zodiac', 2007),
        films=[('The Conversation', 1974), ('Blow Out', 1981), ('The Vanishing', 1988), ('Cure', 1997),
               ('Memories of Murder', 2003), ('Caché', 2005), ('Zodiac', 2007),
               ('Tinker Tailor Soldier Spy', 2011), ('Prisoners', 2013), ('Enemy', 2013),
               ('Burning', 2018)],
    ),
    dict(
        title='The Canon, Briefly',
        tagline='Twelve films critics keep coming back to. A place to start, not an exam.',
        description='If you have never watched an old film on purpose, start here. Each one is here because it is still thrilling, not because it is homework.',
        moods=['epic'],
        cover=('2001: A Space Odyssey', 1968),
        films=[('Bicycle Thieves', 1948), ('Tokyo Story', 1953), ('Seven Samurai', 1954), ('Vertigo', 1958),
               ('Citizen Kane', 1941), ("Singin' in the Rain", 1952), ('8½', 1963), ('Persona', 1966),
               ('2001: A Space Odyssey', 1968), ('The Godfather', 1972), ('Mulholland Drive', 2001),
               ('In the Mood for Love', 2000)],
    ),
    dict(
        title='Tokyo, Quietly',
        tagline='Small rooms, long takes, whole lives.',
        description='Ozu’s families, Kore-eda’s found ones, and a toilet cleaner who loves trees. Japanese films for when you want to feel everything, slowly.',
        moods=['tender'],
        cover=('Perfect Days', 2023),
        films=[('Late Spring', 1949), ('Tokyo Story', 1953), ('Ikiru', 1952), ('Floating Weeds', 1959),
               ('Tampopo', 1985), ('Maborosi', 1995), ('After Life', 1998), ('Still Walking', 2008),
               ('Shoplifters', 2018), ('Drive My Car', 2021), ('Perfect Days', 2023)],
    ),
]

def tmdb(title, year):
    """The film with this title and year: exact title first, then any title
    from that year (give or take one, for festival vs. release dates)."""
    def search(**kw):
        q = urllib.parse.urlencode({'api_key': KEY, 'query': title, **kw})
        return json.load(urllib.request.urlopen('https://api.themoviedb.org/3/search/movie?' + q))['results']
    def yr(m):
        return int((m.get('release_date') or '0')[:4] or 0)
    results = search(year=year) + search()
    same = lambda a, b: a.casefold().replace(':', ',') == b.casefold().replace(':', ',')
    for ok in (lambda m: same(m['title'], title) and abs(yr(m) - year) <= 1,
               lambda m: same(m.get('original_title', ''), title) and abs(yr(m) - year) <= 1,
               lambda m: abs(yr(m) - year) <= 1):
        for m in results:
            if ok(m):
                return m
    sys.exit(f'Not found on TMDB: {title} ({year})')

def lit(v):
    return 'null' if v is None else "'" + str(v).replace("'", "''") + "'"

out = ['-- 35mm Selects, generated by tool/selects_seed.py. Do not edit by hand.',
       '-- Needs the official account (username 35mm). Safe to re-run.',
       'do $$ begin',
       "  if not exists (select 1 from public.profiles where username = '35mm') then",
       "    raise exception 'Create the official account and rename it to 35mm first.';",
       '  end if;',
       'end $$;', '']
report = []
for rank, s in enumerate(SELECTS, 1):
    lid = uuid.uuid5(uuid.NAMESPACE_URL, 'https://35mm.contact/selects/' + s['title'])
    cover = tmdb(*s['cover'])
    out.append(f"-- {rank}. {s['title']}")
    out.append(
        'insert into public.lists (id, user_id, kind, title, description, visibility, '
        'is_select, select_rank, tagline, cover_style, cover_path, moods)\n'
        f"select {lit(lid)}, id, 'playlist', {lit(s['title'])}, {lit(s['description'])}, 'public', "
        f"true, {rank}, {lit(s['tagline'])}, 'film', {lit(cover.get('backdrop_path'))}, "
        f"array[{', '.join(lit(m) for m in s['moods'])}]\n"
        "  from public.profiles where username = '35mm'\n"
        'on conflict (id) do update set title = excluded.title, description = excluded.description, '
        'is_select = true, select_rank = excluded.select_rank, tagline = excluded.tagline, '
        'cover_style = excluded.cover_style, cover_path = excluded.cover_path, moods = excluded.moods;')
    out.append(f'delete from public.list_items where list_id = {lit(lid)};')
    rows = []
    for pos, (t, y) in enumerate(s['films'], 1):
        m = tmdb(t, y)
        got_year = (m.get('release_date') or '')[:4]
        report.append(f"{s['title'][:22]:22} | {t[:30]:30} {y} -> {m['title'][:34]:34} {got_year}")
        rows.append(f"  ({lit(lid)}, {m['id']}, 'movie', {lit(m['title'])}, {lit(m.get('poster_path'))}, "
                    f"{lit(m.get('backdrop_path'))}, {lit(got_year or None)}, {pos})")
    out.append('insert into public.list_items (list_id, film_id, media_type, film_title, '
               'film_poster_path, film_backdrop_path, film_year, position) values\n'
               + ',\n'.join(rows) + ';')
    out.append('')

os.makedirs(os.path.dirname(OUT), exist_ok=True)
open(OUT, 'w').write('\n'.join(out))
print('\n'.join(report))
print('wrote', os.path.normpath(OUT))
