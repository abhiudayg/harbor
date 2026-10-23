import Foundation

public enum DestinationPolicy {
    public static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        guard let host = url.host?.lowercased(), !host.isEmpty else {
            return false
        }
        return !isInternal(host)
    }

    static func isInternal(_ host: String) -> Bool {
        if host == "localhost" || host.hasSuffix(".localhost") || host == "::1" || host == "[::1]" {
            return true
        }
        let privatePrefixes = ["127.", "10.", "192.168.", "169.254.", "0.0.0.0"]
        if privatePrefixes.contains(where: { host.hasPrefix($0) }) {
            return true
        }
        return isInCarrierBlock172(host)
    }

    private static func isInCarrierBlock172(_ host: String) -> Bool {
        let octets = host.split(separator: ".")
        guard octets.count == 4, octets[0] == "172", let second = Int(octets[1]) else {
            return false
        }
        return (16...31).contains(second)
    }
}
