//
//  CaptionTests.swift
//  LRCLibTests
//
//  Created by David Sherlock on 2026.
//
//  Timed lines to SRT and WebVTT through SubtitleKit.
//

import Foundation
import XCTest
import SubtitleKit
@testable import LRCLib

final class CaptionTests: XCTestCase {

    private let doc = LRCDocument(parsing: "[00:01.00] One\n[00:03.50] Two\n[00:06.00]\n[00:10.00] Three")

    func testEachLineLastsUntilTheNextStampAndGapsEndCues() {
        let cues = doc.cues()
        XCTAssertEqual(cues.map(\.text), ["One", "Two", "Three"])
        XCTAssertEqual(cues.map(\.start), [1, 3.5, 10])
        XCTAssertEqual(cues.map(\.end), [3.5, 6, 15], "the gap ends Two; Three holds five seconds")
    }

    func testTheLastLineStopsAtTheTracksEnd() {
        XCTAssertEqual(doc.cues(trackDuration: 12).last?.end, 12)
        XCTAssertEqual(doc.cues(trackDuration: 60).last?.end, 15, "never longer than the hold")
        XCTAssertEqual(doc.cues(trackDuration: 5).last?.end, 15, "a duration before the line is ignored")
    }

    func testSharedStampsBecomeOneTwoLineCue() {
        let cues = LRCDocument(parsing: "[00:01.00] Lead\n[00:01.00] Echo\n[00:02.00] Next").cues()
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0].text, "Lead\nEcho")
    }

    func testSRTAndVTTRender() throws {
        let srt = try XCTUnwrap(doc.captions(.srt))
        XCTAssertTrue(srt.hasPrefix("1\n00:00:01,000 --> 00:00:03,500\nOne\n"), srt)
        XCTAssertTrue(srt.contains("3\n00:00:10,000 --> 00:00:15,000\nThree"))
        let vtt = try XCTUnwrap(doc.captions(.vtt))
        XCTAssertTrue(vtt.hasPrefix("WEBVTT"), vtt)
        XCTAssertTrue(vtt.contains("00:00:01.000 --> 00:00:03.500"))
    }

    func testNoWordsNoCaptions() {
        XCTAssertNil(LRCDocument(parsing: "[00:01.00]\n").captions(.srt))
        XCTAssertNil(LRCDocument(parsing: "").captions(.vtt))
    }

    func testLyricsFallBackToSyncedTextAndInstrumentalsHaveNone() {
        let syncedOnly = Lyrics(id: 1, track: "T", artist: "A", album: nil, duration: 20, isInstrumental: false,
                                hasWordSync: false, plain: nil, synced: "[00:01.00] One\n[00:02.00]\n[00:03.00] Two")
        XCTAssertEqual(syncedOnly.text, "One\n\nTwo")
        XCTAssertTrue(syncedOnly.hasSyncedLyrics)
        XCTAssertNotNil(syncedOnly.captions(.srt))
        let instrumental = Lyrics(id: 2, track: "T", artist: "A", album: nil, duration: 20, isInstrumental: true,
                                  hasWordSync: false, plain: nil, synced: nil)
        XCTAssertNil(instrumental.text)
        XCTAssertFalse(instrumental.hasSyncedLyrics)
        XCTAssertNil(instrumental.captions(.vtt))
        XCTAssertTrue(instrumental.timedLines.isEmpty)
    }
}
