//
//  LRCDocument.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// An LRC file, parsed: its timed lines in time order and its ID tags.
public struct LRCDocument: Sendable, Hashable {

    /// The lines, earliest first, with any `[offset:]` already applied.
    public let lines: [TimedLine]

    /// ID tags — `ar`, `ti`, `al`, `by`, `length`… — lower-cased keys.
    public let tags: [String: String]

    /// The `[offset:]` tag in seconds (positive shows lyrics sooner); 0 when absent.
    public let offset: TimeInterval

    /// A document.
    public init(lines: [TimedLine], tags: [String: String], offset: TimeInterval) {
        self.lines = lines
        self.tags = tags
        self.offset = offset
    }
}
