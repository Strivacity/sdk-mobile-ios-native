import Foundation
import Synchronization

struct HttpResponse {
    let httpResponse: HTTPURLResponse
    let data: Data
}

class HttpService {
    private enum HttpMethod: String {
        case GET, POST
    }

    private let session: URLSession

    private let logging: Logging

    private let networkConfiguration: NetworkConfiguration

    private let languageLock = NSRecursiveLock()
    private var languageTag: String = Locale.preferredLanguages.first ?? Locale.current.identifier.bcp47

    init(logging: Logging, networkConfiguration: NetworkConfiguration) {
        self.logging = logging
        self.networkConfiguration = networkConfiguration
        session = URLSession(
            configuration: .default,
            delegate: HttpSessionDelegate(logging: logging),
            delegateQueue: .main
        )
    }

    func get(url: URL, acceptHeader: String = "application/json") async throws -> HttpResponse {
        let request = createRequest(url: url, method: HttpMethod.GET, acceptHeader: acceptHeader, contentType: nil)
        return try await exchangeDataWithCustomHeaders(request: request)
    }

    func post(
        url: URL,
        session: String,
        body: [String: Any]? = nil,
        acceptHeader _: String = "application/json"
    ) async throws -> HttpResponse {
        var jsonData: Data?
        if let body = body {
            jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        return try await post(url: url, session: session, bodyContent: jsonData, contentType: "application/json")
    }

    func post(
        url: URL,
        session: String? = nil,
        bodyContent: Data? = nil,
        contentType: String = "application/json",
        acceptHeader: String = "application/json"
    ) async throws -> HttpResponse {
        var request = createRequest(
            url: url,
            method: HttpMethod.POST,
            acceptHeader: acceptHeader,
            contentType: contentType
        )

        if let session = session {
            request.setValue("Bearer " + session, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyContent

        return try await exchangeDataWithCustomHeaders(request: request)
    }

    func setAcceptLanguageHeader(languageTag: String) {
        languageLock.withLock {
            self.languageTag = languageTag
        }
    }

    private func createRequest(url: URL, method: HttpMethod, acceptHeader: String, contentType: String?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let contentType = contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        request.setValue(acceptHeader, forHTTPHeaderField: "Accept")
        let languageTag = languageLock.withLock { self.languageTag }
        request.setValue(languageTag, forHTTPHeaderField: "Accept-Language")

        return request
    }

    private func exchangeDataWithCustomHeaders(request: URLRequest) async throws -> HttpResponse {
        // shadow immutable param with mutable variant
        var request = request
        logging
            .debug(
                "REQUEST [\(request.httpMethod ?? "")]: \(request.url?.path ?? "")"
            )
        await networkConfiguration.customRequestHeaderProvider?(
            request.url!,
            request.httpMethod!,
            request.httpBody
        ).forEach { fieldName, value in
            if request.value(forHTTPHeaderField: fieldName) != nil {
                logging.debug("Dropped custom header as it conflicts with SDK set header: \(fieldName)")
                return
            }
            request.setValue(value, forHTTPHeaderField: fieldName)
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NativeSDKError.httpError(statusCode: -1)
        }

        if let xEventIdHeader = httpResponse.value(forHTTPHeaderField: "x-event-id"),
           logging.xEventId != xEventIdHeader {
            logging.xEventId = xEventIdHeader
            logging.debug("X-Event-ID updated: \(xEventIdHeader)")
        }
        return HttpResponse(httpResponse: httpResponse, data: data)
    }

    private class HttpSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
        private let logging: Logging

        init(logging: Logging) {
            self.logging = logging
        }

        func urlSession(
            _: URLSession,
            task _: URLSessionTask,
            willPerformHTTPRedirection _: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping (URLRequest?) -> Void
        ) {
            if request.url?.scheme == "https" {
                logging.debug("Redirect to \(request.url?.path ?? "")")
                completionHandler(request)
            } else {
                logging
                    .debug(
                        "Redirect to \(request.url?.scheme ?? "")://\(request.url?.host ?? "")/\(request.url?.path ?? "")"
                    )
                completionHandler(nil)
            }
        }
    }
}

private extension String {
    var bcp47: String {
        replacingOccurrences(of: "_", with: "-")
    }
}
