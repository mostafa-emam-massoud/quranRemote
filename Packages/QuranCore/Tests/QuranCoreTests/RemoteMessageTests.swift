import XCTest
@testable import QuranCore

final class RemoteMessageTests: XCTestCase {

    private func roundTrip(_ message: RemoteMessage, file: StaticString = #filePath, line: UInt = #line) {
        guard let payload = try? message.payload() else {
            return XCTFail("could not encode \(message)", file: file, line: line)
        }
        XCTAssertNotNil(payload[RemoteMessage.payloadKey] as? Data, file: file, line: line)
        XCTAssertEqual(RemoteMessage(payload: payload), message, file: file, line: line)

        guard let data = try? message.encoded() else {
            return XCTFail("could not encode \(message) as data", file: file, line: line)
        }
        XCTAssertEqual(RemoteMessage(data: data), message, file: file, line: line)
    }

    func testEveryCommandSurvivesTheTrip() {
        roundTrip(.command(.next(.page)))
        roundTrip(.command(.next(.verse)))
        roundTrip(.command(.previous(.page)))
        roundTrip(.command(.previous(.verse)))
        roundTrip(.command(.goToPage(255)))
        roundTrip(.command(.goToSurah(18)))
        roundTrip(.command(.goToJuz(30)))
        roundTrip(.command(.requestState))
    }

    func testStateSurvivesTheTrip() {
        // Seconds precision on the wire, so compare against a whole second.
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        roundTrip(.state(ReaderStateSnapshot(page: 293, verseKey: "18:10", updatedAt: stamp)))
        roundTrip(.state(ReaderStateSnapshot(page: 1, displayMode: .continuous, updatedAt: stamp)))
    }

    func testGarbagePayloadsAreRejectedRatherThanCrashing() {
        XCTAssertNil(RemoteMessage(payload: [:]))
        XCTAssertNil(RemoteMessage(payload: ["something": "else"]))
        XCTAssertNil(RemoteMessage(payload: [RemoteMessage.payloadKey: Data("not json".utf8)]))
        XCTAssertNil(RemoteMessage(data: Data()))
    }

    func testSnapshotDerivesSurahAndJuzFromThePage() {
        let snapshot = ReaderStateSnapshot(page: 604)
        XCTAssertEqual(snapshot.surahNumber, 114)
        XCTAssertEqual(snapshot.juz.number, 30)
        XCTAssertEqual(snapshot.surah.transliteratedName, "An-Nas")
    }

    func testSnapshotClampsImpossiblePages() {
        XCTAssertEqual(ReaderStateSnapshot(page: 10_000).page, 604)
        XCTAssertEqual(ReaderStateSnapshot(page: 0).page, 1)
    }
}
