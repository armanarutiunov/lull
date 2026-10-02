import Foundation

enum Level: Int, Comparable, Sendable {
    case safe, caution, unsafe

    static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Reason: Identifiable, Equatable, Sendable {
    let id: String
    let level: Level
    let message: String
    var app: AppUsage? = nil
}

struct Thresholds: Sendable {
    var machineCPUCaution: Double = 10
    var machineCPUUnsafe: Double = 40
    var appCPUCaution: Double = 25
    var appCPUUnsafe: Double = 80
    var drainingFractionUnsafe: Double = 0.5
    var swapGrowthCautionBytes: Int64 = 256 * 1024 * 1024
    var maxAppReasons = 3

    static let standard = Thresholds()
}

struct Verdict: Equatable, Sendable {
    let level: Level
    let reasons: [Reason]

    static func evaluate(_ snapshot: Snapshot, thresholds t: Thresholds = .standard) -> Verdict {
        var reasons: [Reason] = []

        for app in snapshot.apps.prefix(t.maxAppReasons) where app.cpuPercentOfCore >= t.appCPUCaution {
            reasons.append(Reason(
                id: "app:\(app.id)",
                level: app.cpuPercentOfCore >= t.appCPUUnsafe ? .unsafe : .caution,
                message: "\(app.name) is using \(Int(app.cpuPercentOfCore.rounded()))% CPU",
                app: app
            ))
        }

        if let cpu = snapshot.machineCPUPercent, cpu >= t.machineCPUCaution {
            reasons.append(Reason(
                id: "machine-cpu",
                level: cpu >= t.machineCPUUnsafe ? .unsafe : .caution,
                message: "The whole Mac is \(Int(cpu.rounded()))% busy"
            ))
        }

        switch snapshot.thermal {
        case .nominal: break
        case .fair: reasons.append(Reason(id: "thermal", level: .caution, message: "The Mac is warming up"))
        case .serious, .critical: reasons.append(Reason(id: "thermal", level: .unsafe, message: "The Mac is running hot"))
        }

        if snapshot.power?.isOnAC == true, snapshot.drainingOnACFraction >= t.drainingFractionUnsafe {
            reasons.append(Reason(
                id: "draining",
                level: .unsafe,
                message: "Draining the battery while on the charger"
            ))
        }

        if snapshot.memory != .normal {
            reasons.append(Reason(id: "memory", level: .caution, message: "Memory is under pressure"))
        } else if snapshot.swapGrowthBytes >= t.swapGrowthCautionBytes {
            reasons.append(Reason(id: "swap", level: .caution, message: "Swap use is growing"))
        }

        reasons.sort { $0.level > $1.level }
        return Verdict(level: reasons.map(\.level).max() ?? .safe, reasons: reasons)
    }
}
