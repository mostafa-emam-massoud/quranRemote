# Quran Remote

A Qur'an reader for iPhone and iPad that you can **scroll from your Apple
Watch** — so the mushaf can sit propped in front of you while you pray, and a
tap on your wrist turns the page.

- **iPhone + iPad** — one universal app. A landscape iPad shows two pages side
  by side, like an open mushaf.
- **Apple Watch remote** — big Next/Back buttons, Digital Crown page turning,
  a haptic on every page turn, and a prayer mode that keeps the remote on
  screen instead of dropping back to the watch face between rak'ahs.
- **Works offline** — pages are cached as you read, and one tap downloads all
  604 pages so a weak signal in the masjid cannot interrupt you.
- **Built for praying** — the screen stays awake, controls fade away, and there
  is a dim "night" theme for a dark room.

## Getting it running

Requirements: Xcode 16 or newer, iOS 17+, watchOS 10+.

1. `open QuranRemote.xcodeproj`
2. Select the **QuranRemote** scheme and your iPhone, then set your own team
   under Signing & Capabilities for both targets (the bundle IDs are
   `com.quranremote.app` and `com.quranremote.app.watchkitapp` — change the
   prefix to something you own).
3. Run it on the phone. Then install the watch app from the Watch app on your
   iPhone (Available Apps → Quran Remote), or run the **QuranRemote Watch App**
   scheme straight onto the watch.
4. On the phone, open Settings → Offline and tap **Download the whole mushaf**
   once. After that the app needs no network at all.

The Qur'an text is fetched from public APIs
([alquran.cloud](https://alquran.cloud), falling back to
[quran.com](https://quran.com)) in Uthmani script and cached on the device. No
account, no key, no analytics, nothing leaves the device except those requests.

### Using it in prayer

1. Prop the phone or iPad where you can see it and open the page you are
   starting from.
2. On the watch, open Quran Remote and tap the **hands** button to start prayer
   mode — the remote will now stay on screen.
3. Tap **Next** to turn the page, or turn the crown. Both work without looking:
   every move plays a haptic, and a double buzz means you are at the first or
   last page.

### Reading from the iPad

An Apple Watch pairs only with an iPhone, never with an iPad. Quran Remote
bridges the gap: turn on **Settings → Reading on the iPad → Link nearby iPhone
and iPad** on *both* devices, keep them on the same Wi-Fi, and leave the iPhone
app open. The watch's page turns then travel watch → iPhone → iPad, and both
screens stay on the same page.

### A mushaf font

The reader ships without a Qur'an font and falls back to the system serif face,
which renders Uthmani text correctly. For a printed-mushaf look, drop a font
into `Fonts/` — see [Fonts/README.md](Fonts/README.md). Settings → About shows
which font is in use.

## How it is put together

```
QuranRemote/                iOS app (SwiftUI): the reader
QuranRemote Watch App/      watchOS app: the remote
Packages/QuranCore/         local Swift package, shared by both
  Sources/QuranCore/        mushaf metadata, navigation, text loading, caching
  Sources/QuranLink/        WatchConnectivity + Multipeer plumbing
  Tests/QuranCoreTests/     unit tests for all of the above
Config/                     Info.plists for both targets
```

The pieces worth knowing about:

- **`ReaderNavigator`** (QuranCore) is the single source of truth for movement.
  A swipe, the page slider, the surah list, a crown turn and a watch button all
  produce the same `RemoteCommand`, and the navigator applies it. That is why
  the watch and the phone can never disagree about what "next page" means, and
  why the rules are testable without a device.
- **`RemoteMessage`** is the only thing that crosses between devices — a
  command going one way, a `ReaderStateSnapshot` (page, surah, juz', focused
  verse) coming back. It is sent live when the counterpart is reachable and
  queued when it is not, so a page turn is never silently dropped.
- **`PageStore`** is an actor that fetches a page once, keeps it in memory and
  writes it to the caches directory as JSON. "Download the whole mushaf" is the
  same path run over all 604 pages.
- **`MushafData`** holds the 114 surahs and 30 juz' with their start pages, so
  the watch can name where you are with no phone and no network.

### Tests

```sh
cd Packages/QuranCore && swift test
```

They cover the mushaf tables (114 surahs, 6236 verses, ordered start pages),
every navigation rule including the edges of the mushaf, message encoding and
decoding, both API parsers, basmalah handling, and the page cache and its
offline download.

There are no tests for the SwiftUI layer or for the WatchConnectivity and
Multipeer code — those need real devices, and the watch link in particular is
worth trying on a real watch before relying on it in prayer.

### Regenerating the project

`QuranRemote.xcodeproj` is checked in and is the source of truth. `project.yml`
is only a fallback: if the project file is ever damaged,
`brew install xcodegen && xcodegen generate` rebuilds an equivalent one.

## Notes and limitations

- The reader lays out verse by verse rather than reproducing the exact line
  breaks of a printed mushaf page — that needs per-line glyph data and a
  licensed mushaf font. Page *numbers* match the standard 604-page Madani
  mushaf, so "page 293" is the same page it is in your copy.
- Surah-per-page metadata offline is derived from surah start pages; once a
  page's text has loaded, the actual verses on it are used instead.
- The iPad link needs the iPhone app to be in the foreground — iOS will not let
  a backgrounded app relay over the local network indefinitely.
- Please report anything that looks wrong in the Qur'anic text itself. It comes
  from the APIs above, unmodified apart from moving the basmalah into the surah
  header where an edition includes it in the first verse.
