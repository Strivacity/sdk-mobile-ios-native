import Combine
import Foundation

public class HeadlessAdapter {
    var nativeSDK: NativeSDK
    private var loginController: LoginController

    private var delegate: HeadlessAdapterDelegate

    private var cancellables = Set<AnyCancellable>()

    public init(nativeSDK: NativeSDK, delegate: HeadlessAdapterDelegate) {
        precondition(
            nativeSDK.loginController != nil,
            "No login session started. Make sure to call `NativeSDK.login()` first."
        )

        self.nativeSDK = nativeSDK
        self.delegate = delegate
        loginController = nativeSDK.loginController!

        loginController.$screen
            .compactMap { $0 } // remove nil values
            .scan((previous: Screen?.none, current: Screen?.none)) { acc, newValue in
                (previous: acc.current, current: newValue)
            }
            .filter { _ in nativeSDK.session.loginInProgress }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pair in
                guard let self, let current = pair.current else {
                    return
                }

                if let previous = pair.previous,
                   previous.screen == current.screen,
                   previous.forms == current.forms,
                   previous.layout == current.layout,
                   previous.messages != current.messages {
                    delegate.refreshScreen(screen: current)
                } else {
                    delegate.renderScreen(screen: current)
                }
            }
            .store(in: &cancellables)
    }

    public func initialize() {
        if let screen = loginController.screen {
            delegate.renderScreen(screen: screen)
        }
    }

    @available(*, deprecated, message: "Prefer to use HeadlessAdapterDelegate method parameter")
    public func getScreen() -> Screen? {
        return loginController.screen
    }

    public func errorMessage(formId: String, widgetId: String) -> String? {
        return loginController.errorMessage(formId: formId, widgetId: widgetId)
    }

    public func submit(formId: String, data: [String: Any]?) async {
        await loginController.submit(formId: formId, formData: data)
    }

    func submitForm(formId: String) async {
        let formData = loginController.formModel?.formRequestData(formId: formId)
        await submit(formId: formId, data: formData)
    }

    public func closeFlow() async throws {
        try await loginController.closeFlow()
    }
}

public protocol HeadlessAdapterDelegate: AnyObject {
    func renderScreen(screen: Screen)
    func refreshScreen(screen: Screen)
}
