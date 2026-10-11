//
//  LRCDocument+Parsing.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation
import SubtitleKit

public extension LRCDocument {

    /// Parses LRC text — LRCLIB's, or any `.lrc` file. Never fails: lines with
    /// no time stamp are skipped, so text that is not LRC parses to no lines.
    ///
    /// Handles `[mm:ss]` with zero to three fraction digits and `[mm:ss:xx]`,
    /// several stamps on one line, ID tags (`[ar:]`, `[ti:]`…), `[offset:]`,
    /// enhanced word stamps (`<mm:ss.xx>`, removed), a BOM, and LF, CRLF or CR
    /// line endings.
    init(parsing text: String) {
        self = LRCParser.parse(text)
    }

    /// `true` when there is at least one line with words.
    var hasWords: Bool {
        lines.contains { !$0.text.isEmpty }
    }

    /// The lines as LRC, `[mm:ss.xx] text`, with the offset already applied
    /// and no tags.
    var lrc: String {
        LRCWriter.render(lines)
    }

    /// The lines as subtitle cues: each line until the next stamp, gaps
    /// ending a cue rather than making one, the last held five seconds or to
    /// the track's end.
    func cues(trackDuration: TimeInterval? = nil) -> [SubtitleCue] {
        Captions.cues(from: lines, trackDuration: trackDuration)
    }

    /// The lines as an SRT or WebVTT file, or `nil` when none has words.
    func captions(_ format: SubtitleFormat, trackDuration: TimeInterval? = nil) -> String? {
        let cues = cues(trackDuration: trackDuration)
        guard !cues.isEmpty else { return nil }
        return SubtitleWriter.render(cues, format: format)
    }
}
