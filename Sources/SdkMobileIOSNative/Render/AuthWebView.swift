import AuthenticationServices

public class AuthWebView: NSObject, ASWebAuthenticationPresentationContextProviding {
    public func open(
        hostedURL: URL,
        customURIScheme: String,
        prefersEphemeralWebBrowserSession: Bool,
        URIHandle: @escaping (URL) -> Void,
        errorCallback: @escaping (Error) -> Void
    ) {
        let session = ASWebAuthenticationSession(
            url: hostedURL,
            callbackURLScheme: customURIScheme
        ) { URIScheme, error in
            if let URIScheme = URIScheme {
                URIHandle(URIScheme)
            } else if let error = error {
                errorCallback(error)
            }
        }

        session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession

        session.presentationContextProvider = self
        session.start()
    }

    public func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
