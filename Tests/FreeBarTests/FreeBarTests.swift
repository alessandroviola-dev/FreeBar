import XCTest
@testable import FreeBar

final class FreeBarTests: XCTestCase {
    func testDecimalCapacity() {
        let cases: [(Int64?, String)] = [
            (nil, "?"), (-1, "?"), (0, "0M"), (1, "<1M"), (999_999, "<1M"),
            (1_000_000, "1M"), (983_000_000, "983M"), (999_499_999, "999M"),
            (999_500_000, "1G"), (28_000_000_000, "28G"), (183_400_000_000, "183G"),
            (183_600_000_000, "184G"), (742_000_000_000, "742G"),
            (999_499_999_999, "999G"), (999_500_000_000, "1T"),
            (1_200_000_000_000, "1.2T"), (1_420_000_000_000, "1.42T"),
            (Int64.max, "9223372.04T")
        ]
        for (bytes, expected) in cases { XCTAssertEqual(StorageFormatter.capacity(bytes), expected, "\(String(describing: bytes))") }
    }

    func testNamesAndUnicode() {
        XCTAssertEqual(StorageFormatter.name("T7"), "T7")
        XCTAssertEqual(StorageFormatter.name("Extreme SSD"), "Extreme SSD")
        XCTAssertEqual(StorageFormatter.name("Samsung Portable SSD T7 Shield"), "Samsung Por…")
        XCTAssertEqual(StorageFormatter.name("   "), "Drive")
        XCTAssertEqual(StorageFormatter.name("a|b\u{202E}\u{0000}"), "a-b")
        let emoji = String(repeating: "👨‍👩‍👧‍👦", count: 20)
        XCTAssertEqual(StorageFormatter.name(emoji), String(repeating: "👨‍👩‍👧‍👦", count: 11) + "…")
        let combining = String(repeating: "e\u{301}", count: 20)
        XCTAssertEqual(StorageFormatter.name(combining).count, 12)
    }

    func testOrderingAndTitle() {
        let volumes = [
            StorageVolume(id: "z", name: "usb", availableBytes: 18_000_000_000, isMac: false),
            StorageVolume(id: "b", name: "T7", availableBytes: 742_000_000_000, isMac: false),
            StorageVolume(id: "mac", name: "Macintosh HD", availableBytes: 183_000_000_000, isMac: true),
            StorageVolume(id: "a", name: "t7", availableBytes: 28_000_000_000, isMac: false)
        ]
        XCTAssertEqual(StorageVolume.ordered(volumes).map(\.id), ["mac", "a", "b", "z"])
        XCTAssertEqual(StorageFormatter.title(volumes), "Mac 183G | t7 28G | T7 742G | usb 18G")
        XCTAssertEqual(StorageFormatter.title(volumes.reversed()), StorageFormatter.title(volumes))
    }

    func testPhysicalVolumeFiltering() {
        let physical = VolumeMetadata(path: "/Volumes/Recovery", isLocal: true, isBrowsable: true,
                                      isHidden: false, isInternal: false, isRemovable: false,
                                      isEjectable: false, deviceProtocol: "USB")
        // Names are not blacklisted: a real user disk may legitimately be called Recovery.
        XCTAssertTrue(physical.isRelevantExternal)
        for transport in ["USB", "Thunderbolt", "Secure Digital", "FireWire", "PCI-Express"] {
            var value = physical
            value.deviceProtocol = transport
            XCTAssertTrue(value.isRelevantExternal)
        }
        var rejected: [VolumeMetadata] = []
        var value = physical; value.isLocal = false; rejected.append(value)
        value = physical; value.isBrowsable = false; rejected.append(value)
        value = physical; value.isHidden = true; rejected.append(value)
        value = physical; value.isInternal = true; rejected.append(value)
        value = physical; value.isInternal = nil; rejected.append(value)
        value = physical; value.deviceProtocol = nil; rejected.append(value)
        value = physical; value.deviceProtocol = "Virtual Interface"; value.isEjectable = true; rejected.append(value)
        value = physical; value.deviceProtocol = "Unknown"; rejected.append(value)
        value = physical; value.path = "/"; rejected.append(value)
        value = physical; value.path = "/System/Volumes/Preboot"; rejected.append(value)
        for candidate in rejected { XCTAssertFalse(candidate.isRelevantExternal, "\(candidate)") }
        value = physical; value.isInternal = true; value.isRemovable = true
        XCTAssertTrue(value.isRelevantExternal, "Built-in SD readers can report internal transport")
    }

    func testUnknownTransportRequiresPhysicalBacking() {
        var volume = VolumeMetadata(path: "/Volumes/Future", isLocal: true, isBrowsable: true,
                                    isHidden: false, isInternal: false, isRemovable: true,
                                    isEjectable: true, deviceProtocol: "Future Transport")
        XCTAssertFalse(volume.isRelevantExternal, "External/ejectable/removable alone is not proof")
        volume.hasPhysicalBacking = true
        XCTAssertTrue(volume.isRelevantExternal)
        // Even convincing hardware evidence must never override these exclusions.
        var rejected = volume; rejected.deviceProtocol = "Virtual Interface"
        XCTAssertFalse(rejected.isRelevantExternal)
        rejected = volume; rejected.isLocal = false
        XCTAssertFalse(rejected.isRelevantExternal)
        rejected = volume; rejected.isInternal = true; rejected.isRemovable = false; rejected.isEjectable = false
        XCTAssertFalse(rejected.isRelevantExternal)
        rejected = volume; rejected.deviceProtocol = nil
        XCTAssertFalse(rejected.isRelevantExternal)
        rejected = volume; rejected.isInternal = nil; rejected.isRemovable = false; rejected.isEjectable = false
        XCTAssertFalse(rejected.isRelevantExternal)
    }

    func testPrivacyManifestSchemaAndReasons() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/PrivacyInfo.xcprivacy"))
        var format = PropertyListSerialization.PropertyListFormat.xml
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: &format) as? [String: Any])
        XCTAssertEqual(format, .xml)
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(try XCTUnwrap(plist["NSPrivacyTrackingDomains"] as? [String]), [])
        XCTAssertTrue(try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]]).isEmpty)
        let declarations = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        // Apple NSPrivacyAccessedAPITypeReasons documentation: display disk space;
        // measure elapsed time between in-app events. No write-space or tracking reason.
        let expected = ["NSPrivacyAccessedAPICategoryDiskSpace": ["85F4.1"],
                        "NSPrivacyAccessedAPICategorySystemBootTime": ["35F9.1"]]
        var actual: [String: [String]] = [:]
        for declaration in declarations {
            let category = try XCTUnwrap(declaration["NSPrivacyAccessedAPIType"] as? String)
            XCTAssertNil(actual[category], "Duplicate API category")
            actual[category] = try XCTUnwrap(declaration["NSPrivacyAccessedAPITypeReasons"] as? [String])
        }
        XCTAssertEqual(actual, expected)
    }

    func testLiveMacAndRepeatedReads() throws {
        let reader = StorageReader()
        let initial = reader.read(rediscover: true)
        XCTAssertEqual(initial.first?.id, "mac")
        XCTAssertEqual(initial.filter(\.isMac).count, 1)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(initial.first?.availableBytes), 0)
        XCTAssertEqual(Set(initial.map(\.id)).count, initial.count)
        for _ in 0..<10 {
            let result = reader.read(rediscover: false)
            XCTAssertEqual(result.filter(\.isMac).count, 1)
            XCTAssertEqual(result.first?.name, "Mac")
        }
        print("Live storage: \(StorageFormatter.title(initial))")
    }
}
