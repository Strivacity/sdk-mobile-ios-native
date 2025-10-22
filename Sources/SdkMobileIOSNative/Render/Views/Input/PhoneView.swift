import SwiftUI

struct PhoneView: View {
    @EnvironmentObject var loginController: LoginController
    // periphery:ignore
    let screen: String
    let formId: String
    let widgetId: String

    let widget: PhoneWidget

    var body: some View {
        var error = loginController.errorMessage(formId: formId, widgetId: widgetId) ?? ""

        TextField(
            widget.label,
            text: loginController.bindingForWidget(formId: formId, widgetId: widgetId, defaultValue: "")
        )
        .textContentType(.telephoneNumber)
        .keyboardType(.phonePad)
    }
}
