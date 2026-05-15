import Foundation

public class NativeSDK {
    let issuer: URL
    let clientId: String
    let redirectURI: URL
    let postLogoutURI: URL
    let mode: SdkMode
    let logging: Logging
    let networkConfiguration: NetworkConfiguration

    var loginController: LoginController?

    public let session: Session

    private let httpService: HttpService
    private let oidcHandlerService: OIDCHandlerService

    private var entryFlowTask: (task: Task<Void, Never>, continuation: CheckedContinuation<Void, Error>)?

    public init(
        issuer: URL,
        clientId: String,
        redirectURI: URL,
        postLogoutURI: URL,
        storage: Storage = KeyChain(),
        mode: SdkMode = .ios,
        logging: Logging = DefaultLogging(),
        networkConfiguration: NetworkConfiguration = NetworkConfiguration()
    ) {
        self.issuer = issuer
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.postLogoutURI = postLogoutURI
        self.mode = mode
        self.logging = logging
        self.networkConfiguration = networkConfiguration

        httpService = HttpService(logging: logging, networkConfiguration: networkConfiguration)
        oidcHandlerService = OIDCHandlerService(httpService: httpService, logging: logging)

        session = Session(storage: storage, logging: logging)
    }

    public func initializeSession() async throws {
        await session.load()
        try await refreshTokensIfNeeded()
    }

    public func login(
        parameters: LoginParameters?
    ) async throws -> Profile {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                await login(
                    parameters: parameters,
                    onSuccess: {
                        continuation.resume(returning: self.session.profile!)
                    },
                    onError: { err in
                        continuation.resume(throwing: err)
                    }
                )
            }
        }
    }

    public func login(
        parameters: LoginParameters?,
        onSuccess: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        logging.info("Starting login flow")
        let oidcParams = OidcParams(
            onSuccess: onSuccess,
            onError: onError,
            prefersEphemeralWebBrowserSession: parameters?.prefersEphemeralWebBrowserSession ?? false
        )

        let authEndpoint = issuer.appendingPathComponent("/oauth2/auth")
        var urlComponents = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: false)!

        urlComponents.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(
                name: "redirect_uri",
                value: redirectURI.absoluteString
            ),
            URLQueryItem(name: "state", value: oidcParams.state),
            URLQueryItem(name: "nonce", value: oidcParams.nonce),
            URLQueryItem(
                name: "code_challenge",
                value: oidcParams.codeChallenge
            ),
            URLQueryItem(name: "code_challenge_method", value: "S256"),

            URLQueryItem(
                name: "scope",
                value: (parameters?.scopes ?? ["openid", "profile"]).joined(
                    separator: " "
                )
            ),
            URLQueryItem(name: "acr_values", value: parameters?.acrValue),
            URLQueryItem(name: "login_hint", value: parameters?.loginHint),
            URLQueryItem(name: "prompt", value: parameters?.prompt),
            URLQueryItem(name: "sdk", value: mode.rawValue),
            URLQueryItem(
                name: "audience",
                value: parameters?.audiences?.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
                .nilIfEmpty?
                .joined(separator: " ")
            ),
            URLQueryItem(
                name: "ui_locales",
                value: parameters?.uiLocales?.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
                .nilIfEmpty?
                .joined(separator: " ")
            ),
        ]

        guard let url = urlComponents.url else {
            onError(NativeSDKError.technical(message: "Unable to generate /auth url"))
            return
        }

        do {
            let parameters = try await oidcHandlerService.handleCall(url: url)

            guard let sessionId = parameters["session_id"] else {
                logging.info("Attempting to continue flow - missing session ID")
                try await continueFlow(oidcParams: oidcParams, queryParameters: parameters)
                return
            }
            logging.info("Session ID present, creating loginController")
            applyServerLanguagePreference(parameters: parameters)

            let loginHandlerService = LoginHandlerService(
                httpService: httpService,
                issuer: issuer,
                sessionId: sessionId
            )
            let loginController = LoginController(
                nativeSDK: self,
                loginHandlerService: loginHandlerService,
                oidcParams: oidcParams,
                logging: logging
            )

            try await loginController.initialize()
            self.loginController = loginController

            await MainActor.run {
                self.session.loginInProgress = true
            }
        } catch {
            logging.error("Failed to log in", error: error)
            cleanup()
            switch error {
            case is NativeSDKError:
                onError(error)
            default:
                onError(NativeSDKError.unknownError(source: error))
            }
        }
    }

    public func entry(entryUrl: URL) async throws {
        defer {
            logging.debug("Cleaning up entry")
            Task { @MainActor in
                cleanup()
            }
            entryFlowTask = nil
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                startEntryTask(entryUrl: entryUrl, continuation: continuation)
            }
        } onCancel: {
            logging.debug("Entry flow cancelled")
            entryFlowTask?.continuation.resume(throwing: CancellationError())
        }
    }

    private func startEntryTask(entryUrl: URL, continuation: CheckedContinuation<Void, Error>) {
        // exit from current flow if exists
        cancelFlow()

        // start new flow
        let newEntryTask = Task {
            do {
                let entryComponents = URLComponents(url: entryUrl, resolvingAgainstBaseURL: false)
                guard let challengeItem = entryComponents?.queryItems?.first(where: { $0.name == "challenge" }) else {
                    throw NativeSDKError
                        .genericError(message: "Expected mandatory challenge parameter but was not provided")
                }

                let requestUrlBase = issuer.appendingPathComponent("/provider/flow/entry")
                var requestComponents = URLComponents(url: requestUrlBase, resolvingAgainstBaseURL: false)!
                requestComponents.queryItems = [
                    URLQueryItem(name: "client_id", value: clientId),
                    URLQueryItem(name: "redirect_uri", value: redirectURI.absoluteString),
                    challengeItem,
                ]

                guard let requestUrl = requestComponents.url else {
                    throw NativeSDKError.genericError(message: "Could not generate URL for entry")
                }

                let response = try await httpService.get(url: requestUrl, acceptHeader: "*/*")
                let statusCode = response.httpResponse.statusCode

                guard case 200 ..< 400 = statusCode else {
                    if statusCode == 400 {
                        let decodedError = try JSONDecoder().decode(ErrorEnvelope.self, from: response.data)
                        throw NativeSDKError.workflowError(
                            error: decodedError.error,
                            errorDescription: decodedError.errorDescription
                        )
                    }
                    logging.warn("Failed to enter login flow")
                    logging
                        .debug(
                            "This might be cause by Client misconfiguration. Ensure that authentication client has entry URL configured."
                        )
                    throw NativeSDKError.httpError(statusCode: statusCode)
                }

                let sessionId = try extractSessionId(fromResponse: response)
                if let loc = response.httpResponse.value(forHTTPHeaderField: "location"),
                   let components = URLComponents(string: loc),
                   let preferredLanguage = components.queryItems?.first { $0.name.lowercased() == "language" }?.value {
                    applyServerLanguagePreference(preferredLanguageTag: preferredLanguage)
                }

                // build loginController for sessionId
                let loginHandlerService = LoginHandlerService(
                    httpService: httpService,
                    issuer: issuer,
                    sessionId: sessionId
                )
                let loginController = LoginController(
                    nativeSDK: self,
                    loginHandlerService: loginHandlerService,
                    oidcParams: OidcParams(
                        onSuccess: {
                            self.logging.debug("Entry flow completed successfully")
                            self.closeFlow()
                        },
                        onError: { err in
                            self.logging.debug("Entry flow completed exceptionally")
                            self.closeFlow(throwing: err)

                        },
                        prefersEphemeralWebBrowserSession: false
                    ),
                    logging: logging
                )
                self.loginController = loginController

                // submit init form with sessionId
                try await loginController.initialize()

                await MainActor.run {
                    session.loginInProgress = true
                }
            } catch let error as NativeSDKError {
                continuation.resume(throwing: error)
            } catch {
                // in case of any error, make sure to propagate it to the continuation
                continuation.resume(throwing: NativeSDKError.unknownError(source: error))
            }
        }

        entryFlowTask = (task: newEntryTask, continuation: continuation)
    }

    private func extractSessionId(fromResponse response: HttpResponse) throws -> String {
        guard let locationHeader = response.httpResponse.value(forHTTPHeaderField: "Location") else {
            throw NativeSDKError.genericError(message: "Expected Location header not found")
        }

        guard let locationUrl = URL(string: locationHeader) else {
            throw NativeSDKError.genericError(message: "Location header could not be parsed")
        }

        guard let sessionParam = URLComponents(url: locationUrl, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "session_id" }),
            let sessionValue = sessionParam.value else {
            throw NativeSDKError.genericError(message: "SessionID parameter not found")
        }

        return sessionValue
    }

    private func applyServerLanguagePreference(parameters: [AnyHashable: Any]) {
        if let preferredLanguageTag = parameters.first { (key, _) in
            guard let key = key as? String else { return false }
            return key.lowercased() == "language"
        }?.value as? String {
            applyServerLanguagePreference(preferredLanguageTag: preferredLanguageTag)
        }
    }

    private func applyServerLanguagePreference(preferredLanguageTag: String) {
        logging.info("Setting server language preference: \(preferredLanguageTag)")
        httpService.setAcceptLanguageHeader(languageTag: preferredLanguageTag)
    }

    func closeFlow(throwing: Error? = nil) {
        if let entryFlowTask = entryFlowTask {
            // closing an entry flow
            // will also run entry's defer block once continuation is resumed
            // cleanup happens there
            if let error = throwing {
                entryFlowTask.continuation.resume(throwing: error)
            } else {
                entryFlowTask.continuation.resume()
            }
            self.entryFlowTask = nil
        } else {
            Task { @MainActor in
                // closing another flow eg. registration
                cleanup()
            }
        }
    }

    public func cancelFlow(error: NativeSDKError? = nil) {
        // reset logging correlation state
        logging.xEventId = nil

        if let error = error {
            logging.info("Cancelling flow with error: \(error.localizedDescription)")
        } else {
            logging.info("Cancelling flow")
        }

        if let entryFlowTask = entryFlowTask {
            entryFlowTask.continuation.resume(throwing: CancellationError())
        }

        guard let loginController = loginController else {
            return
        }

        Task { @MainActor in
            cleanup()
            if let error = error {
                loginController.oidcParams.onError(error)
            }
        }
    }

    public func logout() async throws {
        defer {
            logging.xEventId = nil
        }

        let idToken = session.profile?.tokenResponse.idToken

        await session.clear()

        guard let idToken = idToken else {
            logging.debug("Logout called without session")
            return
        }

        logging.debug("Logging user out")

        let logoutEndpoint = issuer.appendingPathComponent("/oauth2/sessions/logout")
        var urlComponents = URLComponents(url: logoutEndpoint, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "id_token_hint", value: idToken),
            URLQueryItem(name: "post_logout_redirect_uri", value: postLogoutURI.absoluteString),
        ]

        guard let url = urlComponents.url else {
            throw NativeSDKError.technical(message: "Could not generate /logout url")
        }

        let redirectUrl = try await oidcHandlerService.logout(url: url)

        logging.info("Logout completed successfully")

        guard let redirectUrl = redirectUrl,
              redirectUrl.starts(with: postLogoutURI.absoluteString.lowercased()) else {
            logging.warn("Logout redirect does not match expected logout URL. " +
                "This is likely a misconfiguration of `postLogoutURI`")
            return
        }
    }

    public func revoke() async throws {
        let refreshToken = session.profile?.tokenResponse.refreshToken
        let accessToken = session.profile?.tokenResponse.accessToken

        let token = refreshToken != nil ? refreshToken : accessToken

        guard let token = token else {
            return
        }

        let typeHint = refreshToken != nil ? "refresh_token" : "access_token"

        let revokeParams = RevokeParams(clientId: clientId, token: token, tokenTypeHint: typeHint)

        try await oidcHandlerService.revoke(issuer: issuer, params: revokeParams)

        await session.clear()
    }

    public func isAuthenticated() async throws -> Bool {
        try await refreshTokensIfNeeded()
        return session.profile != nil
    }

    public func getAccessToken() async throws -> String? {
        try await refreshTokensIfNeeded()
        return session.profile?.tokenResponse.accessToken
    }

    func finalizeFlow(uri: URL) async throws {
        guard let oidcParams = loginController?.oidcParams else {
            throw NativeSDKError.technical(message: "Called continueFlow in invalid state")
        }

        do {
            let parameters = try await oidcHandlerService.handleCall(url: uri)
            try await continueFlow(oidcParams: oidcParams, queryParameters: parameters)
        } catch {
            await MainActor.run {
                cleanup()
                switch error {
                case is NativeSDKError:
                    oidcParams.onError(error)
                default:
                    oidcParams.onError(NativeSDKError.unknownError(source: error))
                }
            }
        }
    }

    private func continueFlow(oidcParams: OidcParams, queryParameters: [String: String]) async throws {
        if let loginController = loginController, let sessionId = queryParameters["session_id"] {
            logging.info("Attempting to initialize loginController")
            try await loginController.initialize()
            return
        } else {
            logging.info("loginController is null or sessionId does not exist")
        }

        if let error = queryParameters["error"], let errorDescription = queryParameters["error_description"] {
            await session.clear()
            throw NativeSDKError.oidcError(
                error: error,
                errorDescription: errorDescription.replacingOccurrences(of: "+", with: " ")
                    .removingPercentEncoding ?? errorDescription
            )
        }

        guard let state = queryParameters["state"] else {
            throw NativeSDKError.invalidCallback(reason: "Parameter `state` missing from response")
        }

        if state != oidcParams.state {
            throw NativeSDKError.invalidCallback(reason: "State param did not matched expected value")
        }

        guard let code = queryParameters["code"] else {
            throw NativeSDKError.invalidCallback(reason: "Parameter `code` missing from response")
        }

        let tokenResponse = try await oidcHandlerService.tokenExchange(
            url: issuer.appendingPathComponent("/oauth2/token"),
            params: TokenExchangeParams(
                code: code,
                codeVerifier: oidcParams.codeVerifier,
                redirectURI: redirectURI.absoluteString,
                clientId: clientId
            )
        )

        guard let nonce = try JWTUtils.parseJWT(tokenResponse.idToken)["nonce"] as? String else {
            throw NativeSDKError.technical(message: "Nonce missing from response")
        }

        guard nonce == oidcParams.nonce else {
            logging.debug("Nonce param did not match expected value")
            throw NativeSDKError.technical(message: "Nonce param did not matched expected value")
        }

        try await session.update(tokenResponse: tokenResponse)

        logging.xEventId = nil
        logging.info("Login successful")
        await MainActor.run {
            cleanup()
            oidcParams.onSuccess()
        }
    }

    private func refreshTokensIfNeeded() async throws {
        logging.debug("Attempting to refresh token")

        guard let profile = session.profile else {
            logging.debug("Token refresh not possible - session not found")
            return
        }

        guard Date.now >= profile.accessTokenExpiresAt else {
            logging.debug("Token refresh not needed - access token has not expired")
            return
        }

        guard let refreshToken = session.profile?.tokenResponse.refreshToken else {
            logging.info("Cannot refresh token, signing user out due to expired access token")
            await session.clear()
            return
        }

        do {
            let refreshResponse = try await oidcHandlerService.tokenRefresh(
                url: issuer.appendingPathComponent("/oauth2/token"),
                params: TokenRefreshParams(refreshToken: refreshToken, clientId: clientId)
            )

            try await session.update(tokenResponse: refreshResponse)
            logging.info("Session refreshed successfully")
            return
        } catch let error as NativeSDKError {
            if case let .oidcError(err, description) = error {
                logging
                    .warn(
                        "Token refresh failed with error: \(err) and description \"\(description ?? "")\", clearing session"
                    )
                await session.clear()
                return
            }

            guard case let .httpError(statusCode) = error else {
                logging.error("Token refresh failed", error: error)
                throw error
            }

            if statusCode == 401 || statusCode == 403 {
                logging.warn("Token refresh failed with status \(statusCode), clearing session")
                await session.clear()
                return
            }
            logging.error("Token refresh failed with status \(statusCode)", error: error)
            throw error
        } catch {
            logging.error("Token refresh failed", error: error)
            throw error
        }
    }

    private func cleanup() {
        session.loginInProgress = false
        loginController = nil
    }
}

public struct LoginParameters {
    public init(
        prompt: String? = nil,
        loginHint: String? = nil,
        acrValue: String? = nil,
        scopes: [String]? = nil,
        prefersEphemeralWebBrowserSession: Bool = false,
        audiences: [String]? = nil,
        uiLocales: [String]? = nil
    ) {
        self.prompt = prompt
        self.loginHint = loginHint
        self.acrValue = acrValue
        self.scopes = scopes
        self.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
        self.audiences = audiences
        self.uiLocales = uiLocales
    }

    let prompt: String?
    let loginHint: String?
    let acrValue: String?
    let scopes: [String]?
    let prefersEphemeralWebBrowserSession: Bool
    let audiences: [String]?
    /// Preferred languages to display the UI on
    /// Consists of BCP47 encoded language tags eg. de-AT
    let uiLocales: [String]?
}

public enum SdkMode: String {
    case ios
    case iosMinimal = "ios-minimal"
}

extension Array {
    var nilIfEmpty: [Element]? {
        isEmpty ? nil : self
    }
}

/// Static configuration for the network communication layer of the SDK.
///
/// - Parameters:
///   - userAgent: The User-Agent header value sent with every network request. Defaults to
///     Platform default User Agent. Must be at least 3 characters after trimming; a precondition
///     failure is thrown at construction time otherwise.
///   - customRequestHeaders: Additional HTTP headers included in every network request. Every
///     key must be a `CustomHeaderFieldName`: it must start with the `x-sty-` prefix, be entirely
///     lowercase, and not be equal to the bare prefix `"x-sty-"` — all three rules are enforced at
///     construction time and a precondition failure is thrown on violation. Headers with the
///     `x-sty-` prefix are available in server-side event Hooks on the backend. Defaults to an empty
///     dictionary.
public struct NetworkConfiguration {
    let userAgent: String?
    var customRequestHeaders: [CustomHeaderFieldName: String]

    public init(
        userAgent: String? = nil,
        customRequestHeaders: [CustomHeaderFieldName: String] = [:]
    ) {
        precondition(
            userAgent == nil || userAgent!.trimmingCharacters(in: .whitespacesAndNewlines).count
                >= 3,
            "User agent must be at least 3 characters"
        )

        precondition(
            customRequestHeaders.keys.allSatisfy { $0.lowercased() == $0 },
            "Custom request headers must be defined with lowercase. eg. `x-sty-my-header`"
        )

        precondition(
            customRequestHeaders.keys.allSatisfy { $0.starts(with: "x-sty-") },
            "Custom request headers must start with `x-sty-` prefix."
        )

        precondition(
            customRequestHeaders.keys.firstIndex(of: "x-sty-") == nil,
            "Cannot add \"x-sty-\" header as it is a reserved header prefix."
        )

        self.userAgent = userAgent
        self.customRequestHeaders = customRequestHeaders
    }

    /// A header field name that must comply with all of the following rules:
    /// - starts with the `x-sty-` prefix (e.g. `x-sty-my-header`)
    /// - is entirely lowercase
    /// - is not equal to the bare prefix `"x-sty-"` (i.e. must have at least one character after the prefix)
    ///
    /// Headers using this convention are appended to every network request towards the Strivacity
    /// server. Because of the `x-sty-` prefix they are forwarded to and available in server-side event
    /// Hooks on the backend.
    public typealias CustomHeaderFieldName = String
}

public extension NetworkConfiguration {
    /// Returns a copy of this `NetworkConfiguration` with the `x-sty-sdk-version` custom header set to
    /// the current `SDKVersion`. Useful for correlating server-side Hook events with a specific SDK
    /// release.
    mutating func addSdkVersionCustomHeader() -> NetworkConfiguration {
        customRequestHeaders = customRequestHeaders.merging([
            "x-sty-sdk-version": SDKVersion,
        ]) { _, new in new }

        return self
    }
}
