# Swift LRCLib

Song lyrics from [LRCLIB](https://lrclib.net) — plain and time-stamped, keyless — plus an LRC parser and SRT/WebVTT export, on any Apple platform.

```swift
import LRCLib

let client = LRCLib()
if let song = try await client.lyrics(artist: "Queen", track: "Bohemian Rhapsody", duration: 355) {
    print(song.text ?? "instrumental")        // the words
    for line in song.timedLines { print(line.time, line.text) }
    let srt = song.captions(.srt)              // SubtitleKit does the writing
}
let hits = try await client.search("bohemian rhapsody")   // at most 20
let file = LRCDocument(parsing: try String(contentsOfFile: "song.lrc"))
```

## Features

- 🎤 **Three lookups** — by artist + track (album and duration optional), by LRCLIB record ID, and search (free text or by field)
- 🫥 **A miss is `nil`, not an error** — a 404 `TrackNotFound` returns `nil`; an instrumental is a record with `isInstrumental` and no text; a plain-only record has `synced == nil`
- 🕰️ **An LRC parser for files in the wild** — `[mm:ss]` with 0–3 fraction digits and `[mm:ss:xx]`, several stamps on one line, ID tags (`[ar:]`, `[ti:]`…), `[offset:]`, enhanced `<mm:ss.xx>` word stamps (removed), section labels with no time (skipped), a BOM, and LF, CRLF, CR or U+2028 line endings. CRLF is one `Character` in Swift, so splitting on `"\n"` finds nothing — lines go through SubtitleKit's `Lines`
- 🎬 **SRT and WebVTT** — each line lasts until the next stamp; an empty stamp (how LRC marks an instrumental break) ends a cue rather than making one; lines sharing a stamp become one two-line cue; the last line holds five seconds or to the track's end. Rendered by [swift-subtitle-kit](https://github.com/arraypress/swift-subtitle-kit)
- 🚦 **Throttling handled** — 503 and 429 retried twice with `Retry-After`, then a typed `rateLimited`
- 🧵 **Swift 6.2 concurrency** — every call `throws(LRCLibError)`, so a `catch` gets the library's error without a cast: offline is `.network`, a cancelled task is `.cancelled` (Swift's or URLSession's). Async calls run on the caller's executor (nonisolated-nonsending by default) and every type is `Sendable`
- 🪪 **Polite by default** — a User-Agent naming the library and its source, as LRCLIB asks
- 🧪 **Offline suite** — the parser, writer and caption timing on fixtures, the client on an injected transport (decoding, misses, retries, URL encoding of `&`, `+` and CJK); three live tests that skip when the service refuses

## Measured (live, 2026-10-11)

| Case | Result |
|---|---|
| Hit with synced lyrics (Queen, *Bohemian Rhapsody*, 355 s) | record 19079, 56 timed lines, 6 of them empty breaks; ~0.8 s |
| Miss | 404 `TrackNotFound` → `nil` |
| Instrumental (Vangelis, *Chariots of Fire*) | `instrumental: true`, no plain, no synced |
| Plain only (YOASOBI, 夜に駆ける; Fairuz, *Kifak Inta*) | plain text, `syncedLyrics: null` |
| Japanese and Arabic script, `&` (Simon & Garfunkel), `/` (AC/DC) | all found; matching ignores case and extra spaces |
| Duration | matches within ±2 s (asked 1236 → 1234, 1248 → 1246.075, 1200 → miss); without one, a record is still found |
| Album | a filter: a wrong album turns a hit into a miss |
| Search | 20 results at most, no paging |
| Very long (Arlo Guthrie, *Alice's Restaurant*, 1,117 s) | 13,076 characters of plain text |
| Load | 503 `ServerOverloaded` with `Retry-After: 1`, not 429: 5 of 30 searches sent 15 at a time; 0 of 40 cached record reads sent 20 at a time; 0 of 60 sequential reads |
| Parser | 5,000 lines in under 0.1 s |

## Requirements

macOS 14+ / iOS 16+ / tvOS 16+ / watchOS 9+ / visionOS 1+, Swift 6.2 (Xcode 26). Depends on [swift-subtitle-kit](https://github.com/arraypress/swift-subtitle-kit).

Lyrics are the rights holders'; LRCLIB is a community database. Check the terms that apply to how you use them.

## License

MIT — see LICENSE.
