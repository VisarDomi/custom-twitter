// x.com in a full-screen web view with Control Panel for Twitter
// (Vendor/control-panel-for-twitter, MIT) injected at document start.
// It removes promoted posts; the "For you" timeline stays.
import SafariServices
import UIKit
import WebKit

enum Site {
    static let home = URL(string: "https://x.com/home")!
    static let ownHosts = ["x.com", "twitter.com"]
    // Third-party sign-in pages that must stay inside the app's cookie store.
    static let loginHosts = ["appleid.apple.com", "accounts.google.com"]

    static func matches(_ url: URL?, _ hosts: [String]) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

enum ControlPanel {
    // Plain x.com apart from ads: keep "For you", inline retweets and counts.
    static let overrides: [String: Any] = [
        "hideForYouTimeline": false,
        "alwaysUseLatestTweets": false,
        "retweets": "ignore",
        "quoteTweets": "ignore",
        "hideExplorePageContents": false,
        "hideMetrics": false,
        "hideLikeMetrics": false,
        "hideReplyMetrics": false,
        "hideRetweetMetrics": false,
        "hideQuoteTweetMetrics": false,
        "hideBookmarkMetrics": false,
        "hideFollowingMetrics": false,
        "hideTotalTweetsMetrics": false,
        "hideViews": false,
        "twitterBlueChecks": "ignore",
        // The "<avatars> posted" pill over the home timeline: the Following tab already shows those posts.
        "hideSeeNewTweets": true,
    ]
    static let storedKey = "cpftConfigChanges"
    // The extension passes settings in a <script id="cpftSettings"> element; the app
    // assigns them directly instead. scripts/build.py checks this line still exists.
    static let settingsRead = "let $settings = /** @type {HTMLScriptElement} */ (document.querySelector('script#cpftSettings'))"

    static func source() -> String {
        let url = Bundle.main.url(forResource: "script", withExtension: "js")!
        let script = try! String(contentsOf: url, encoding: .utf8)
        var config = overrides
        if let stored = UserDefaults.standard.dictionary(forKey: storedKey) {
            config.merge(stored) { _, new in new }
        }
        let json = String(data: try! JSONSerialization.data(withJSONObject: config), encoding: .utf8)!
        return script.replacingOccurrences(of: settingsRead, with: "Object.assign(config, \(json))\nlet $settings = null")
    }

    // Settings the page changes itself (muted quotes, list retweets) are kept for the next launch.
    static let relay = """
        window.addEventListener('message', (event) => {
          if (event.source === window && event.data && event.data.type === 'cpftConfigChange' && event.data.changes) {
            window.webkit.messageHandlers.cpft.postMessage(JSON.stringify(event.data.changes))
          }
        })
        """
}

// x.com hides its header on scroll by sliding TopNavBar up (an inline transform, animated over 350 ms), but
// only part way, and it only fades its bottom tab bar (BottomBar's inline opacity). Whenever x.com hides the
// header, this hides both bars completely instead (header up, tab bar and the floating "create post" button down,
// same timing); they come back together, and the tab bar and button stay opaque. The rules live in the script's own style element: x.com rewrites
// the attributes of <html>, so state kept there was lost.
enum BottomBar {
    static let script = """
        (() => {
          const style = document.createElement('style')
          const base = `:is([data-testid="BottomBar"], [data-testid="FloatingActionButtons_Tweet_Button"]) {
            opacity: 1 !important;
            transition: transform 350ms cubic-bezier(0, 0, 0, 1) !important;
          }`
          // The floating "create post" button sits above the tab bar: it leaves by its own height plus 200 px.
          const hiddenRules = `
          [data-testid="TopNavBar"] { transform: translate3d(0, -100%, 0) !important; }
          [data-testid="BottomBar"] { transform: translate3d(0, 100%, 0) !important; }
          [data-testid="FloatingActionButtons_Tweet_Button"] { transform: translate3d(0, calc(100% + 200px), 0) !important; }`
          let hidden = null
          // x.com's own target for the header, from its inline transform: any upward shift means hidden.
          const headerHidden = () => [...document.querySelectorAll('[data-testid="TopNavBar"]')]
            .some(h => h.offsetHeight > 0 && /-\\d/.test(h.style.transform || ''))
          const update = () => {
            if (!style.isConnected) (document.head || document.documentElement).append(style)
            const now = headerHidden()
            if (now === hidden) return
            hidden = now
            style.textContent = base + (hidden ? hiddenRules : '')
          }
          const observer = new MutationObserver(update)
          let watched = []
          const attach = () => {
            const headers = [...document.querySelectorAll('[data-testid="TopNavBar"]')]
            if (headers.length !== watched.length || headers.some((h, i) => h !== watched[i])) {
              observer.disconnect()
              watched = headers
              for (const h of headers) observer.observe(h, { attributes: true, attributeFilter: ['style'] })
            }
            update()
          }
          attach()
          setInterval(attach, 250)
        })()
        """
}

final class WebController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
    private var webView: WKWebView!
    private var popup: UIViewController?

    // Like the other apps: no status bar, so the top edge belongs to the page (iOS kept taps there for
    // scroll-to-top, so buttons under it, such as compose's Post, couldn't be tapped).
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        // Allow pinch zoom even when the site restricts viewport scaling.
        configuration.ignoresViewportScaleLimits = true
        configuration.applicationNameForUserAgent = "Version/26.0 Mobile/15E148 Safari/604.1"
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let relayWorld = WKContentWorld.world(name: "cpft-relay")
        let controller = configuration.userContentController
        controller.addUserScript(WKUserScript(source: ControlPanel.source(), injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true, in: .page))
        controller.addUserScript(WKUserScript(source: ControlPanel.relay, injectionTime: .atDocumentStart,
                                              forMainFrameOnly: true, in: relayWorld))
        controller.add(self, contentWorld: relayWorld, name: "cpft")
        controller.addUserScript(WKUserScript(source: BottomBar.script, injectionTime: .atDocumentEnd,
                                              forMainFrameOnly: true, in: .defaultClient))

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = true
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(reload(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        // Edge to edge: x.com sets viewport-fit=cover and pads its own header and tab bar with
        // env(safe-area-inset-*), so the page scrolls under the notch and the home indicator.
        let root = UIView()
        root.backgroundColor = .black
        root.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: root.topAnchor),
            webView.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
        ])
        view = root
    }

    // Like a restored Safari tab: a relaunch after iOS ended the app reopens the page you were on,
    // with its Back/Forward list. Only an x.com page becomes the restore point.
    private static let session = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("interaction-state")

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let state = try? Data(contentsOf: Self.session) else { webView.load(URLRequest(url: Site.home)); return }
        webView.interactionState = state
        // An old restore point can reopen a blank page without any navigation callback.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, !webView.isLoading, !Site.matches(webView.url, Site.ownHosts) else { return }
            webView.load(URLRequest(url: Site.home))
        }
    }

    func saveSession() {
        guard Site.matches(webView?.url, Site.ownHosts), let state = webView?.interactionState as? Data else { return }
        do {
            try FileManager.default.createDirectory(at: Self.session.deletingLastPathComponent(), withIntermediateDirectories: true)
            try state.write(to: Self.session, options: .atomic)
        } catch { print("WebKit session checkpoint:", error) }
    }

    @objc private func reload(_ sender: UIRefreshControl) {
        webView.reload()
        sender.endRefreshing()
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let text = message.body as? String,
              let changes = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return }
        var stored = UserDefaults.standard.dictionary(forKey: ControlPanel.storedKey) ?? [:]
        stored.merge(changes) { _, new in new }
        UserDefaults.standard.set(stored, forKey: ControlPanel.storedKey)
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.allow) }
        let scheme = url.scheme?.lowercased() ?? ""
        if !["http", "https", "about", "blob", "data"].contains(scheme) {
            // Never hand twitter:// and similar to another X app on the phone.
            if ["mailto", "tel", "sms", "facetime"].contains(scheme) { UIApplication.shared.open(url) }
            return decisionHandler(.cancel)
        }
        let mainFrame = action.targetFrame?.isMainFrame ?? true
        if mainFrame && webView == self.webView && scheme.hasPrefix("http")
            && !Site.matches(url, Site.ownHosts + Site.loginHosts) {
            openOutside(url)
            return decisionHandler(.cancel)
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let url = action.request.url
        if let url, url.scheme?.hasPrefix("http") == true, !Site.matches(url, Site.ownHosts + Site.loginHosts) {
            openOutside(url)
            return nil
        }
        if let url, Site.matches(url, Site.ownHosts) {
            self.webView.load(action.request)
            return nil
        }
        // Sign-in popups need window.opener, so they get a real child web view.
        let child = WKWebView(frame: .zero, configuration: configuration)
        child.navigationDelegate = self
        child.uiDelegate = self
        let host = UIViewController()
        host.view = child
        popup = host
        present(host, animated: true)
        return child
    }

    func webViewDidClose(_ webView: WKWebView) {
        if webView != self.webView {
            popup?.dismiss(animated: true)
            popup = nil
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    private func openOutside(_ url: URL) {
        (popup ?? self).present(SFSafariViewController(url: url), animated: true)
    }

    // MARK: JavaScript dialogs

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
