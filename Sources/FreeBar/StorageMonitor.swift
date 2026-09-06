import AppKit

@MainActor
final class StorageMonitor {
    var onChange: ((String) -> Void)?
    private let queue = DispatchQueue(label: "com.alessandroviola.freebar.storage", qos: .utility)
    private let reader = StorageReader()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var active = false
    private var inFlight = false
    private var pendingRefresh = false
    private var pendingDiscovery = false
    private var lastTitle: String?

    func start() {
        guard !active else { return }
        active = true
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
                     NSWorkspace.didRenameVolumeNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.async { self?.refresh(rediscover: true) }
            })
        }
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.refresh(rediscover: false) }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh(rediscover: true)
    }

    func refresh(rediscover: Bool = true) {
        guard active else { return }
        if inFlight {
            // Coalesce bursts of mount events/manual clicks; never overlap disk reads.
            pendingRefresh = true
            pendingDiscovery = pendingDiscovery || rediscover
            return
        }
        inFlight = true
        let reader = reader
        queue.async { [weak self] in
            let title = StorageFormatter.title(reader.read(rediscover: rediscover))
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active else { return }
                self.inFlight = false
                if !self.pendingDiscovery, title != self.lastTitle {
                    self.lastTitle = title
                    self.onChange?(title)
                }
                if self.pendingRefresh {
                    let discover = self.pendingDiscovery
                    self.pendingRefresh = false
                    self.pendingDiscovery = false
                    self.refresh(rediscover: discover)
                }
            }
        }
    }

    func stop() {
        active = false
        timer?.invalidate()
        timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        onChange = nil
    }
}
