import Foundation

struct ProcessAverage: Equatable, Sendable {
    let pid: pid_t
    let path: String
    let cpuPercentOfCore: Double
}

struct SampleWindow: Sendable {
    let duration: TimeInterval
    private(set) var samples: [Sample] = []

    init(duration: TimeInterval) {
        self.duration = duration
    }

    mutating func append(_ sample: Sample) {
        samples.append(sample)
        let cutoff = Double(sample.uptimeNanos) - duration * 1e9
        samples.removeAll { Double($0.uptimeNanos) < cutoff }
    }

    var span: TimeInterval {
        guard let first = samples.first, let last = samples.last else { return 0 }
        return Double(last.uptimeNanos - first.uptimeNanos) / 1e9
    }

    var machineCPUPercent: Double? {
        guard let first = samples.first, let last = samples.last, first != last else { return nil }
        // Mach tick counters are 32-bit and wrap after a few weeks of uptime.
        let busy = last.busyTicks &- first.busyTicks
        let total = last.totalTicks &- first.totalTicks
        guard total > 0 else { return nil }
        return Double(busy) / Double(total) * 100
    }

    var processAverages: [ProcessAverage] {
        guard let last = samples.last else { return [] }
        return last.processes.compactMap { pid, latest in
            // A process that started mid-window is measured from its first appearance; a
            // reused pid with a different executable is treated as a new process.
            guard let base = samples.first(where: { $0.processes[pid]?.path == latest.path }),
                  base.uptimeNanos < last.uptimeNanos,
                  let baseProcess = base.processes[pid],
                  latest.cpuTimeNanos >= baseProcess.cpuTimeNanos
            else { return nil }
            let elapsed = Double(last.uptimeNanos - base.uptimeNanos)
            let used = Double(latest.cpuTimeNanos - baseProcess.cpuTimeNanos)
            return ProcessAverage(pid: pid, path: latest.path, cpuPercentOfCore: used / elapsed * 100)
        }
    }

    var drainingOnACFraction: Double {
        let onAC = samples.compactMap(\.power).filter(\.isOnAC)
        guard !onAC.isEmpty else { return 0 }
        return Double(onAC.filter { $0.milliamps < 0 }.count) / Double(onAC.count)
    }

    var swapGrowthBytes: Int64 {
        guard let first = samples.first, let last = samples.last else { return 0 }
        return Int64(last.swapUsedBytes) - Int64(first.swapUsedBytes)
    }
}
