import SwiftUI

struct SubmitView: View {
    @EnvironmentObject var loginController: LoginController

    // periphery:ignore
    let screen: String
    let formId: String
    // periphery:ignore
    let widgetId: String

    let widget: SubmitWidget

    public var body: some View {
        let button = Button {
            Task {
                await loginController.submit(formId: formId)
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
