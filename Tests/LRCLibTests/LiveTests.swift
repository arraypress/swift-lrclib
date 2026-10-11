//
//  LiveTests.swift
//  LRCLibTests
//
//  Created by David Sherlock on 2026.
//
//  Against the real LRCLIB. Each skips — never fails — when the network is
//  down or the service is throttling, and checks shape, not words.
//

import Foundation
import XCTest
@testable import LRCLib

final class LiveTests: XCTestCase {

    private let client = LRCLib()

    /// Runs `body`, turning a refusal or no network into a skip.
    private func live<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch LRCLibError.rateLimited, LRCLibError.http(500...599) {
            throw XCTSkip("LRCLIB is refusing requests")
        } catch LRCLibError.network(let why) {
            throw XCTSkip("no network: \(why)")
        }
    }

    func testAKnownTrackHasPlainAndSyncedLyrics() async throws {
        let song = try await live { try await client.lyrics(artist: "Queen", track: "Bohemian Rhapsody", duration: 355) }
        let found = try XCTUnwrap(song)
        XCTAssertFalse(found.isInstrumental)
        XCTAssertNotNil(found.plain)
        XCTAssertTrue(found.hasSyncedLyrics)
        XCTAssertGreaterThan(found.timedLines.count, 20)
        XCTAssertNotNil(found.captions(.srt))
    }

    func testAMissIsNil() async throws {
        let song = try await live { try await client.lyrics(artist: "zzqx no such artist", track: "zzqx no such track") }
        XCTAssertNil(song)
    }

    func testSearchIsCappedAtTwenty() async throws {
        let hits = try await live { try await client.search("love") }
        XCTAssertFalse(hits.isEmpty)
        XCTAssertLessThanOrEqual(hits.count, LRCLib.searchLimit)
    }
}
