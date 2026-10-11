//
//  Lyrics.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One track's lyrics as LRCLIB holds them.
///
/// Either text may be missing: an instrumental has neither, and many tracks
/// carry plain lyrics without timings. Parsed timings, captions and LRC text are
/// in `Extensions/Lyrics+Timing.swift`.
public struct Lyrics: Sendable, Hashable, Identifiable, Codable {

    /// LRCLIB's record ID — stable, and the cheapest way to fetch it again.
    public let id: Int

    /// The track's title.
    public let track: String

    /// The artist, as the record names them.
    public let artist: String

    /// The album, when the record names one.
    public let album: String?

    /// The track's length in seconds, when known.
    public let duration: TimeInterval?

    /// Whether the record marks the track as instrumental — no words at all.
    public let isInstrumental: Bool

    /// Whether the synced lyrics carry word-level timings as well as lines.
    public let hasWordSync: Bool

    /// The lyrics as plain text, one line per line.
    public let plain: String?

    /// The lyrics as LRC: `[mm:ss.xx] line`, one timed line per line.
    public let synced: String?

    /// Lyrics.
    public init(id: Int, track: String, artist: String, album: String?, duration: TimeInterval?,
                isInstrumental: Bool, hasWordSync: Bool, plain: String?, synced: String?) {
        self.id = id
        self.track = track
        self.artist = artist
        self.album = album
        self.duration = duration
        self.isInstrumental = isInstrumental
        self.hasWordSync = hasWordSync
        self.plain = plain
        self.synced = synced
    }
}
