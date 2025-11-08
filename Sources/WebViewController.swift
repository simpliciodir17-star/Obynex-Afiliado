import UIKit
import WebKit

// Removemos a conformidade com WKScriptMessageHandler
final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private let partnerURL = URL(string: "https://partner.obynexbroker.com/")!
    private var lastTokenSnippet: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // --- Injeção de JavaScript REMOVIDA ---
        // A lógica de 'scriptSource', 'userScript' e 'nativeHandler'
        // foi removida pois não funciona com cookies HttpOnly.

        // Configuração padrão do WebView
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptEnabled = true
        // Não precisamos mais do userContentController para esta lógica

        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // O WKNavigationDelegate é agora o ponto principal
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

    // --- deinit e userContentController REMOVIDOS ---
    // Não são mais necessários após a remoção do WKScriptMessageHandler

    // Esta função (WKNavigationDelegate) é a nova lógica de captura
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

        // 1. Tentar obter a resposta HTTP
        guard let httpResponse = navigationResponse.response as? HTTPURLResponse,
              let headers = httpResponse.allHeaderFields as? [String: String] else {
            decisionHandler(.allow)
            return
        }

        // 2. Procurar pelo cabeçalho 'Set-Cookie' (maiúsculas/minúsculas)
        let setCookieHeader = headers["Set-Cookie"] ?? headers["set-cookie"]

        if let cookieString = setCookieHeader {
            
            // 3. O cabeçalho pode conter múltiplos cookies, então dividimos
            let cookies = cookieString.components(separatedBy: ";")
            
            for cookie in cookies {
                let trimmedCookie = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 4. Procurar pelo nosso cookie 'aff_sid'
                if trimmedCookie.hasPrefix("aff_sid=") {
                    // Extrai o valor do token (o que vem depois de 'aff_sid=')
                    let token = String(trimmedCookie.dropFirst("aff_sid=".count))
                    
                    if !token.isEmpty {
                        let snippet = tokenSnippet(from: token)
                        
                        // 5. Evitar mostrar o mesmo token repetidamente
                        guard snippet != lastTokenSnippet else {
                            continue // Passa para o próximo cookie
                        }
                        lastTokenSnippet = snippet

                        // 6. Mostrar o alerta (na thread principal)
                        DispatchQueue.main.async { [weak self] in
                            self?.showAlert(with: snippet)
                        }
                        // Já encontramos o que queríamos, podemos parar o loop
                        break
                    }
                }
            }
        }

        // 7. Permitir que a navegação continue
        decisionHandler(.allow)
    }

    // Esta função lida com pop-ups (links target="_blank")
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    // MARK: - Funções Auxiliares (Helpers)

    private func showAlert(with snippet: String) {
        let alert = UIAlertController(title: "Token (aff_sid) Capturado",
                                      message: "Token: \(snippet)",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        // Lógica para evitar conflito de alertas
        if self.presentedViewController == nil {
            self.present(alert, animated: true, completion: nil)
        } else {
            self.dismiss(animated: false) {
                self.present(alert, animated: true, completion: nil)
            }
        }
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
