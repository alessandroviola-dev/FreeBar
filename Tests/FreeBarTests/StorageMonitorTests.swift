import AppKit
import XCTest
import os
@testable import FreeBar

final class StorageMonitorTests: XCTestCase {
    private struct Reads {
        var count = 0
        var active = 0
        var maximumActive = 0
        var discovery: [Bool] = []
    }

    @MainActor
    func testRestartRejectsInFlightResultAndClearsPendingWork() async {
        let entered = expectation(description: "First read entered")
        let updated = expectation(description: "Restarted run emitted")
        let release = DispatchSemaphore(value: 0)
        let reads = OSAllocatedUnfairLock(initialState: Reads())
        let monitor = StorageMonitor { discover in
            XCTAssertFalse(Thread.isMainThread)
            let count = reads.withLock {
                $0.count += 1; $0.active += 1
                $0.maximumActive = max($0.maximumActive, $0.active)
                $0.discovery.append(discover)
                return $0.count
            }
            defer { reads.withLock { $0.active -= 1 } }
            if count == 1 {
                entered.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            }
            return [StorageVolume(id: "mac", name: "Mac", availableBytes: count == 1 ? 99_000_000_000 : 42_000_000_000, isMac: true)]
        }
        defer { release.signal(); monitor.stop() }
        var titles: [String] = []
        monitor.onChange = {
            XCTAssertTrue(Thread.isMainThread)
            titles.append($0)
            updated.fulfill()
        }
        monitor.start()
        await fulfillment(of: [entered], timeout: 2)
        monitor.refresh() // Leave both pending flags set in the old run.
        monitor.stop()
        monitor.start() // The old read is still blocked on the same serial queue.
        release.signal()
        await fulfillment(of: [updated], timeout: 2)
        XCTAssertEqual(titles, ["Mac 42G"], "Old Mac 99G must never escape into the new run")
        XCTAssertEqual(reads.withLock { $0.count }, 2)
        XCTAssertEqual(reads.withLock { $0.maximumActive }, 1)
        XCTAssertEqual(reads.withLock { $0.discovery }, [true, true])
    }

    @MainActor
    func testBurstCoalescesDiscoveryAndDoesNotReemitUnchangedTitle() async {
        let entered = expectation(description: "First read entered")
        let updated = expectation(description: "Coalesced discovery emitted")
        let thirdRead = expectation(description: "Unchanged read executed")
        let unexpectedUpdate = expectation(description: "Unchanged title must not be reassigned")
        unexpectedUpdate.isInverted = true
        let release = DispatchSemaphore(value: 0)
        let reads = OSAllocatedUnfairLock(initialState: Reads())
        let monitor = StorageMonitor { discover in
            XCTAssertFalse(Thread.isMainThread)
            let count = reads.withLock {
                $0.count += 1; $0.active += 1
                $0.maximumActive = max($0.maximumActive, $0.active)
                $0.discovery.append(discover)
                return $0.count
            }
            defer { reads.withLock { $0.active -= 1 } }
            if count == 1 {
                entered.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            }
            if count == 3 { thirdRead.fulfill() }
            return [StorageVolume(id: "mac", name: "Mac", availableBytes: count == 1 ? 99_000_000_000 : 42_000_000_000, isMac: true)]
        }
        defer { release.signal(); monitor.stop() }
        monitor.onChange = { title in
            XCTAssertEqual(title, "Mac 42G")
            updated.fulfill()
        }
        monitor.start()
        await fulfillment(of: [entered], timeout: 2)
        for _ in 0..<20 { monitor.refresh(rediscover: false) }
        monitor.refresh(rediscover: true)
        monitor.refresh(rediscover: false) // Must not downgrade the pending discovery.
        release.signal()
        await fulfillment(of: [updated], timeout: 2)
        monitor.onChange = { _ in unexpectedUpdate.fulfill() }
        monitor.refresh(rediscover: false)
        await fulfillment(of: [thirdRead], timeout: 2)
        await fulfillment(of: [unexpectedUpdate], timeout: 0.15)
        XCTAssertEqual(reads.withLock { $0.discovery }, [true, true, false])
        XCTAssertEqual(reads.withLock { $0.maximumActive }, 1)
    }

    @MainActor
    func testIdleRestartReemitsTitleAndRetainsCallback() async {
        let first = expectation(description: "First run")
        let second = expectation(description: "Second run, same title")
        let monitor = StorageMonitor { _ in
            [StorageVolume(id: "mac", name: "Mac", availableBytes: 42_000_000_000, isMac: true)]
        }
        defer { monitor.stop() }
        var updates = 0
        monitor.onChange = { title in
            XCTAssertEqual(title, "Mac 42G")
            updates += 1
            (updates == 1 ? first : second).fulfill()
        }
        monitor.start()
        monitor.start() // Idempotent while active.
        await fulfillment(of: [first], timeout: 2)
        monitor.stop()
        monitor.stop()
        monitor.refresh() // Inactive refresh is ignored.
        monitor.start()
        await fulfillment(of: [second], timeout: 2)
        XCTAssertEqual(updates, 2)
    }
}
