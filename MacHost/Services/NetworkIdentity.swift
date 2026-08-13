import Foundation
import SystemConfiguration
import Darwin

/// Identité réseau du Mac, transmise à l'iPhone lors de l'appairage pour
/// permettre le réveil à distance (Wake on LAN).
enum NetworkIdentity {

    /// Adresse MAC de l'interface active, au format `aa:bb:cc:dd:ee:ff`.
    ///
    /// On privilégie l'Ethernet quand il existe : le Wi-Fi ne réveille le Mac
    /// que sur les modèles récents et avec « Réveil pour l'accès réseau »
    /// activé, alors que l'Ethernet le fait toujours.
    static func macAddress() -> String? {
        let preferred = ["en0", "en1", "en2", "en3"]
        let addresses = allHardwareAddresses()

        for name in preferred {
            if let address = addresses[name] { return address }
        }
        return addresses.values.sorted().first
    }

    /// Adresse de diffusion du réseau local, cible du paquet magique.
    static func broadcastAddress() -> String? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(pointer) }

        var result: String?
        var current: UnsafeMutablePointer<ifaddrs>? = first

        while let interface = current {
            defer { current = interface.pointee.ifa_next }

            let flags = Int32(interface.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  flags & IFF_LOOPBACK == 0,
                  flags & IFF_BROADCAST != 0,
                  interface.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_INET),
                  let broadcast = interface.pointee.ifa_dstaddr else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(broadcast, socklen_t(broadcast.pointee.sa_len),
                              &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }

            let name = String(cString: interface.pointee.ifa_name)
            let address = String(cString: host)
            // en0 d'abord : c'est l'interface principale sur un Mac.
            if name == "en0" { return address }
            if result == nil { result = address }
        }
        return result
    }

    // MARK: - Lecture des adresses matérielles

    private static func allHardwareAddresses() -> [String: String] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [:] }
        defer { freeifaddrs(pointer) }

        var results: [String: String] = [:]
        var current: UnsafeMutablePointer<ifaddrs>? = first

        while let interface = current {
            defer { current = interface.pointee.ifa_next }

            guard interface.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                  Int32(interface.pointee.ifa_flags) & IFF_LOOPBACK == 0,
                  let data = interface.pointee.ifa_addr else { continue }

            let name = String(cString: interface.pointee.ifa_name)

            let formatted: String? = data.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { link in
                // Une adresse MAC fait 6 octets ; les interfaces virtuelles en
                // ont souvent 0, il faut les écarter.
                guard link.pointee.sdl_alen == 6 else { return nil }

                var bytes = [UInt8](repeating: 0, count: 6)
                withUnsafePointer(to: link.pointee.sdl_data) { tuple in
                    tuple.withMemoryRebound(to: CChar.self, capacity: 32) { chars in
                        let offset = Int(link.pointee.sdl_nlen)
                        for index in 0..<6 {
                            bytes[index] = UInt8(bitPattern: chars[offset + index])
                        }
                    }
                }
                return bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
            }

            if let formatted { results[name] = formatted }
        }
        return results
    }
}
