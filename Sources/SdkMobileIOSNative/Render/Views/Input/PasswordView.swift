import SwiftUI

struct PasswordWiew: View {
    @EnvironmentObject var loginController: LoginController

    // periphery:ignore
    let screen: String
    let formId: String
    let widgetId: String

    let widget: PasswordWidget
    @State var isPasswordVisible: Bool = false

    public var body: some View {
        var error = loginController.errorMessage(formId: formId, widgetId: widgetId) ?? ""

        HStack {
            if isPasswordVisible {
                TextField(
                    widget.label,
                    text: loginController.bindingForWidget(formId: formId, widgetId: widgetId, defaultValue: "")
                )
            } else {
                SecureField(
                    widget.label,
                    text: loginController.bindingForWidget(formId: formId, widgetId: widgetId, defaultValue: "")
                )
            }

            Button {
                isPasswordVisible.toggle()
            } label: {
                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
            }
        }
    }
}
