//
//  Validation.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Input checks, before any request. Each throws ``LRCLibError/invalidQuery(_:)``.
enum Validation {

    /// Text that must say something: not empty, not only spaces, at most 500 characters.
    static func required(_ value: String, _ what: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LRCLibError.invalidQuery("The \(what) cannot be empty") }
        guard trimmed.count <= 500 else { throw LRCLibError.invalidQuery("The \(what) is too long (max 500 characters)") }
        return trimmed
    }

    /// Optional text: nil when absent or blank, else trimmed.
    static func optional(_ value: String?, _ what: String) throws -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return try required(value, what)
    }

    /// A track length a song can have: more than 0 and under a day.
    static func duration(_ seconds: TimeInterval?) throws {
        guard let seconds else { return }
        guard seconds.isFinite, seconds > 0, seconds < 86_400 else {
            throw LRCLibError.invalidQuery("A duration must be more than 0 seconds and less than a day")
        }
    }

    /// A record ID: positive.
    static func id(_ id: Int) throws {
        guard id > 0 else { throw LRCLibError.invalidQuery("A record ID is a positive number") }
    }
}
