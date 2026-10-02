import Darwin

enum MemoryPressure: Int, Sendable {
    case normal = 1
    case warning = 2
    case critical = 4
}

enum MemoryReader {
    private static let host = mach_host_self()

    static func pressure() -> MemoryPressure {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return .normal }
        return MemoryPressure(rawValue: Int(level)) ?? .normal
    }

    // Matches Activity Monitor's "Memory Used": app memory + wired + compressed.
    static func usage() -> (used: UInt64, total: UInt64) {
        var total: UInt64 = 0
        var totalSize = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &totalSize, nil, 0)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, total) }
        let pageSize = UInt64(getpagesize())
        let appPages = UInt64(stats.internal_page_count) - UInt64(min(stats.purgeable_count, stats.internal_page_count))
        let used = (appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * pageSize
        return (min(used, total), total)
    }

    static func swapUsedBytes() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return 0 }
        return usage.xsu_used
    }
}
