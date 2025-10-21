import SwiftUI

struct PasscodeView: View {
    @EnvironmentObject var loginController: LoginController

    // periphery:ignore
    let screen: String
    let formId: String
    let widgetId: String

    let widget: PasscodeWidget

    var body: some View {
        var error = loginController.errorMessage(formId: formId, widgetId: widgetId) ?? ""
        TextField(
            widget.label,
            text: loginController.bindingForWidget(formId: formId, widgetId: widgetId, defaultValue: "")
        )
        .textContentType(.oneTimeCode)
        .keyboardType(.numberPad)
    }
}
