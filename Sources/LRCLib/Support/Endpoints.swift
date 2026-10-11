//
//  Endpoints.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// LRCLIB's URLs, built in one place and testable offline.
enum Endpoints {

    static let base = "https://lrclib.net/api"

    /// `/api/get` — or `/api/get-cached`, which answers only from LRCLIB's own
    /// store and never reaches out to its upstream sources.
    static func get(artist: String, track: String, album: String?, duration: TimeInterval?, cachedOnly: Bool) -> URL {
        url(cachedOnly ? "/get-cached" : "/get", [
            ("artist_name", artist), ("track_name", track), ("album_name", album),
            // Whole seconds: the API matches within about two seconds either way.
            ("duration", duration.map { String(Int($0.rounded())) }),
        ])
    }

    /// `/api/get/{id}`.
    static func get(id: Int) -> URL {
        url("/get/\(id)", [])
    }

    /// `/api/search` — free text, or by field.
    static func search(query: String?, track: String?, artist: String?, album: String?) -> URL {
        url("/search", [("q", query), ("track_name", track), ("artist_name", artist), ("album_name", album)])
    }

    private static func url(_ path: String, _ items: [(String, String?)]) -> URL {
        var components = URLComponents(string: base + path)!
        let present = items.compactMap { name, value in value.map { URLQueryItem(name: name, value: $0) } }
        components.queryItems = present.isEmpty ? nil : present
        // `+` is legal in a query but read as a space by many servers.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }
}
