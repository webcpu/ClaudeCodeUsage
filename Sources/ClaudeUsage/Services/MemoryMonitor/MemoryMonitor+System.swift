//
//  MemoryMonitor+System.swift
//
//  System memory infrastructure for low-level memory queries.
//

import Foundation

// MARK: - System Memory Infrastructure

enum SystemMemory {
    struct Info {
        let total: Int64
        let free: Int64
    }

    static func fetchTaskFootprint() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }

    static func fetchSystemInfo() -> Info {
        let totalMemory = Int64(ProcessInfo.processInfo.physicalMemory)

        // Use getpagesize() which is thread-safe and avoids Swift 6 concurrency issues
        let pageSize = vm_size_t(getpagesize())

        var vmStats = vm_statistics64()
        var vmStatsSize = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<natural_t>.size
        )

        let hostPort = mach_host_self()
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmStatsSize)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &vmStatsSize)
            }
        }

        let freeMemory = result == KERN_SUCCESS
            ? Int64(vmStats.free_count) * Int64(pageSize)
            : totalMemory / 2

        return Info(total: totalMemory, free: freeMemory)
    }
}
