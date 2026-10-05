import Foundation
import Testing
@testable import Lull

@MainActor
struct StatusFileTests {
    private let snapshot = Snapshot(
        machineCPUPercent: 14.04,
        recentCPUPercent: 9.96,
        apps: [AppUsage(id: "/Applications/1Password.app", name: "1Password", cpuPercentOfCore: 36, pids: [1], bundleURL: nil)],
        thermal: .nominal,
        temperature: .init(cpuCelsius: 46.24, batteryCelsius: nil),
        memory: .normal,
        memoryUsedBytes: 8 << 30,
        memoryTotalBytes: 16 << 30,
        swapGrowthBytes: 0,
        power: PowerReading(isOnAC: true, batteryPercent: 50, milliamps: 0),
        drainingOnACFraction: 0,
        span: 300,
        takenAt: Date(timeIntervalSince1970: 1_000_000)
    )

    @Test func mapsSnapshotAndVerdict() {
        let status = StatusFile(snapshot: snapshot, verdict: Verdict.evaluate(snapshot), coreCount: 18)
        #expect(status.level == "caution")
        #expect(status.reasons.map(\.message) == ["1Password is using 36% of a core", "The whole Mac is 14% busy"])
        #expect(status.cpu.averagePercent == 14)
        #expect(status.cpu.topApps.first?.percentOfMac == 2)
        #expect(status.heat.cpuCelsius == 46.2)
        #expect(status.battery?.onCharger == true)
    }

    @Test func roundTripsThroughJSON() throws {
        let status = StatusFile(snapshot: snapshot, verdict: Verdict.evaluate(snapshot), coreCount: 18)
        let data = try StatusFile.encoder.encode(status)
        #expect(try StatusFile.decoder.decode(StatusFile.self, from: data) == status)
    }

    @Test func summaryFlagsStaleStatus() {
        let status = StatusFile(snapshot: snapshot, verdict: Verdict.evaluate(snapshot), coreCount: 18)
        #expect(status.summary(now: snapshot.takenAt.addingTimeInterval(30)).contains("stale") == false)
        #expect(status.summary(now: snapshot.takenAt.addingTimeInterval(600)).contains("stale"))
    }
}
