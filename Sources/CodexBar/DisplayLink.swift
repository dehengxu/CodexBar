import AppKit
import Combine
import CoreVideo
import QuartzCore

/// Minimal display link driver using CVDisplayLink.
/// Publishes ticks on the main thread at the requested frame rate.
@MainActor
final class DisplayLinkDriver: ObservableObject {
    // Published counter used to drive SwiftUI updates.
    @Published var tick: Int = 0
    private var cvDisplayLink: CVDisplayLink?
    private var targetInterval: CFTimeInterval = 1.0 / 60.0
    private var lastTickTimestamp: CFTimeInterval = 0
    private let onTick: (() -> Void)?

    init(onTick: (() -> Void)? = nil) {
        self.onTick = onTick
    }

    func start(fps: Double = 12) {
        guard self.cvDisplayLink == nil else { return }
        let clampedFps = max(fps, 1)
        self.targetInterval = 1.0 / clampedFps
        self.lastTickTimestamp = 0
        self.startCVDisplayLink()
    }

    func stop() {
        if let cvDisplayLink = self.cvDisplayLink {
            CVDisplayLinkStop(cvDisplayLink)
        }
        self.cvDisplayLink = nil
    }

    private func handleTick() {
        let now = CACurrentMediaTime()
        if self.lastTickTimestamp > 0, now - self.lastTickTimestamp < self.targetInterval {
            return
        }
        self.lastTickTimestamp = now
        // Safe on main runloop; drives SwiftUI updates.
        self.tick &+= 1
        self.onTick?()
    }

    private func startCVDisplayLink() {
        var link: CVDisplayLink?
        if CVDisplayLinkCreateWithActiveCGDisplays(&link) != kCVReturnSuccess {
            return
        }
        guard let link else { return }
        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
            guard let userInfo else { return kCVReturnSuccess }
            let driver = Unmanaged<DisplayLinkDriver>.fromOpaque(userInfo).takeUnretainedValue()
            driver.scheduleTick()
            return kCVReturnSuccess
        }
        CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
        self.cvDisplayLink = link
    }

    private nonisolated func scheduleTick() {
        Task { @MainActor [weak self] in
            self?.handleTick()
        }
    }

    deinit {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
}
