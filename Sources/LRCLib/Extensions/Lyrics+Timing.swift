//
//  Lyrics+Timing.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation
import SubtitleKit

public extension Lyrics {

    /// `true` when the record carries time-stamped lyrics with words in them.
    var hasSyncedLyrics: Bool {
        document?.hasWords ?? false
    }

    /// The synced lyrics, parsed; `nil` when the record has none.
    var document: LRCDocument? {
        synced.map(LRCDocument.init(parsing:))
    }

    /// The synced lyrics as timed lines, earliest first; empty when there are none.
    var timedLines: [TimedLine] {
        document?.lines ?? []
    }

    /// The words without times: the plain lyrics, or — when a record has only
    /// synced ones — their lines with the stamps removed. `nil` for an
    /// instrumental or a record with no text.
    var text: String? {
        if let plain { return plain }
        guard let document, document.hasWords else { return nil }
        return document.lines.map(\.text).joined(separator: "\n")
    }

    /// The synced lyrics as an SRT or WebVTT file, the last line ending with the
    /// track; `nil` when there are no synced lyrics.
    func captions(_ format: SubtitleFormat) -> String? {
        document?.captions(format, trackDuration: duration)
    }
}
