import SwiftUI

struct SelectView: View {
    @EnvironmentObject var loginController: LoginController

    // periphery:ignore
    let screen: String
    let formId: String
    let widgetId: String

    let widget: SelectWidget

    var body: some View {
        if widget.render.type == "dropdown" {
            if widget.options[0].type == "item" {
                SimpleSelect(
                    formId: formId,
                    widget: widget,
                    selectedValue: loginController.bindingForWidget(
                        formId: formId,
                        widgetId: widgetId,
                        defaultValue: widget.value ?? nil
                    )
                )
            } else if widget.options[0].type == "group" {
                GroupSelect(
                    formId: formId,
                    widget: widget,
                    selectedValue: loginController.bindingForWidget(
                        formId: formId,
                        widgetId: widgetId,
                        defaultValue: widget.value ?? nil
                    )
                )
            } else {
                FallbackTriggerView()
            }
        } else if widget.render.type == "radio" {
            RadioSelect(
                formId: formId,
                widget: widget,
                selectedValue: loginController.bindingForWidget(
                    formId: formId,
                    widgetId: widgetId,
                    defaultValue: widget.value ?? nil
                )
            )
        } else {
            FallbackTriggerView()
        }
    }
}
