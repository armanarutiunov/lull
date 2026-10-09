import Foundation
import Testing
@testable import Lull

@MainActor
struct HistoryTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func entry(minutesAfterStart minutes: Double) -> HistoryEntry {
        HistoryEntry(
            time: start.addingTimeInterval(minutes * 60),
            level: "safe",
            cpuAveragePercent: 4,
            topApps: [],
            reasons: [],
            cpuCelsius: 40,
            memoryUsedBytes: 1,
            memoryPressure: "normal",
            batteryPercent: 50,
            onCharger: true,
            batteryMilliamps: 0
        )
    }

    @Test func skipsReadingsCloserThanFiveMinutes() {
        var history = History()
        let first = history.record(entry(minutesAfterStart: 0))
        let tooSoon = history.record(entry(minutesAfterStart: 4.5))
        let onTime = history.record(entry(minutesAfterStart: 5))
        #expect(first && !tooSoon && onTime)
        #expect(history.entries.count == 2)
    }

    @Test func keepsOnlyTheLast24Hours() {
        var history = History()
        for minute in stride(from: 0.0, through: 26 * 60, by: 5) {
            history.record(entry(minutesAfterStart: minute))
        }
        #expect(history.entries.count == 288)
        #expect(history.entries.first?.time == start.addingTimeInterval((2 * 60 + 5) * 60))
    }

    @Test func roundTripsThroughJSON() throws {
        var history = History()
        history.record(entry(minutesAfterStart: 0))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(history)
        #expect(try StatusFile.decoder.decode(History.self, from: data) == history)
    }
}
