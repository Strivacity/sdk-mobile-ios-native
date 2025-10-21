import SwiftUI

struct SubmitView: View {
    @EnvironmentObject var loginController: LoginController

    // periphery:ignore
    let screen: String
    let formId: String
    // periphery:ignore
    let widgetId: String

    let widget: SubmitWidget

    let action: (() async -> Void)?

    init(screen: String, formId: String, widgetId: String, widget: SubmitWidget, action: @escaping () async -> Void) {
        self.screen = screen
        self.formId = formId
        self.widgetId = widgetId
        self.widget = widget
        self.action = action
    }

    init(screen: String, formId: String, widgetId: String, widget: SubmitWidget) {
        self.screen = screen
        self.formId = formId
        self.widgetId = widgetId
        self.widget = widget
        action = nil
    }

    var body: some View {
        let button = Button {
            Task {
                if action != nil {
                    await action?()
                } else {
                    await loginController.submit(formId: formId)
                }
            }
        } label: { Text(widget.label) }

        switch widget.render.type {
        case "button":
            button
                .buttonStyle(.borderedProminent)

        case "link":
            button

        default:
            FallbackTriggerView()
        }
    }
}
