//
//  ClientTests.swift
//  LRCLibTests
//
//  Created by David Sherlock on 2026.
//
//  The client on a recorded transport: decoding, misses, throttling, URLs.
//

import Foundation
import XCTest
@testable import LRCLib

final class ClientTests: XCTestCase {

    /// A transport that answers each request in turn and records the URLs.
    private final class Script: @unchecked Sendable {
        var answers: [(Int, String, [String: String])]
        var urls: [URL] = []
        var sleeps: [Int] = []
        init(_ answers: [(Int, String, [String: String])]) { self.answers = answers }

        func client() -> LRCLib {
            LRCLib(transport: { request in
                self.urls.append(request.url!)
                let (status, body, headers) = self.answers.removeFirst()
                return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!)
            }, sleeper: { self.sleeps.append($0) })
        }
    }

    private let record = """
        {"id":7,"name":"Song","trackName":"Song","artistName":"Band","albumName":"null","duration":201.0,\
        "instrumental":false,"hasWordSync":false,"plainLyrics":"One\\nTwo","syncedLyrics":"[00:01.00] One\\n[00:02.00] Two"}
        """

    func testARecordDecodes() async throws {
        let script = Script([(200, record, [:])])
        let song = try await script.client().lyrics(artist: "Band", track: "Song")
        XCTAssertEqual(song?.id, 7)
        XCTAssertNil(song?.album, "the literal \"null\" LRCLIB sometimes stores is no album")
        XCTAssertEqual(song?.duration, 201)
        XCTAssertEqual(song?.timedLines.count, 2)
    }

    func testAMissIsNilNotAnError() async throws {
        let miss = #"{"message":"Failed to find specified track","name":"TrackNotFound","statusCode":404}"#
        let script = Script([(404, miss, [:]), (404, miss, [:])])
        let byName = try await script.client().lyrics(artist: "Nobody", track: "Nothing")
        let byID = try await script.client().lyrics(id: 999_999_999)
        XCTAssertNil(byName)
        XCTAssertNil(byID)
    }

    func testAnInstrumentalHasNoText() async throws {
        let body = #"{"id":3,"trackName":"Tune","artistName":"Band","albumName":"","duration":0,"instrumental":true,"plainLyrics":null,"syncedLyrics":null}"#
        let song = try await Script([(200, body, [:])]).client().lyrics(id: 3)
        XCTAssertEqual(song?.isInstrumental, true)
        XCTAssertNil(song?.plain)
        XCTAssertNil(song?.album)
        XCTAssertNil(song?.duration, "zero is no duration")
        XCTAssertNil(song?.text)
    }

    func testThrottlingRetriesWithRetryAfterThenGivesUp() async throws {
        let script = Script([(503, "", ["Retry-After": "3"]), (429, "", [:]), (200, "[\(record)]", [:])])
        let hits = try await script.client().search("song")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(script.sleeps, [3, 2], "no Retry-After: back off to two seconds")

        let refusing = Script([(503, "", ["Retry-After": "60"]), (503, "", ["Retry-After": "60"]), (503, "", ["Retry-After": "60"])])
        do {
            _ = try await refusing.client().lyrics(id: 1)
            XCTFail("expected rateLimited")
        } catch let error as LRCLibError {
            XCTAssertEqual(error, .rateLimited(retryAfter: 60))
        }
        XCTAssertEqual(refusing.sleeps, [10, 10], "capped at ten seconds")
    }

    func testOtherFailuresAndGarbage() async throws {
        do {
            _ = try await Script([(500, "", [:])]).client().lyrics(id: 1)
            XCTFail()
        } catch let error as LRCLibError { XCTAssertEqual(error, .http(500)) }
        do {
            _ = try await Script([(200, "<html>", [:])]).client().lyrics(id: 1)
            XCTFail()
        } catch let error as LRCLibError {
            guard case .malformed = error else { return XCTFail("\(error)") }
        }
    }

    func testValidationRunsBeforeAnyRequest() async {
        let script = Script([])
        let client = script.client()
        for attempt in [
            { _ = try await client.lyrics(artist: " ", track: "x") },
            { _ = try await client.lyrics(artist: "x", track: "") },
            { _ = try await client.lyrics(artist: "x", track: "y", duration: 0) },
            { _ = try await client.lyrics(id: 0) },
            { _ = try await client.search(artist: "only an artist") },
        ] as [() async throws -> Void] {
            do { try await attempt(); XCTFail() } catch let error as LRCLibError {
                guard case .invalidQuery = error else { return XCTFail("\(error)") }
            } catch { XCTFail("\(error)") }
        }
        XCTAssertTrue(script.urls.isEmpty)
    }

    func testURLsEncodeAmpersandsPlusAndUnicode() {
        let url = Endpoints.get(artist: "Simon & Garfunkel", track: "1+1 夜", album: nil, duration: 201.6, cachedOnly: false)
        XCTAssertEqual(url.path, "/api/get")
        let query = url.query(percentEncoded: true) ?? ""
        XCTAssertTrue(query.contains("artist_name=Simon%20%26%20Garfunkel"), query)
        XCTAssertTrue(query.contains("track_name=1%2B1%20%E5%A4%9C"), query)
        XCTAssertTrue(query.contains("duration=202"), query)
        XCTAssertFalse(query.contains("album_name"))
        XCTAssertEqual(Endpoints.get(artist: "a", track: "b", album: nil, duration: nil, cachedOnly: true).path, "/api/get-cached")
        XCTAssertEqual(Endpoints.get(id: 19080).absoluteString, "https://lrclib.net/api/get/19080")
    }
}
