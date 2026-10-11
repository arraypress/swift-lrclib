//
//  LRCWriter.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Writes LRC text.
enum LRCWriter {

    /// `[mm:ss.xx] text`, one line per timed line, in order; minutes past 99
    /// are written in full.
    static func render(_ lines: [TimedLine]) -> String {
        lines.map { "[\(stamp($0.time))] \($0.text)".trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
    }

    /// `mm:ss.xx`, rounded to the hundredth.
    static func stamp(_ seconds: TimeInterval) -> String {
        let hundredths = Int((max(0, seconds) * 100).rounded())
        return String(format: "%02d:%02d.%02d", hundredths / 6_000, (hundredths / 100) % 60, hundredths % 100)
    }
}
