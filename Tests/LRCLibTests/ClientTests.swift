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
    private actor Script {
        var answers: [(Int, String, [String: String])]
        var urls: [URL] = []
        var sleeps: [Int] = []
        init(_ answers: [(Int, String, [String: String])]) { self.answers = answers }

        func answer(_ request: URLRequest) -> (Data, HTTPURLResponse) {
            urls.append(request.url!)
            let (status, body, headers) = answers.removeFirst()
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!)
        }

        func sleep(_ seconds: Int) { sleeps.append(seconds) }

        nonisolated func client() -> LRCLib {
            LRCLib(transport: { await self.answer($0) }, sleeper: { await self.sleep($0) })
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
        let sleeps = await script.sleeps
        XCTAssertEqual(sleeps, [3, 2], "no Retry-After: back off to two seconds")

        let refusing = Script([(503, "", ["Retry-After": "60"]), (503, "", ["Retry-After": "60"]), (503, "", ["Retry-After": "60"])])
        do {
            _ = try await refusing.client().lyrics(id: 1)
            XCTFail("expected rateLimited")
        } catch {
            XCTAssertEqual(error, .rateLimited(retryAfter: 60))
        }
        let capped = await refusing.sleeps
        XCTAssertEqual(capped, [10, 10], "capped at ten seconds")
    }

    func testOtherFailuresAndGarbage() async throws {
        do {
            _ = try await Script([(500, "", [:])]).client().lyrics(id: 1)
            XCTFail()
        } catch { XCTAssertEqual(error, .http(500)) }
        do {
            _ = try await Script([(200, "<html>", [:])]).client().lyrics(id: 1)
            XCTFail()
        } catch {
            guard case .malformed = error else { return XCTFail("\(error)") }
        }
    }

    func testTransportFailuresAndCancellationAreTyped() async {
        let offline = LRCLib(transport: { _ in throw URLError(.notConnectedToInternet) })
        do {
            _ = try await offline.lyrics(id: 1)
            XCTFail("expected network")
        } catch {
            guard case .network = error else { return XCTFail("\(error)") }
        }
        for failure in [CancellationError(), URLError(.cancelled)] as [any Error] {
            let client = LRCLib(transport: { _ in throw failure })
            do {
                _ = try await client.search("song")
                XCTFail("expected cancelled")
            } catch {
                XCTAssertEqual(error, .cancelled)
            }
        }
        // A sleeper interrupted mid-backoff is a cancellation too.
        let script = Script([(503, "", [:])])
        let interrupted = LRCLib(transport: { await script.answer($0) }, sleeper: { _ in throw CancellationError() })
        do {
            _ = try await interrupted.lyrics(id: 1)
            XCTFail("expected cancelled")
        } catch {
            XCTAssertEqual(error, .cancelled)
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
        let urls = await script.urls
        XCTAssertTrue(urls.isEmpty)
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
