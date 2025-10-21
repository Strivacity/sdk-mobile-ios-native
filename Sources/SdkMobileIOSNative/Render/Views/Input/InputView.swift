import SwiftUI

struct InputView: View {
    @EnvironmentObject var loginController: LoginController

    // periphery:ignore
    let screen: String
    let formId: String
    let widgetId: String

    let widget: InputWidget

    var body: some View {
        var error = loginController.errorMessage(formId: formId, widgetId: widgetId) ?? ""

        let textContentType: UITextContentType? = switch widget.autocomplete {
        case "username":
            .username
        default:
            .none
        }

        let keyboardType: UIKeyboardType = switch widget.inputmode {
        case "email":
            .emailAddress
        default:
            .default
        }

        TextField(
            widget.label,
            text: loginController.bindingForWidget(formId: formId, widgetId: widgetId, defaultValue: "")
        )
        .textContentType(textContentType)
        .keyboardType(keyboardType)
    }
}
