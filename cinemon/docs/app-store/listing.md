# App Store submission kit: 35mm 1.1.1

Everything to paste into App Store Connect for the first review. Limits are
Apple's; counts are checked. Nothing here names Letterboxd, TMDB or any other
service as a comparison or keyword (App Review 2.3.7, 5.2.1).

## App information

| Field | Value |
|---|---|
| Name (30) | 35mm: Social Cinema |
| Subtitle (30) | Log films. Share your takes. |
| Primary category | Entertainment |
| Secondary category | Social Networking |
| Age rating | 13+ (answered 2026-09-25) |
| Content rights | Contains third-party content; has the rights |
| Privacy Policy URL | https://35mm.contact/privacy |
| Support URL | https://35mm.contact/support |
| Marketing URL | https://35mm.contact |
| Copyright | 2026 Raunaq Naidu (the account holder until the transfer; then Khush Naidu) |

## Promotional text (170)

Can be changed any time without a review.

> Log what you watch, keep every film you've ever seen in one place, and trade hot takes with friends. Trailers, playlists and share cards included.

## Description (4000)

> 35mm is a film diary for people who love movies and shows, and love talking about them.
>
> LOG WHAT YOU WATCH
> Rate a film or show, write a review, add photos or a short voice note. Log single episodes as you binge. Everything you log lands in your Films library, and you can add everything you watched before 35mm too, without posting a thing.
>
> SEE WHAT YOUR PEOPLE THINK
> Home is the people you follow: their reviews, one card at a time. Like, react with a sticker, or start a conversation in the comments. Friends who follow each other show up as Friends.
>
> EXPLORE HOT TAKES
> Post a thought, a hot take, a critique or a playlist to Explore, where everyone on 35mm can agree, disagree and reply. Sort by latest or top, or dive into everything said about one film.
>
> DISCOVER WHAT TO WATCH NEXT
> Swipe through trailers for what's trending and new, films or shows, and narrow it to a genre when you're in the mood for one. Turn it sideways for full screen, and save anything that catches your eye to your watchlist.
>
> YOUR WATCHLIST AND PLAYLISTS
> Save what you want to watch, and strike it off when you do. Make playlists for every mood, share them, and save other people's.
>
> KNOW WHERE TO WATCH
> Every film and show tells you where it's streaming, when it's in theaters, and who's in it.
>
> MAKE IT YOURS
> Your Top 3, favourite actors and directors, badges to earn, and a month-in-film recap. Share any review, your profile or your Top 3 as a card to your Instagram story or in a message.
>
> PRIVATE WHEN YOU WANT IT
> Keep your account public or make it private and approve who follows you. Report anything with a tap and block anyone. We review every report within 24 hours.
>
> 35mm uses the TMDB API but is not endorsed or certified by TMDB. Streaming availability by JustWatch.

## Keywords (100)

> film,movie,diary,log,review,watchlist,binge,tv,shows,trailers,ratings,friends,playlist,critic

(93 characters. Don't repeat words already in the name or subtitle; Apple indexes those separately.)

## What's New (for this version)

> The first release of 35mm. Log films and shows, follow friends, post hot takes, swipe trailers, and keep your whole film history in one place.

## App Review Information

**Sign-in:** demo account, to be created before submitting (see "Demo account" below).

**Notes (paste into "Notes"):**

> 35mm is a social film diary. People log films and shows (ratings, reviews, optional photos and 10-second voice notes), follow each other, and post to a public "Explore" feed.
>
> User-generated content safeguards (Guideline 1.2):
> - Terms of Use with zero tolerance for objectionable content are accepted with an explicit checkbox at sign-up, with a date of birth; under-13s cannot create an account.
> - Every review, comment, Explore post and reply, playlist and profile has a ••• menu with Report and Block. Reported content is hidden from the reporter at once; blocking hides both accounts from each other everywhere and ends follows.
> - Text is filtered on the server for slurs, sexual content involving minors, sexual violence and encouragement of self-harm before it is saved. Photos are checked automatically by a moderation model before they appear; refused photos are deleted.
> - Reports go to a moderation queue that we review within 24 hours; we remove content and suspend accounts.
> - Contact: support@35mm.contact, also linked in the app under Settings → Help.
>
> Account deletion (5.1.1(v)): Profile → gear → Delete account. It deletes everything immediately, and revokes Sign in with Apple.
>
> Age: users give a date of birth at sign-up; where required by law we also read the Declared Age Range. Accounts of under-18s start private.
>
> Trailers play in YouTube's own embedded player. Film data and artwork come from TMDB under its API terms; attribution is in Settings → About.
>
> The demo account follows a second account so Home, Explore and notifications have content.

## Demo account (later)

Before submitting: create `appreview@35mm.contact` (or any inbox you can read) with a password, then with it:
1. Log 4–5 films (a couple with reviews, one with a photo).
2. Add a few titles to the watchlist and the Films library.
3. Make one playlist.
4. Follow your main account (and have your main account follow it back, so it shows Friends).
5. Post one Explore take.
Put the email and password in App Review Information → Sign-in required.

## Screenshots

Required: **6.9-inch iPhone**, 1320 × 2868 portrait, 3 to 10 images. Apple scales these down for smaller iPhones.

Take them on the iPhone (side button + volume up) from an account with real-looking content, AirDrop them to `~/Cinémon/app-store-screens/raw/`, named `01.png` … `08.png` in the order below, then run:

```
python3 cinemon/tool/app_store_screenshots.py ~/Cinémon/app-store-screens/raw ~/Cinémon/app-store-screens/out
```

| # | Screen to capture | Caption |
|---|---|---|
| 01 | Home, a friend's review card (front) | Your friends' reviews, one card at a time |
| 02 | A film page (poster, where to watch, friends' reviews) | Everything about a film, and where to watch it |
| 03 | Posting a review (stars, text, a photo) | Log it. Rate it. Say what you really think. |
| 04 | Explore, a hot take with agree/disagree | Hot takes. Agree or disagree. |
| 05 | Discover, a genre chosen | Find tonight's film, one trailer at a time |
| 06 | Profile (header, Top 3, tabs) | Your Top 3, your films, your badges |
| 07 | Films tab (library grid) | Every film you've ever seen, in one place |
| 08 | A share card in the share sheet | Share any review to your story |

Tips: hide the status bar clutter (full battery, good signal, a tidy time like 9:41 if you can); use films with striking posters; avoid other people's real names or photos unless they've agreed.
