import Foundation

enum Thermal: Int, Comparable, Sendable {
    case nominal, fair, serious, critical

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .serious
        }
    }

    static func < (lhs: Thermal, rhs: Thermal) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct AppUsage: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let cpuPercentOfCore: Double
    let pids: [pid_t]
    let bundleURL: URL?
}

extension AppUsage {
    // Above one core the work is spread over several cores, so "150% of a core" reads better
    // as "1.5 cores". Which cores is unknowable: macOS moves threads between them constantly.
    var coreUsage: String {
        cpuPercentOfCore < 100
            ? "\(Int(cpuPercentOfCore.rounded()))% of a core"
            : String(format: "%.1f cores", cpuPercentOfCore / 100)
    }
}

struct Snapshot: Equatable, Sendable {
    var machineCPUPercent: Double?
    var recentCPUPercent: Double?
    var apps: [AppUsage]
    var thermal: Thermal
    var temperature: TemperatureReader.Reading
    var memory: MemoryPressure
    var memoryUsedBytes: UInt64
    var memoryTotalBytes: UInt64
    var swapGrowthBytes: Int64
    var power: PowerReading?
    var drainingOnACFraction: Double
    var span: TimeInterval
    var takenAt: Date
}
