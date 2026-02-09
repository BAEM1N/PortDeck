import Foundation
import Darwin

struct SystemSnapshot: Sendable {
    var cpuPercent: Double
    var memoryUsedBytes: UInt64
    var memoryTotalBytes: UInt64
    var diskUsedBytes: UInt64
    var diskTotalBytes: UInt64

    static let empty = SystemSnapshot(
        cpuPercent: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        diskUsedBytes: 0,
        diskTotalBytes: 0
    )

    var memoryPercent: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return min(max(Double(memoryUsedBytes) / Double(memoryTotalBytes) * 100, 0), 100)
    }

    var diskPercent: Double {
        guard diskTotalBytes > 0 else { return 0 }
        return min(max(Double(diskUsedBytes) / Double(diskTotalBytes) * 100, 0), 100)
    }
}

private struct CPUTicks: Sendable {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64
}

private struct SnapshotResult: Sendable {
    let snapshot: SystemSnapshot
    let ticks: CPUTicks?
}

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.empty

    private var timer: Timer?
    private var previousTicks: CPUTicks?

    func start() {
        guard timer == nil else { return }

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let previous = previousTicks

        Task {
            let result = await Task.detached(priority: .utility) {
                Self.collectSnapshot(previousTicks: previous)
            }.value

            snapshot = result.snapshot
            previousTicks = result.ticks
        }
    }

    private nonisolated static func collectSnapshot(previousTicks: CPUTicks?) -> SnapshotResult {
        let cpu = collectCPU(previousTicks: previousTicks)
        let memory = collectMemory()
        let disk = collectDisk()

        return SnapshotResult(
            snapshot: SystemSnapshot(
                cpuPercent: cpu.percent,
                memoryUsedBytes: memory.used,
                memoryTotalBytes: memory.total,
                diskUsedBytes: disk.used,
                diskTotalBytes: disk.total
            ),
            ticks: cpu.ticks
        )
    }

    private nonisolated static func collectCPU(previousTicks: CPUTicks?) -> (percent: Double, ticks: CPUTicks?) {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

        let status: kern_return_t = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }

        guard status == KERN_SUCCESS else {
            return (0, previousTicks)
        }

        let current = CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )

        guard let previousTicks else {
            return (0, current)
        }

        let userDelta = current.user &- previousTicks.user
        let systemDelta = current.system &- previousTicks.system
        let idleDelta = current.idle &- previousTicks.idle
        let niceDelta = current.nice &- previousTicks.nice

        let totalDelta = userDelta + systemDelta + idleDelta + niceDelta
        guard totalDelta > 0 else {
            return (0, current)
        }

        let usedDelta = totalDelta - idleDelta
        let percent = Double(usedDelta) / Double(totalDelta) * 100
        return (min(max(percent, 0), 100), current)
    }

    private nonisolated static func collectMemory() -> (used: UInt64, total: UInt64) {
        let total = ProcessInfo.processInfo.physicalMemory

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let status: kern_return_t = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard status == KERN_SUCCESS else {
            return (0, total)
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize)

        let active = UInt64(vmStats.active_count) * page
        let wired = UInt64(vmStats.wire_count) * page
        let compressed = UInt64(vmStats.compressor_page_count) * page
        let used = min(active + wired + compressed, total)

        return (used, total)
    }

    private nonisolated static func collectDisk() -> (used: UInt64, total: UInt64) {
        guard
            let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
            let totalValue = attributes[.systemSize] as? NSNumber,
            let freeValue = attributes[.systemFreeSize] as? NSNumber
        else {
            return (0, 0)
        }

        let total = totalValue.uint64Value
        let free = freeValue.uint64Value
        let used = total >= free ? (total - free) : 0
        return (used, total)
    }
}
