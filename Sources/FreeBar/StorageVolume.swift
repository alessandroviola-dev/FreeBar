import Foundation

struct StorageVolume: Equatable {
    let id: String
    let name: String
    let availableBytes: Int64?
    let isMac: Bool

    static func ordered(_ volumes: [StorageVolume]) -> [StorageVolume] {
        volumes.sorted {
            if $0.isMac != $1.isMac { return $0.isMac }
            let left = $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            let right = $1.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            return left == right ? $0.id < $1.id : left < right
        }
    }
}

enum StorageFormatter {
    static func capacity(_ bytes: Int64?) -> String {
        guard let bytes, bytes >= 0 else { return "?" }
        let value = Double(bytes)
        if bytes == 0 { return "0M" }
        if value < 1_000_000 { return "<1M" }
        // Decimal SI units match Finder. Promote at rounding boundaries, not to 1000G.
        if value < 999_500_000 {
            return "\(Int((value / 1_000_000).rounded()))M"
        }
        if value < 999_500_000_000 {
            return "\(Int((value / 1_000_000_000).rounded()))G"
        }
        var number = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value / 1_000_000_000_000)
        while number.last == "0" { number.removeLast() }
        if number.last == "." { number.removeLast() }
        return number + "T"
    }

    static func name(_ name: String, limit: Int = 12) -> String {
        // Strip controls and direction overrides, but preserve emoji joiners/graphemes.
        let scalars = name.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) || $0.value == 0x200D || $0.value == 0x200C
        }
        let cleaned = String(String.UnicodeScalarView(scalars))
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .replacingOccurrences(of: "|", with: "-")
        let display = cleaned.isEmpty ? "Drive" : cleaned
        guard limit > 1 else { return "…" }
        return display.count <= limit ? display : String(display.prefix(limit - 1)) + "…"
    }

    static func title(_ volumes: [StorageVolume]) -> String {
        StorageVolume.ordered(volumes).map {
            "\($0.isMac ? "Mac" : name($0.name)) \(capacity($0.availableBytes))"
        }.joined(separator: " | ")
    }
}

struct VolumeMetadata {
    var path: String
    var isLocal: Bool
    var isBrowsable: Bool
    var isHidden: Bool
    var isInternal: Bool?
    var isRemovable: Bool
    var isEjectable: Bool
    var deviceProtocol: String?
    var hasPhysicalBacking = false

    var isRelevantExternal: Bool {
        guard isLocal, isBrowsable, !isHidden,
              path != "/", path != "/System", !path.hasPrefix("/System/"),
              isInternal == false || isRemovable || isEjectable,
              let deviceProtocol, deviceProtocol != "Virtual Interface" else { return false }
        // Unknown transports require hardware ancestry, not merely ejectability (DMGs
        // are ejectable too). Known transports retain the existing classification.
        return ["USB", "FireWire", "Thunderbolt", "PCI-Express", "PCI", "SATA",
                "ATA", "ATAPI", "SCSI", "Secure Digital", "Apple Fabric"]
            .contains(deviceProtocol) || hasPhysicalBacking
    }
}
