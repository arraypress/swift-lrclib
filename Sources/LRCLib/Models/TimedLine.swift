//
//  TimedLine.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One line of synced lyrics and when it starts.
public struct TimedLine: Sendable, Hashable, Codable {

    /// Seconds from the start of the track.
    public let time: TimeInterval

    /// The words; empty for a timed gap — an instrumental break.
    public let text: String

    /// A timed line.
    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}
