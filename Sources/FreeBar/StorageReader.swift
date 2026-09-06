import Foundation
import DiskArbitration
import Darwin

// Confined to StorageMonitor's serial queue. No subprocesses or user-file access.
final class StorageReader: @unchecked Sendable {
    private struct MountedVolume {
        let url: URL
        let id: String
        let name: String
    }
    private let session = DASessionCreate(kCFAllocatorDefault)
    private var external: [MountedVolume] = []
    private var lastDiscovery = -Double.infinity

    func read(rediscover: Bool) -> [StorageVolume] {
        let now = ProcessInfo.processInfo.systemUptime
        // Rare fallback covers missed notifications or metadata not ready at mount time.
        if rediscover || now - lastDiscovery >= 60 {
            external = discover()
            lastDiscovery = now
        }
        // The writable Data volume is the main user filesystem on split APFS systems.
        // Do not enumerate its System/VM/Preboot siblings as separate Mac disks.
        let data = URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)
        let root = URL(fileURLWithPath: "/", isDirectory: true)
        let macBytes = Self.availableCapacity(at: data) ?? Self.availableCapacity(at: root)
        var result = [StorageVolume(id: "mac", name: "Mac", availableBytes: macBytes, isMac: true)]
        for volume in external {
            // Confirm this is still the same mount before reading: an unmounted URL can
            // otherwise resolve to the containing Mac filesystem and show a false value.
            guard Self.isSameMount(volume),
                  let bytes = Self.availableCapacity(at: volume.url),
                  Self.isSameMount(volume) else { continue }
            result.append(StorageVolume(id: volume.id, name: volume.name, availableBytes: bytes, isMac: false))
        }
        return StorageVolume.ordered(result)
    }

    private static func isSameMount(_ volume: MountedVolume) -> Bool {
        let fresh = URL(fileURLWithPath: volume.url.path, isDirectory: true)
        guard let values = try? fresh.resourceValues(forKeys: [.volumeUUIDStringKey, .isVolumeKey]) else { return false }
        return values.isVolume == true && values.volumeUUIDString == volume.id
    }

    static func availableCapacity(at url: URL) -> Int64? {
        // Important usage includes space macOS can reclaim (e.g. purgeable caches),
        // unlike opportunistic capacity. Fall back to immediately available bytes on
        // filesystems that do not implement the important-usage key. Fresh URLs avoid
        // Foundation resource-value caching across refreshes.
        let fresh = URL(fileURLWithPath: url.path, isDirectory: true)
        if let values = try? fresh.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let bytes = values.volumeAvailableCapacityForImportantUsage, bytes >= 0 { return bytes }
        if let values = try? fresh.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let bytes = values.volumeAvailableCapacity, bytes >= 0 { return Int64(bytes) }
        return nil
    }

    private func discover() -> [MountedVolume] {
        guard let session else { return [] }
        // MNT_NOWAIT reads the kernel's cached mount table, without probing network
        // shares. The reentrant variant owns its buffer rather than sharing static data.
        var buffer: UnsafeMutablePointer<statfs>?
        let count = getmntinfo_r_np(&buffer, MNT_NOWAIT)
        guard count > 0, let buffer else { return [] }
        defer { free(buffer) }
        var result: [MountedVolume] = []
        var seen = Set<String>()
        for index in 0..<Int(count) {
            var mount = buffer[index]
            guard mount.f_flags & UInt32(MNT_LOCAL) != 0,
                  mount.f_flags & UInt32(MNT_DONTBROWSE | MNT_AUTOMOUNTED) == 0 else { continue }
            let path = withUnsafePointer(to: &mount.f_mntonname) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
            }
            guard path != "/", !path.hasPrefix("/System/") else { continue }
            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
                  let description = DADiskCopyDescription(disk) as? [String: Any] else { continue }
            var metadata = VolumeMetadata(
                path: path,
                isLocal: description[kDADiskDescriptionVolumeNetworkKey as String] as? Bool == false,
                isBrowsable: true, isHidden: false,
                isInternal: description[kDADiskDescriptionDeviceInternalKey as String] as? Bool,
                isRemovable: description[kDADiskDescriptionMediaRemovableKey as String] as? Bool == true,
                isEjectable: description[kDADiskDescriptionMediaEjectableKey as String] as? Bool == true,
                deviceProtocol: description[kDADiskDescriptionDeviceProtocolKey as String] as? String
            )
            guard metadata.isRelevantExternal else { continue }
            guard let values = try? url.resourceValues(forKeys: [
                .volumeNameKey, .volumeUUIDStringKey, .volumeIsBrowsableKey, .isHiddenKey, .isVolumeKey
            ]), values.isVolume == true else { continue }
            metadata.isBrowsable = values.volumeIsBrowsable == true
            metadata.isHidden = values.isHidden != false
            guard metadata.isRelevantExternal, let id = values.volumeUUIDString,
                  seen.insert(id).inserted else { continue }
            result.append(MountedVolume(url: url, id: id, name: values.volumeName ?? url.lastPathComponent))
        }
        return result
    }
}
