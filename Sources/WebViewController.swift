import UIKit
import WebKit

final class WebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private let partnerURL = URL(string: "https://partner.obynexbroker.com/")!
    private var lastTokenSnippet: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let scriptSource = """
        (function() {
          function findToken() {
            try {
              var token = null;
              token = window.localStorage.getItem('auth_token')
                || window.localStorage.getItem('token')
                || window.localStorage.getItem('accessToken')
                || window.sessionStorage.getItem('auth_token')
                || window.sessionStorage.getItem('token')
                || window.sessionStorage.getItem('accessToken');
              if (!token && window.__INITIAL_STATE__ && window.__INITIAL_STATE__.auth) token = window.__INITIAL_STATE__.auth.token;
              if (!token) {
                var m = document.cookie.match(/(?:^|; )(?:auth_token|token|accessToken)=([^;]+)/);
                if (m) token = decodeURIComponent(m[1]);
              }
              if (token && window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.nativeHandler) {
                window.webkit.messageHandlers.nativeHandler.postMessage({type:'auth_token', token: token});
              }
            } catch(e) { /* silent */ }
          }
          window.addEventListener('load', findToken);
          setInterval(findToken, 3000);
        })();
        """

        let userContentController = WKUserContentController()
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        userContentController.addUserScript(userScript)
        userContentController.add(self, name: "nativeHandler")

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptEnabled = true
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.webView = webView

        var request = URLRequest(url: partnerURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        webView.load(request)
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "nativeHandler")
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "nativeHandler",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String,
              type == "auth_token",
              let token = body["token"] as? String,
              !token.isEmpty else {
            return
        }

        let snippet = tokenSnippet(from: token)
        guard snippet != lastTokenSnippet else {
            return
        }
        lastTokenSnippet = snippet

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Token capturado",
                                          message: "Token capturado: \(snippet)",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            if self.presentedViewController == nil {
                self.present(alert, animated: true, completion: nil)
            } else {
                self.dismiss(animated: false) {
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    private func tokenSnippet(from token: String) -> String {
        if token.count <= 8 {
            return token
        }
        let startIndex = token.startIndex
        let endIndex = token.index(token.endIndex, offsetBy: -4)
        let prefix = token[startIndex..<token.index(startIndex, offsetBy: 4)]
        let suffix = token[endIndex..<token.endIndex]
        return "\(prefix)…\(suffix)"
    }
}
