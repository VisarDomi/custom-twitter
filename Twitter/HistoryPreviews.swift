import UIKit
import WebKit

// WebKit's serialized interactionState contains history, but not its swipe images.
// Supply a saved viewport only when WebKit has no image of its own.
final class HistoryPreviewWebView: WKWebView {
    var preview: ((Bool) -> CGImage?)?
    private weak var activePreview: UIView?

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        DispatchQueue.main.async { [weak self, weak subview] in
            if let subview { self?.prepareSnapshot(in: subview) }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for child in subviews where isGestureSurface(child) { prepareSnapshot(in: child) }
    }

    private func isGestureSurface(_ view: UIView) -> Bool {
        view.layer.name == "SwipeSnapshot" || view.layer.name == "SwipeTransitionContainer"
    }

    var isShowingHistoryPreview: Bool {
        activePreview?.window != nil || subviews.contains { isGestureSurface($0) && !$0.isHidden && $0.window != nil }
    }

    private func prepareSnapshot(in root: UIView) {
        func visit(_ candidate: UIView) {
            // This is WebKit's transient gesture surface, not the page or media.
            // Keep its own image whenever one is available.
            if candidate.layer.name == "SwipeSnapshot" {
                activePreview = candidate
                candidate.backgroundColor = .black
                if candidate.layer.contents == nil, let back = direction(for: candidate), let image = preview?(back) {
                    candidate.layer.contents = image
                    candidate.layer.contentsScale = 1
                    candidate.layer.contentsGravity = .resizeAspect
                }
                return
            }
            for child in candidate.subviews { visit(child) }
        }
        visit(root)
    }

    private func direction(for snapshot: UIView) -> Bool? {
        let leftToRight = effectiveUserInterfaceLayoutDirection != .rightToLeft
        func panDirection(in view: UIView) -> Bool? {
            for recognizer in view.gestureRecognizers ?? [] where recognizer.state == .began || recognizer.state == .changed {
                if let pan = recognizer as? UIPanGestureRecognizer {
                    let delta = pan.translation(in: self)
                    if abs(delta.x) > max(0.5, abs(delta.y)) { return (delta.x > 0) == leftToRight }
                }
            }
            for child in view.subviews { if let direction = panDirection(in: child) { return direction } }
            return nil
        }
        if let direction = panDirection(in: window ?? self) { return direction }
        let x = snapshot.convert(snapshot.bounds, to: self).minX
        guard abs(x) > 0.5 else { return nil }
        return (x < 0) == leftToRight
    }
}

@MainActor
final class HistoryPreviews: NSObject {
    private struct Image: Codable {
        var index: Int
        let url: String
        let originalURL: String
        let jpeg: Data
    }
    private struct Checkpoint: Codable {
        let state: Data
        let history: [String]
        let images: [Image]
    }

    private weak var webView: WKWebView?
    private let path: URL
    private var observation: NSKeyValueObservation?
    private var capture: DispatchWorkItem?
    private var inFlight = false
    private var captureAgain = false
    private var checkpoint: (() -> Void)?
    private var images: [WKBackForwardListItem: Image] = [:]
    private var recent: [WKBackForwardListItem] = []
    private var restored: Checkpoint?

    init(_ webView: WKWebView, session: URL) {
        self.webView = webView
        path = session.appendingPathExtension("previews")
        super.init()
        observation = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.scheduleCapture() }
        }
        webView.scrollView.panGestureRecognizer.addTarget(self, action: #selector(didScroll(_:)))
        webView.scrollView.pinchGestureRecognizer?.addTarget(self, action: #selector(didScroll(_:)))
    }

    private var history: [WKBackForwardListItem] {
        guard let list = webView?.backForwardList, let current = list.currentItem else { return [] }
        return list.backList + [current] + list.forwardList
    }

    func restore(matching state: Data) {
        guard let data = try? Data(contentsOf: path),
              let checkpoint = try? PropertyListDecoder().decode(Checkpoint.self, from: data),
              checkpoint.state == state else { return }
        restored = checkpoint
        bindRestoredImages()
    }

    func didFinish() {
        bindRestoredImages()
        restored = nil
        scheduleCapture()
    }

    private func bindRestoredImages() {
        guard let restored, restored.history == history.map({ $0.url.absoluteString }) else { return }
        let items = history
        for image in restored.images.suffix(8) where items.indices.contains(image.index) {
            let item = items[image.index]
            if item.url.absoluteString == image.url && item.initialURL.absoluteString == image.originalURL {
                images[item] = image
                recent.append(item)
            }
        }
        self.restored = nil
    }

    func save(matching state: Data) {
        let items = history
        let saved = items.enumerated().compactMap { index, item -> Image? in
            guard var image = images[item], image.url == item.url.absoluteString else { return nil }
            image.index = index
            return image
        }
        let checkpoint = Checkpoint(state: state, history: items.map { $0.url.absoluteString }, images: saved)
        do {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            try encoder.encode(checkpoint).write(to: path, options: .atomic)
        } catch { print("WebKit preview checkpoint:", error) }
    }

    func image(back: Bool) -> CGImage? {
        guard let list = webView?.backForwardList, let item = back ? list.backItem : list.forwardItem,
              let image = images[item], image.url == item.url.absoluteString else { return nil }
        guard let decoded = UIImage(data: image.jpeg)?.cgImage else {
            images.removeValue(forKey: item)
            recent.removeAll { $0 === item }
            return nil
        }
        return decoded
    }

    func captureForCheckpoint(_ completion: @escaping () -> Void) {
        checkpoint = completion
        capture?.cancel()
        captureViewport()
    }

    private func finishCheckpoint() {
        let completion = checkpoint
        checkpoint = nil
        completion?()
    }

    @objc private func didScroll(_ gesture: UIGestureRecognizer) {
        if gesture.state == .ended { scheduleCapture(after: 0.8) }
    }

    private func scheduleCapture(after delay: TimeInterval = 1) {
        capture?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.captureViewport() }
        capture = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func captureViewport() {
        guard let webView, !webView.isLoading, webView.window != nil,
              Site.matches(webView.url, Site.ownHosts), let item = webView.backForwardList.currentItem,
              !((webView as? HistoryPreviewWebView)?.isShowingHistoryPreview ?? false),
              !webView.scrollView.isTracking, !webView.scrollView.isDragging,
              !webView.scrollView.isDecelerating, !webView.scrollView.isZooming,
              !hasActiveGesture(in: webView),
              webView.bounds.width >= 32, webView.bounds.height >= 32 else { finishCheckpoint(); return }
        let width = min(428, webView.bounds.width)
        let size = CGSize(width: width, height: width * webView.bounds.height / webView.bounds.width)
        guard size.height <= 2048 else { finishCheckpoint(); return }
        guard !inFlight else { captureAgain = true; return }
        inFlight = true
        let url = item.url
        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = NSNumber(value: Double(width))
        webView.takeSnapshot(with: configuration) { [weak self, weak webView] snapshot, _ in
            guard let self else { return }
            defer {
                self.inFlight = false
                if self.captureAgain { self.captureAgain = false; self.scheduleCapture() }
                else { self.finishCheckpoint() }
            }
            guard let webView, let snapshot, webView.backForwardList.currentItem === item,
                  webView.url == url, !webView.isLoading else { return }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.black.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                snapshot.draw(in: CGRect(origin: .zero, size: size))
            }
            guard let jpeg = image.jpegData(compressionQuality: 0.75) else { return }
            self.images[item] = Image(index: 0, url: url.absoluteString,
                                      originalURL: item.initialURL.absoluteString, jpeg: jpeg)
            self.recent.removeAll { $0 === item }
            self.recent.append(item)
            let valid = Set(self.history)
            self.recent.removeAll { !valid.contains($0) }
            while self.recent.count > 8 { self.recent.removeFirst() }
            self.images = self.images.filter { self.recent.contains($0.key) }
        }
    }

    private func hasActiveGesture(in view: UIView) -> Bool {
        if view.gestureRecognizers?.contains(where: { $0.state == .began || $0.state == .changed }) == true { return true }
        return view.subviews.contains { hasActiveGesture(in: $0) }
    }
}
