import SwiftUI

struct MultiSelectView: View {
    @EnvironmentObject var loginController: LoginController

    // periphery:ignore
    let screen: String
    let formId: String
    let widgetId: String

    let widget: MultiSelectWidget

    var body: some View {
        var error = loginController.errorMessage(formId: formId, widgetId: widgetId) ?? ""

        VStack(alignment: .leading) {
            Text(widget.label)

            ForEach(widget.options, id: \.self) { option in
                SelectOption(
                    option: option,
                    selectedValues: loginController.bindingForWidget(
                        formId: formId,
                        widgetId: widgetId,
                        defaultValue: widget.value
                    )
                )
            }
        }
    }

    struct SelectOption: View {
        var option: MultiSelectWidget.Option
        @Binding var selectedValues: [String?]

        var body: some View {
            HStack {
                Group {
                    Button {
                        if let index = selectedValues.firstIndex(of: option.value) {
                            selectedValues.remove(at: index)
                        } else {
                            selectedValues.append(option.value)
                        }
                    } label: {
                        Image(systemName: selectedValues
                            .contains(option.value) ? "checkmark.rectangle.fill" : "rectangle")

                        Text(option.label)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
    }
}
