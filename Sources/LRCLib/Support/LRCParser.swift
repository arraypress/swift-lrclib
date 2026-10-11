//
//  LRCParser.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//
//  LRC as files in the wild write it, not only as LRCLIB serves it. LRCLIB
//  normalises its own to `[mm:ss.xx] text`, but a caller may hand this any .lrc:
//  one to three fraction digits or none, `[mm:ss:xx]`, several stamps on one
//  line (a chorus written once), ID tags, an `[offset:]`, enhanced word stamps
//  (`<mm:ss.xx>`), section labels with no time, a BOM, and any line ending —
//  CRLF is one Character in Swift, so lines are split by SubtitleKit's `Lines`,
//  which normalises every ending first.
//

import Foundation
import SubtitleKit

/// Parses LRC text.
enum LRCParser {

    /// The document in `text`. Lines with no time stamp (`[Chorus]`, prose) are
    /// dropped; a stamp with no words is kept as a gap.
    static func parse(_ text: String) -> LRCDocument {
        var stamped: [(time: TimeInterval, order: Int, text: String)] = []
        var tags: [String: String] = [:]
        var order = 0
        for rawLine in Lines.of(text) {
            var rest = Substring(rawLine.replacingOccurrences(of: "\u{FEFF}", with: ""))
                .drop { $0 == " " || $0 == "\t" }
            var times: [TimeInterval] = []
            while rest.first == "[", let close = rest.firstIndex(of: "]") {
                let tag = rest[rest.index(after: rest.startIndex)..<close]
                if let seconds = timeStamp(tag) {
                    times.append(seconds)
                } else if let (key, value) = idTag(tag) {
                    tags[key] = value
                } else {
                    break   // "[Chorus]"-style text, not a tag
                }
                rest = rest[rest.index(after: close)...]
            }
            guard !times.isEmpty else { continue }
            let words = cleaned(String(rest))
            for time in times {
                stamped.append((time, order, words))
                order += 1
            }
        }
        let offset = tags["offset"].flatMap { Double($0.replacingOccurrences(of: "+", with: "")) }.map { $0 / 1_000 } ?? 0
        let lines = stamped
            .sorted { ($0.time, $0.order) < ($1.time, $1.order) }
            .map { TimedLine(time: max(0, $0.time - offset), text: $0.text) }
        return LRCDocument(lines: lines, tags: tags, offset: offset)
    }

    /// `mm:ss`, `mm:ss.x`, `mm:ss.xx`, `mm:ss.xxx` or `mm:ss:xx` as seconds.
    /// Minutes may run past 59; seconds may not.
    static func timeStamp(_ tag: Substring) -> TimeInterval? {
        let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3, let minutes = Int(parts[0]), minutes >= 0 else { return nil }
        var secondsText = parts[1], fraction: Substring = ""
        if parts.count == 3 {
            fraction = parts[2]
        } else if let dot = secondsText.firstIndex(of: ".") {
            fraction = secondsText[secondsText.index(after: dot)...]
            secondsText = secondsText[..<dot]
        }
        guard (1...2).contains(secondsText.count), secondsText.allSatisfy(\.isASCII), let seconds = Int(secondsText),
              seconds < 60, fraction.count <= 3, fraction.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        let fractional = fraction.isEmpty ? 0 : Double(Int(fraction)!) / pow(10, Double(fraction.count))
        return Double(minutes * 60 + seconds) + fractional
    }

    /// An ID tag — `ar:Queen` — as a lower-cased key and a trimmed value.
    static func idTag(_ tag: Substring) -> (String, String)? {
        guard let colon = tag.firstIndex(of: ":") else { return nil }
        let key = tag[..<colon]
        guard !key.isEmpty, key.count <= 10, key.allSatisfy({ $0.isASCII && ($0.isLetter || $0 == "#") }) else { return nil }
        return (key.lowercased(), tag[tag.index(after: colon)...].trimmingCharacters(in: .whitespaces))
    }

    /// The words of a line: enhanced word stamps removed, spaces tidied.
    static func cleaned(_ text: String) -> String {
        text.replacingOccurrences(of: "<\\d+:\\d{1,2}(?:[.:]\\d{1,3})?>", with: "", options: .regularExpression)
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .joined(separator: " ")
    }
}
