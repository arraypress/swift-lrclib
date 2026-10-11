//
//  LRCLibError.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong asking LRCLIB. A track that is not there is not an error:
/// lookups return `nil` and searches return nothing.
public enum LRCLibError: Error, LocalizedError, Sendable, Equatable {

    /// The request could not be made as asked — an empty title, a duration of zero.
    case invalidQuery(String)

    /// LRCLIB answered with an HTTP failure.
    case http(Int)

    /// LRCLIB is turning requests away — 429, or the 503s a burst draws.
    /// Retry after this many seconds when it said.
    case rateLimited(retryAfter: Int?)

    /// A response did not have the documented shape.
    case malformed(String)

    /// A lower-case phrase that reads inside a sentence.
    public var errorDescription: String? {
        switch self {
        case .invalidQuery(let why): return why
        case .http(let code): return "LRCLIB answered HTTP \(code)"
        case .rateLimited(let after):
            return "LRCLIB is turning requests away" + (after.map { " (retry after \($0)s)" } ?? "")
        case .malformed(let what): return "unexpected LRCLIB response: \(what)"
        }
    }
}
