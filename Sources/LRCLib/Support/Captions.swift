//
//  Captions.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//
//  Timed lines to subtitle cues. LRC gives each line a start and nothing else,
//  so a line lasts until the next stamp — including a gap stamp, which is how a
//  file marks an instrumental break and why gaps end a cue rather than become
//  one. Lines that share a stamp are sung together and share one cue.
//

import Foundation
import SubtitleKit

/// Turns timed lyrics into subtitle cues.
enum Captions {

    /// How long the last line stays up when nothing follows it, in seconds.
    static let lastLineHold: TimeInterval = 5

    /// Cues for `lines`. The last cue ends `lastLineHold` after it starts, or at
    /// the track's end if that comes sooner.
    static func cues(from lines: [TimedLine], trackDuration: TimeInterval?) -> [SubtitleCue] {
        // Group by start: a stamp shared by two lines is one cue of two lines.
        var groups: [(time: TimeInterval, texts: [String])] = []
        for line in lines.sorted(by: { $0.time < $1.time }) {
            if let last = groups.last, abs(last.time - line.time) < 0.0005 {
                groups[groups.count - 1].texts.append(line.text)
            } else {
                groups.append((line.time, [line.text]))
            }
        }
        var cues: [SubtitleCue] = []
        for (index, group) in groups.enumerated() {
            let words = group.texts.filter { !$0.isEmpty }
            guard !words.isEmpty else { continue }   // a gap
            let end: TimeInterval
            if index + 1 < groups.count {
                end = groups[index + 1].time
            } else {
                let held = group.time + lastLineHold
                end = trackDuration.map { $0 > group.time ? min($0, held) : held } ?? held
            }
            cues.append(SubtitleCue(start: group.time, end: end, text: words.joined(separator: "\n")))
        }
        return cues
    }
}
