import SwiftUI

public struct HeadlessAdapterLoginView: View {
    let headlessAdapter: HeadlessAdapter

    public init(headlessAdapter: HeadlessAdapter) {
        self.headlessAdapter = headlessAdapter
    }

    public var body: some View {
        LoginView(nativeSDK: headlessAdapter.nativeSDK) { _, screen, forms, layout in
            LoginLayoutView(screen: screen, forms: forms, layout: layout) { screen, formId, widgetId, widget in
                switch widget {
                case let .submit(widget):
                    SubmitView(screen: screen, formId: formId, widgetId: widgetId, widget: widget) {
                        await headlessAdapter.submitForm(formId: formId)
                    }
                default:
                    LoginWidgetView(screen: screen, formId: formId, widgetId: widgetId, widget: widget)
                }
            }
        }
    }
}
