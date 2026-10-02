import Foundation
import Observation

@Observable
final class Monitor {
    static let interval: Duration = .seconds(30)
    static let windowDuration: TimeInterval = 5 * 60

    private(set) var snapshot: Snapshot?
    private(set) var verdict: Verdict?

    @ObservationIgnored private var window = SampleWindow(duration: windowDuration)
    @ObservationIgnored private var loop: Task<Void, Never>?

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            self?.sample()
            // A second sample soon after launch gives a first verdict without waiting a full interval.
            try? await Task.sleep(for: .seconds(5))
            while !Task.isCancelled {
                self?.sample()
                try? await Task.sleep(for: Self.interval)
            }
        }
    }

    func refresh() {
        sample()
    }

    private func sample() {
        let ticks = CPUReader.machineTicks()
        window.append(Sample(
            uptimeNanos: clock_gettime_nsec_np(CLOCK_UPTIME_RAW),
            busyTicks: ticks.busy,
            totalTicks: ticks.total,
            processes: CPUReader.processes(),
            power: PowerReader.read(),
            swapUsedBytes: MemoryReader.swapUsedBytes()
        ))

        let snapshot = Snapshot(
            machineCPUPercent: window.machineCPUPercent,
            apps: AppGrouping.group(window.processAverages),
            thermal: Thermal(ProcessInfo.processInfo.thermalState),
            memory: MemoryReader.pressure(),
            swapGrowthBytes: window.swapGrowthBytes,
            power: window.samples.last?.power,
            drainingOnACFraction: window.drainingOnACFraction,
            span: window.span,
            takenAt: .now
        )
        self.snapshot = snapshot
        verdict = Verdict.evaluate(snapshot)
    }
}
