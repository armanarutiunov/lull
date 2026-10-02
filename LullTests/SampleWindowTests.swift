import Foundation
import Testing
@testable import Lull

@MainActor
struct SampleWindowTests {
    private func sample(
        at seconds: Double,
        busy: UInt32,
        total: UInt32,
        processes: [pid_t: ProcessSample] = [:],
        power: PowerReading? = nil,
        swap: UInt64 = 0
    ) -> Sample {
        Sample(
            uptimeNanos: UInt64(seconds * 1e9),
            busyTicks: busy,
            totalTicks: total,
            processes: processes,
            power: power,
            swapUsedBytes: swap
        )
    }

    @Test func machineCPUUsesFirstAndLastSample() {
        var window = SampleWindow(duration: 300)
        window.append(sample(at: 0, busy: 100, total: 1000))
        window.append(sample(at: 30, busy: 400, total: 2000))
        #expect(window.machineCPUPercent == 30)
    }

    @Test func machineCPUSurvivesTickCounterWrap() {
        var window = SampleWindow(duration: 300)
        window.append(sample(at: 0, busy: .max - 9, total: .max - 99))
        window.append(sample(at: 30, busy: 10, total: 100))
        #expect(window.machineCPUPercent == 10)
    }

    @Test func dropsSamplesOlderThanWindow() {
        var window = SampleWindow(duration: 60)
        window.append(sample(at: 0, busy: 0, total: 0))
        window.append(sample(at: 30, busy: 0, total: 0))
        window.append(sample(at: 90, busy: 0, total: 0))
        #expect(window.samples.count == 2)
        #expect(window.span == 60)
    }

    @Test func processAverageIsPercentOfOneCore() throws {
        var window = SampleWindow(duration: 300)
        window.append(sample(at: 0, busy: 0, total: 1, processes: [42: ProcessSample(path: "/bin/busy", cpuTimeNanos: 0)]))
        window.append(sample(at: 10, busy: 0, total: 2, processes: [42: ProcessSample(path: "/bin/busy", cpuTimeNanos: 15_000_000_000)]))
        let average = try #require(window.processAverages.first)
        #expect(average.cpuPercentOfCore == 150)
    }

    @Test func processStartedMidWindowIsMeasuredFromFirstAppearance() {
        var window = SampleWindow(duration: 300)
        window.append(sample(at: 0, busy: 0, total: 1))
        window.append(sample(at: 10, busy: 0, total: 2, processes: [7: ProcessSample(path: "/bin/new", cpuTimeNanos: 0)]))
        window.append(sample(at: 20, busy: 0, total: 3, processes: [7: ProcessSample(path: "/bin/new", cpuTimeNanos: 5_000_000_000)]))
        #expect(window.processAverages.first?.cpuPercentOfCore == 50)
    }

    @Test func reusedPidIsTreatedAsNewProcess() {
        var window = SampleWindow(duration: 300)
        window.append(sample(at: 0, busy: 0, total: 1, processes: [7: ProcessSample(path: "/bin/old", cpuTimeNanos: 90_000_000_000)]))
        window.append(sample(at: 10, busy: 0, total: 2, processes: [7: ProcessSample(path: "/bin/new", cpuTimeNanos: 1_000_000_000)]))
        #expect(window.processAverages.isEmpty)
    }

    @Test func drainingFractionOnlyCountsSamplesOnCharger() {
        var window = SampleWindow(duration: 300)
        window.append(sample(at: 0, busy: 0, total: 0, power: PowerReading(isOnAC: true, batteryPercent: 50, milliamps: -200)))
        window.append(sample(at: 30, busy: 0, total: 0, power: PowerReading(isOnAC: true, batteryPercent: 50, milliamps: 0)))
        window.append(sample(at: 60, busy: 0, total: 0, power: PowerReading(isOnAC: false, batteryPercent: 49, milliamps: -900)))
        #expect(window.drainingOnACFraction == 0.5)
    }

    @Test func swapGrowthComparesEnds() {
        var window = SampleWindow(duration: 300)
        window.append(sample(at: 0, busy: 0, total: 0, swap: 1_000))
        window.append(sample(at: 30, busy: 0, total: 0, swap: 4_000))
        #expect(window.swapGrowthBytes == 3_000)
    }
}
