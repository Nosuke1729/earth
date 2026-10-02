import Foundation
import Darwin
import IOKit.ps
import SimulationEngine

public protocol RealWorldInputProvider {
    func sample() -> RealWorldInfluence
}

/// Aggregate host counters only. No applications, files, location or user activity are inspected.
public final class LocalSystemInputProvider: RealWorldInputProvider {
    private var previousTicks: [UInt64]?
    public init() {}
    public func sample() -> RealWorldInfluence {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        var usage = 0.0
        if result == KERN_SUCCESS {
            let ticks = [UInt64(info.cpu_ticks.0), UInt64(info.cpu_ticks.1), UInt64(info.cpu_ticks.2), UInt64(info.cpu_ticks.3)]
            if let old = previousTicks {
                let deltas = zip(ticks, old).map { $0 >= $1 ? $0 - $1 : 0 }
                let total = deltas.reduce(0, +)
                if total > 0 { usage = 1 - Double(deltas[2]) / Double(total) }
            }
            previousTicks = ticks
        }
        var charging = false
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            charging = sources.contains { source in
                guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else { return false }
                return description[kIOPSIsChargingKey] as? Bool == true
            }
        }
        return RealWorldInfluence(cpuActivity: usage, isCharging: charging, uptimeSeconds: ProcessInfo.processInfo.systemUptime)
    }
}
