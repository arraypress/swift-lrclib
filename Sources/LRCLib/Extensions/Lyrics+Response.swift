//
//  Lyrics+Response.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation

extension Lyrics {

    /// Lyrics from a record. Blank texts become `nil`, so "has lyrics" is
    /// simply "is not nil"; an album named "" or "null" is no album.
    init(response: LyricsResponse) {
        func text(_ value: String?) -> String? {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        let album = response.albumName.flatMap { $0.isEmpty || $0.lowercased() == "null" ? nil : $0 }
        self.init(id: response.id, track: response.trackName ?? response.name ?? "", artist: response.artistName,
                  album: album, duration: response.duration.flatMap { $0 > 0 ? $0 : nil },
                  isInstrumental: response.instrumental ?? false, hasWordSync: response.hasWordSync ?? false,
                  plain: text(response.plainLyrics), synced: text(response.syncedLyrics))
    }
}
