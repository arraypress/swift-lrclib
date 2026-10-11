//
//  LyricsResponse.swift
//  LRCLib
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A record as `/api/get`, `/api/get/{id}` and `/api/search` return it.
/// `hasWordSync` and `lyricsfile` are newer fields; only the first is read.
struct LyricsResponse: Decodable {
    let id: Int
    let trackName: String?
    let name: String?
    let artistName: String
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let hasWordSync: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}
