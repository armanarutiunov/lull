import Foundation

struct ProcessSample: Equatable, Sendable {
    let path: String
    let cpuTimeNanos: UInt64
}

struct PowerReading: Equatable, Sendable {
    let isOnAC: Bool
    let batteryPercent: Int
    let milliamps: Int
}

struct Sample: Equatable, Sendable {
    let uptimeNanos: UInt64
    let busyTicks: UInt32
    let totalTicks: UInt32
    let processes: [pid_t: ProcessSample]
    let power: PowerReading?
    let swapUsedBytes: UInt64
}
