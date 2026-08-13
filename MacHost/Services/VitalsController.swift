import Foundation
import AppKit
import IOKit.ps

/// Constantes système du Mac : batterie, disque, mémoire, processeur.
final class VitalsController {

    /// Instantané précédent des ticks processeur, pour calculer un pourcentage
    /// d'utilisation sur l'intervalle plutôt que depuis le démarrage.
    private var previousCPUTicks: (used: Double, total: Double)?

    func snapshot() -> MacVitals {
        let battery = batteryState()
        let disk = diskUsage()
        let memory = memoryUsage()

        return MacVitals(batteryPercent: battery.percent,
                         isCharging: battery.charging,
                         diskFreeGB: disk.free,
                         diskTotalGB: disk.total,
                         memoryUsedGB: memory.used,
                         memoryTotalGB: memory.total,
                         cpuPercent: cpuUsage(),
                         uptime: formattedUptime(),
                         hostName: Host.current().localizedName ?? "Mac")
    }

    // MARK: - Batterie

    private func batteryState() -> (percent: Int?, charging: Bool?) {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] else {
            return (nil, nil)
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }

            guard let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let max = info[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }

            let charging = info[kIOPSIsChargingKey] as? Bool
            return (Int((Double(current) / Double(max)) * 100), charging)
        }
        // Un Mac de bureau n'a pas de batterie : ce n'est pas une erreur.
        return (nil, nil)
    }

    // MARK: - Disque

    private func diskUsage() -> (free: Double, total: Double) {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ]) else { return (0, 0) }

        let gigabyte = 1_000_000_000.0
        let free = Double(values.volumeAvailableCapacityForImportantUsage ?? 0) / gigabyte
        let total = Double(values.volumeTotalCapacity ?? 0) / gigabyte
        return (free, total)
    }

    // MARK: - Mémoire

    private func memoryUsage() -> (used: Double, total: Double) {
        let gigabyte = 1_073_741_824.0
        let total = Double(ProcessInfo.processInfo.physicalMemory) / gigabyte

        var stats = vm_statistics64()
        var count = UInt32(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, total) }

        let pageSize = Double(vm_kernel_page_size)
        // « Mémoire utilisée » au sens du Moniteur d'activité : actives +
        // câblées + compressées (les pages libres et inactives ne comptent pas).
        let used = (Double(stats.active_count)
                    + Double(stats.wire_count)
                    + Double(stats.compressor_page_count)) * pageSize / gigabyte
        return (used, total)
    }

    // MARK: - Processeur

    private func cpuUsage() -> Double {
        // HOST_CPU_LOAD_INFO_COUNT n'est pas exposé à Swift : on le recalcule.
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size
                                           / MemoryLayout<integer_t>.size)
        var load = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let user = Double(load.cpu_ticks.0)
        let system = Double(load.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3)

        let used = user + system + nice
        let total = used + idle

        defer { previousCPUTicks = (used, total) }

        // Sans point de comparaison, on renverrait la moyenne depuis le
        // démarrage du Mac, qui ne veut rien dire.
        guard let previous = previousCPUTicks else { return 0 }
        let deltaUsed = used - previous.used
        let deltaTotal = total - previous.total
        guard deltaTotal > 0 else { return 0 }
        return min(max(deltaUsed / deltaTotal * 100, 0), 100)
    }

    // MARK: - Durée de fonctionnement

    private func formattedUptime() -> String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 { return "\(days) j \(hours) h" }
        if hours > 0 { return "\(hours) h \(minutes) min" }
        return "\(minutes) min"
    }
}
