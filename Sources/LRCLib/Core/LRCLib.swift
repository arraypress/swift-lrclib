//
//  LRCLib.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//
//  LRCLIB (lrclib.net), keyless: song lyrics, plain and time-stamped, by
//  track and artist or by record ID, and search. Measured against the live API
//  on 2026-10-11:
//
//  - A miss is a 404 with `TrackNotFound`; here it is `nil`.
//  - `get` matches the duration within about two seconds either way, and
//    finds the track without one; the album is optional too.
//  - Search returns at most 20 records and has no paging.
//  - Load draws 503 `ServerOverloaded` with `Retry-After: 1`, not 429: 5 of
//    30 searches sent 15 at a time, none of 40 cached record reads sent 20 at
//    a time, none of 60 sequential reads. Both codes are retried twice before
//    ``LRCLibError/rateLimited(retryAfter:)``.
//  - The album, when given, must match: a wrong one is a miss.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A keyless client for LRCLIB.
///
/// ```swift
/// import LRCLib
///
/// let client = LRCLib()
/// if let song = try await client.lyrics(artist: "Queen", track: "Bohemian Rhapsody") {
///     print(song.plain ?? "instrumental")
///     print(song.captions(.srt) ?? "no synced lyrics")
/// }
/// let hits = try await client.search("bohemian rhapsody")
/// ```
public struct LRCLib: Sendable {

    /// How requests are performed — injectable so tests run on recordings.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    /// How a retry waits — injectable so rate-limit tests cost no wall-clock.
    public typealias Sleeper = @Sendable (_ seconds: Int) async throws -> Void

    /// The User-Agent sent when none is chosen. LRCLIB asks clients to name
    /// themselves and link to their source; override it to name your app.
    public static let defaultUserAgent = "swift-lrclib/0.2 (+https://github.com/arraypress/swift-lrclib)"

    /// The most records one search returns. LRCLIB caps it and does not page.
    public static let searchLimit = 20

    /// How far LRCLIB lets a duration miss and still match, in seconds — measured.
    public static let durationTolerance: TimeInterval = 2

    /// The User-Agent every request carries.
    public let userAgent: String

    private let transport: Transport
    private let sleeper: Sleeper

    /// A client.
    ///
    /// - Parameters:
    ///   - userAgent: Name your app and link to it.
    ///   - transport: Leave `nil` for the shared URLSession.
    ///   - sleeper: How a throttled retry waits; leave `nil` for real sleeping.
    public init(userAgent: String = LRCLib.defaultUserAgent, transport: Transport? = nil,
                sleeper: Sleeper? = nil) {
        self.userAgent = userAgent
        self.sleeper = sleeper ?? { seconds in
            try await Task.sleep(for: .seconds(max(seconds, 1)))
        }
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw LRCLibError.malformed("not an HTTP response")
            }
            return (data, http)
        }
    }

    // MARK: - Lookups

    /// The lyrics of one track, or `nil` when LRCLIB has none.
    ///
    /// - Parameters:
    ///   - artist: The artist, as credited.
    ///   - track: The track title.
    ///   - album: Narrows the match; optional.
    ///   - duration: The track's length in seconds; LRCLIB matches it within
    ///     about two seconds and picks the right edit when a song has several.
    ///   - cachedOnly: Ask only LRCLIB's own store, never its upstream sources —
    ///     faster, and misses more.
    /// - Throws: ``LRCLibError``, never for a miss.
    public func lyrics(artist: String, track: String, album: String? = nil,
                       duration: TimeInterval? = nil, cachedOnly: Bool = false) async throws(LRCLibError) -> Lyrics? {
        let artist = try Validation.required(artist, "artist")
        let track = try Validation.required(track, "track")
        let album = try Validation.optional(album, "album")
        try Validation.duration(duration)
        return try await record(Endpoints.get(artist: artist, track: track, album: album,
                                              duration: duration, cachedOnly: cachedOnly))
    }

    /// One record by its LRCLIB ID, or `nil` when there is no such record.
    public func lyrics(id: Int) async throws(LRCLibError) -> Lyrics? {
        try Validation.id(id)
        return try await record(Endpoints.get(id: id))
    }

    /// Records matching free text, by field, or both — at most
    /// ``searchLimit``, in LRCLIB's order. Needs `query` or `track`.
    ///
    /// - Throws: ``LRCLibError/invalidQuery(_:)`` when neither is given.
    public func search(_ query: String? = nil, track: String? = nil, artist: String? = nil,
                       album: String? = nil) async throws(LRCLibError) -> [Lyrics] {
        let query = try Validation.optional(query, "query")
        let track = try Validation.optional(track, "track")
        guard query != nil || track != nil else {
            throw LRCLibError.invalidQuery("Search needs words to look for, or a track title")
        }
        let url = Endpoints.search(query: query, track: track,
                                   artist: try Validation.optional(artist, "artist"),
                                   album: try Validation.optional(album, "album"))
        guard let data = try await perform(url) else { return [] }
        do {
            return try JSONDecoder().decode([LyricsResponse].self, from: data).map(Lyrics.init(response:))
        } catch {
            throw LRCLibError.malformed("search results: \(error.localizedDescription)")
        }
    }

    // MARK: - Plumbing

    /// One record from a `get` URL; `nil` on 404.
    func record(_ url: URL) async throws(LRCLibError) -> Lyrics? {
        guard let data = try await perform(url) else { return nil }
        do {
            return Lyrics(response: try JSONDecoder().decode(LyricsResponse.self, from: data))
        } catch {
            throw LRCLibError.malformed("lyrics record: \(error.localizedDescription)")
        }
    }

    /// A GET with the User-Agent: the body, `nil` on 404, and a 429 or 503
    /// retried twice — after the Retry-After when one is sent (capped at ten
    /// seconds), else after one second and then two. LRCLIB's 503 says
    /// `ServerOverloaded` with `Retry-After: 1`; measured, it clears within
    /// a second.
    func perform(_ url: URL, retriesLeft: Int = 2) async throws(LRCLibError) -> Data? {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        let data: Data, response: HTTPURLResponse
        do {
            (data, response) = try await transport(request)
        } catch {
            throw Self.mapped(error)
        }
        switch response.statusCode {
        case 200...299:
            return data
        case 404:
            return nil
        case 429, 503:
            let after = response.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard retriesLeft > 0 else { throw LRCLibError.rateLimited(retryAfter: after) }
            do {
                try await sleeper(min(after ?? (3 - retriesLeft), 10))
            } catch {
                throw Self.mapped(error)
            }
            return try await perform(url, retriesLeft: retriesLeft - 1)
        default:
            throw LRCLibError.http(response.statusCode)
        }
    }

    /// Any failure from the transport or the sleeper as an ``LRCLibError``:
    /// cancellation — Swift's or URLSession's — as ``LRCLibError/cancelled``,
    /// the library's own errors unchanged, and the rest as
    /// ``LRCLibError/network(_:)``.
    static func mapped(_ error: any Error) -> LRCLibError {
        switch error {
        case let error as LRCLibError: error
        case is CancellationError: .cancelled
        case let error as URLError where error.code == .cancelled: .cancelled
        default: .network(error.localizedDescription)
        }
    }
}
