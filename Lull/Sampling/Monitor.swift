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
    @ObservationIgnored private var history = History.load()

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

        let memory = MemoryReader.usage()
        let snapshot = Snapshot(
            machineCPUPercent: window.machineCPUPercent,
            recentCPUPercent: window.recentCPUPercent,
            apps: AppGrouping.group(window.processAverages),
            thermal: Thermal(ProcessInfo.processInfo.thermalState),
            temperature: TemperatureReader.read(),
            memory: MemoryReader.pressure(),
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            swapGrowthBytes: window.swapGrowthBytes,
            power: window.samples.last?.power,
            drainingOnACFraction: window.drainingOnACFraction,
            span: window.span,
            takenAt: .now
        )
        self.snapshot = snapshot
        let verdict = Verdict.evaluate(snapshot)
        self.verdict = verdict
        let status = StatusFile(snapshot: snapshot, verdict: verdict, coreCount: ProcessInfo.processInfo.activeProcessorCount)
        try? status.write()
        // A few seconds after launch the averages cover too little time to be worth keeping.
        if snapshot.span >= 60, history.record(HistoryEntry(status: status)) {
            try? history.write()
        }
    }
}
