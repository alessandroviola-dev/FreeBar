import AppKit

@MainActor
final class StorageMonitor {
    var onChange: ((String) -> Void)?
    private let queue = DispatchQueue(label: "com.alessandroviola.freebar.storage", qos: .utility)
    private let read: @Sendable (Bool) -> [StorageVolume]
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var active = false
    private var inFlight = false
    private var pendingRefresh = false
    private var pendingDiscovery = false
    private var lastTitle: String?
    private var generation: UInt = 0

    init(read: @escaping @Sendable (Bool) -> [StorageVolume] = {
        [reader = StorageReader()] in reader.read(rediscover: $0)
    }) {
        self.read = read
    }

    func start() {
        guard !active else { return }
        active = true
        let generation = generation
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification,
                     NSWorkspace.didRenameVolumeNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self, self.generation == generation else { return }
                    self.refresh(rediscover: true)
                }
            })
        }
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.generation == generation else { return }
                self.refresh(rediscover: false)
            }
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
        let read = read
        let generation = generation
        queue.async { [weak self] in
            let title = StorageFormatter.title(read(rediscover))
            DispatchQueue.main.async { [weak self] in
                guard let self, self.active, self.generation == generation else { return }
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
        generation &+= 1
        inFlight = false
        pendingRefresh = false
        pendingDiscovery = false
        lastTitle = nil
        timer?.invalidate()
        timer = nil
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        // Keep the configured callback for a later start; old work is generation-gated.
    }
}
