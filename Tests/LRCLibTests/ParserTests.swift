//
//  ParserTests.swift
//  LRCLibTests
//
//  Created by David Sherlock on 2026.
//
//  The LRC parser and writer, offline. Lyrics here are invented: no song's
//  words are carried in the repository.
//

import Foundation
import XCTest
@testable import LRCLib

final class ParserTests: XCTestCase {

    func testLRCLIBShapeParsesToTheHundredth() {
        let doc = LRCDocument(parsing: "[00:00.63] First line\n[00:05.91] Second line\n[01:02.07] Third")
        XCTAssertEqual(doc.lines.map(\.text), ["First line", "Second line", "Third"])
        XCTAssertEqual(doc.lines[0].time, 0.63, accuracy: 0.0001)
        XCTAssertEqual(doc.lines[2].time, 62.07, accuracy: 0.0001)
        XCTAssertTrue(doc.tags.isEmpty)
        XCTAssertEqual(doc.offset, 0)
    }

    func testEveryFractionWidthAndTheColonForm() {
        XCTAssertEqual(LRCParser.timeStamp("01:02"), 62)
        XCTAssertEqual(LRCParser.timeStamp("01:02.5")!, 62.5, accuracy: 0.0001)
        XCTAssertEqual(LRCParser.timeStamp("01:02.50")!, 62.5, accuracy: 0.0001)
        XCTAssertEqual(LRCParser.timeStamp("01:02.505")!, 62.505, accuracy: 0.0001)
        XCTAssertEqual(LRCParser.timeStamp("01:02:50")!, 62.5, accuracy: 0.0001, "[mm:ss:xx] is hundredths")
        XCTAssertEqual(LRCParser.timeStamp("123:00"), 7_380, "minutes may run past 59")
        XCTAssertEqual(LRCParser.timeStamp("1:05"), 65, "one-digit minutes")
    }

    func testNonsenseStampsAreNotStamps() {
        for bad in ["", "ar:Queen", "00:60.00", "00:5x", "-1:00", "00:00.1234", "aa:bb", "00", "00:00:00:00", "00:٣٠"] {
            XCTAssertNil(LRCParser.timeStamp(Substring(bad)), bad)
        }
    }

    func testSeveralStampsOnOneLineRepeatTheLineInTimeOrder() {
        let doc = LRCDocument(parsing: "[00:10.00][00:40.00] Chorus\n[00:20.00] Verse")
        XCTAssertEqual(doc.lines.map(\.time), [10, 20, 40])
        XCTAssertEqual(doc.lines.map(\.text), ["Chorus", "Verse", "Chorus"])
    }

    func testTagsAreReadAndLowerCasedAndNotLines() {
        let doc = LRCDocument(parsing: "[ar: Some Artist ]\n[TI:Some Title]\n[al:]\n[length: 03:12]\n[00:01.00] Words")
        XCTAssertEqual(doc.tags["ar"], "Some Artist")
        XCTAssertEqual(doc.tags["ti"], "Some Title")
        XCTAssertEqual(doc.tags["al"], "")
        XCTAssertEqual(doc.tags["length"], "03:12")
        XCTAssertEqual(doc.lines.count, 1)
    }

    func testOffsetShowsLyricsSoonerAndNeverBeforeZero() {
        let sooner = LRCDocument(parsing: "[offset:+500]\n[00:00.20] A\n[00:10.00] B")
        XCTAssertEqual(sooner.offset, 0.5)
        XCTAssertEqual(sooner.lines.map(\.time), [0, 9.5], "clamped at zero")
        let later = LRCDocument(parsing: "[offset:-1000]\n[00:10.00] B")
        XCTAssertEqual(later.lines[0].time, 11)
    }

    func testEmptyStampsAreGapsAndUnstampedLinesAreDropped() {
        let doc = LRCDocument(parsing: "[Chorus]\nprose with no time\n\n[00:01.00] A\n[00:04.00]\n[00:09.00] B\n")
        XCTAssertEqual(doc.lines.map(\.text), ["A", "", "B"])
        XCTAssertTrue(doc.hasWords)
    }

    func testEveryLineEndingSplits() {
        // CRLF is ONE Character in Swift: splitting on "\n" finds nothing here.
        for ending in ["\n", "\r\n", "\r", "\u{2028}"] {
            let doc = LRCDocument(parsing: ["[00:01.00] A", "[00:02.00] B", "[00:03.00] C"].joined(separator: ending))
            XCTAssertEqual(doc.lines.map(\.text), ["A", "B", "C"], ending.debugDescription)
        }
    }

    func testBOMEnhancedWordStampsAndSpacing() {
        let doc = LRCDocument(parsing: "\u{FEFF}[00:01.00] <00:01.00>One <00:01.50>two   three\t")
        XCTAssertEqual(doc.lines.map(\.text), ["One two three"])
        XCTAssertEqual(doc.lines[0].time, 1)
    }

    func testUnicodeSurvives() {
        let doc = LRCDocument(parsing: "[00:01.00] 夜に駆ける\n[00:02.00] على الطريق\n[00:03.00] Ça va & 👍")
        XCTAssertEqual(doc.lines.map(\.text), ["夜に駆ける", "على الطريق", "Ça va & 👍"])
    }

    func testNotLRCParsesToNothing() {
        XCTAssertTrue(LRCDocument(parsing: "").lines.isEmpty)
        XCTAssertTrue(LRCDocument(parsing: "just some words\nmore words").lines.isEmpty)
        XCTAssertFalse(LRCDocument(parsing: "[00:01.00]\n[00:02.00]").hasWords, "gaps alone are not lyrics")
    }

    func testWriterRoundTripsAndRounds() {
        let text = "[00:00.63] First\n[00:05.91] Second\n[01:02.07]\n[100:00.00] Long"
        XCTAssertEqual(LRCDocument(parsing: text).lrc, text)
        XCTAssertEqual(LRCWriter.stamp(62.07), "01:02.07")
        XCTAssertEqual(LRCWriter.stamp(59.999), "01:00.00", "rounds up across the minute")
        XCTAssertEqual(LRCWriter.stamp(-3), "00:00.00")
    }

    func testFiveThousandLinesParseQuickly() {
        let text = (0..<5_000).map { "[\(String(format: "%02d:%02d.%02d", $0 / 6_000, ($0 / 100) % 60, $0 % 100))] line \($0)" }
            .joined(separator: "\n")
        let started = Date()
        let doc = LRCDocument(parsing: text)
        XCTAssertEqual(doc.lines.count, 5_000)
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }
}
