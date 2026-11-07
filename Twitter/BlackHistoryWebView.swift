import UIKit
import WebKit

// Keep WebKit's native swipe navigation, with black instead of a stale page image.
final class BlackHistoryWebView: WKWebView {
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        DispatchQueue.main.async { [weak self, weak subview] in
            if let subview { self?.blackenHistorySurface(in: subview) }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for child in subviews where isHistorySurface(child) { blackenHistorySurface(in: child) }
    }

    private func isHistorySurface(_ view: UIView) -> Bool {
        view.layer.name == "SwipeSnapshot" || view.layer.name == "SwipeTransitionContainer"
    }

    var isShowingHistoryPreview: Bool {
        subviews.contains { isHistorySurface($0) && !$0.isHidden && $0.window != nil }
    }

    private func blackenHistorySurface(in root: UIView) {
        if root.layer.name == "SwipeSnapshot" {
            if root.backgroundColor != .black { root.backgroundColor = .black }
            if root.layer.contents != nil { root.layer.contents = nil }
            root.isOpaque = true
            return
        }
        for child in root.subviews { blackenHistorySurface(in: child) }
    }
}
