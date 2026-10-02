import Foundation
import Testing
@testable import Lull

@MainActor
struct VerdictTests {
    private func snapshot(
        cpu: Double? = 2,
        apps: [AppUsage] = [],
        thermal: Thermal = .nominal,
        memory: MemoryPressure = .normal,
        swapGrowth: Int64 = 0,
        power: PowerReading? = PowerReading(isOnAC: true, batteryPercent: 50, milliamps: 0),
        draining: Double = 0
    ) -> Snapshot {
        Snapshot(
            machineCPUPercent: cpu,
            recentCPUPercent: cpu,
            apps: apps,
            thermal: thermal,
            temperature: .init(cpuCelsius: 45, batteryCelsius: 30),
            memory: memory,
            memoryUsedBytes: 8 << 30,
            memoryTotalBytes: 16 << 30,
            swapGrowthBytes: swapGrowth,
            power: power,
            drainingOnACFraction: draining,
            span: 300,
            takenAt: .now
        )
    }

    private func app(_ name: String, cpu: Double) -> AppUsage {
        AppUsage(id: "/Applications/\(name).app", name: name, cpuPercentOfCore: cpu, pids: [1], bundleURL: nil)
    }

    @Test func idleMachineIsSafe() {
        let verdict = Verdict.evaluate(snapshot(apps: [app("Simulator", cpu: 3)]))
        #expect(verdict.level == .safe)
        #expect(verdict.reasons.isEmpty)
    }

    @Test(arguments: [(9.9, Level.safe), (10, .caution), (39.9, .caution), (40, .unsafe)])
    func machineCPUThresholds(cpu: Double, expected: Level) {
        #expect(Verdict.evaluate(snapshot(cpu: cpu)).level == expected)
    }

    @Test(arguments: [(24.9, Level.safe), (25, .caution), (79.9, .caution), (80, .unsafe)])
    func singleAppThresholds(cpu: Double, expected: Level) {
        #expect(Verdict.evaluate(snapshot(apps: [app("Emulator", cpu: cpu)])).level == expected)
    }

    @Test func busyAppReasonCarriesAppForQuitButton() {
        let verdict = Verdict.evaluate(snapshot(apps: [app("Emulator", cpu: 100)]))
        #expect(verdict.reasons.first?.app?.name == "Emulator")
        #expect(verdict.reasons.first?.message == "Emulator is using 100% of a core")
    }

    @Test(arguments: [(Thermal.nominal, Level.safe), (.fair, .caution), (.serious, .unsafe), (.critical, .unsafe)])
    func thermalLevels(thermal: Thermal, expected: Level) {
        #expect(Verdict.evaluate(snapshot(thermal: thermal)).level == expected)
    }

    @Test func drainingOnChargerIsUnsafe() {
        #expect(Verdict.evaluate(snapshot(draining: 0.6)).level == .unsafe)
    }

    @Test func drainingOnBatteryIsExpected() {
        let onBattery = PowerReading(isOnAC: false, batteryPercent: 50, milliamps: -500)
        #expect(Verdict.evaluate(snapshot(power: onBattery, draining: 1)).level == .safe)
    }

    @Test func memoryPressureIsCaution() {
        #expect(Verdict.evaluate(snapshot(memory: .warning)).level == .caution)
    }

    @Test func growingSwapIsCaution() {
        #expect(Verdict.evaluate(snapshot(swapGrowth: 512 * 1024 * 1024)).level == .caution)
    }

    @Test func worstReasonComesFirst() {
        let verdict = Verdict.evaluate(snapshot(cpu: 15, apps: [app("Emulator", cpu: 90)], thermal: .fair))
        #expect(verdict.level == .unsafe)
        #expect(verdict.reasons.first?.level == .unsafe)
    }
}
