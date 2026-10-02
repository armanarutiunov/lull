import Darwin
import Foundation

enum CPUReader {
    private static let host = mach_host_self()

    private static let nanosPerTick: Double = {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        return Double(timebase.numer) / Double(timebase.denom)
    }()

    static func machineTicks() -> (busy: UInt32, total: UInt32) {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        let (user, system, idle, nice) = load.cpu_ticks
        let busy = user &+ system &+ nice
        return (busy, busy &+ idle)
    }

    static func processes() -> [pid_t: ProcessSample] {
        let capacity = proc_listallpids(nil, 0) + 64
        var pids = [pid_t](repeating: 0, count: Int(capacity))
        let count = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard count > 0 else { return [:] }

        var result: [pid_t: ProcessSample] = [:]
        result.reserveCapacity(Int(count))
        for pid in pids.prefix(Int(count)) where pid > 0 {
            guard let cpuTime = cpuTimeNanos(of: pid), let path = executablePath(of: pid) else { continue }
            result[pid] = ProcessSample(path: path, cpuTimeNanos: cpuTime)
        }
        return result
    }

    // Fails with EPERM for processes owned by other users; those still count in machineTicks().
    private static func cpuTimeNanos(of pid: pid_t) -> UInt64? {
        var info = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard result == 0 else { return nil }
        return UInt64(Double(info.ri_user_time + info.ri_system_time) * nanosPerTick)
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(decoding: buffer.prefix(Int(length)).map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}
