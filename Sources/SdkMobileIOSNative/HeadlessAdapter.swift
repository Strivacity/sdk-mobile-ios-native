import Foundation

public class HeadlessAdapter {
    var nativeSDK: NativeSDK
    private var loginController: LoginController

    private var delegate: HeadlessAdapterDelegate

    public init(nativeSDK: NativeSDK, delegate: HeadlessAdapterDelegate) {
        self.nativeSDK = nativeSDK
        self.delegate = delegate

        guard let loginController = nativeSDK.loginController else {
            assert(false, "No login in progress")
        }

        self.loginController = loginController
    }

    public func initialize() {
        delegate.renderScreen(screen: getScreen())
    }

    public func getScreen() -> Screen {
        guard let screen = loginController.screen else {
            assert(false, "Screen not set")
        }
        return screen
    }

    public func errorMessage(formId: String, widgetId: String) -> String? {
        return loginController.errorMessage(formId: formId, widgetId: widgetId)
    }

    public func submit(formId: String, data: [String: Any]?) async {
        let currentScreen = getScreen()
        await loginController.submit(formId: formId, formData: data)

        if !nativeSDK.session.loginInProgress {
            return
        }

        let newScreen = getScreen()

        if
            currentScreen.screen == newScreen.screen,
            currentScreen.forms == newScreen.forms,
            currentScreen.layout == newScreen.layout,
            currentScreen.messages != newScreen.messages {
            delegate.refreshScreen(screen: getScreen())
            return
        }

        delegate.renderScreen(screen: getScreen())
    }

    func submitForm(formId: String) async {
        let formData = loginController.formModel?.formRequestData(formId: formId)
        await submit(formId: formId, data: formData)
    }
}

public protocol HeadlessAdapterDelegate: class {
    func renderScreen(screen: Screen)
    func refreshScreen(screen: Screen)
}
