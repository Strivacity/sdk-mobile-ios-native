import SwiftUI

struct SimpleSelect: View {
    let formId: String
    let widget: SelectWidget
    @State private var showOptions = false
    @Binding var selectedValue: String?
    @EnvironmentObject var loginController: LoginController

    var body: some View {
        var error = loginController.errorMessage(formId: formId, widgetId: widget.id) ?? ""

        SelectField(
            widget: widget,
            showOptions: $showOptions,
            selectedValue: $selectedValue
        )
        .actionSheet(isPresented: $showOptions) {
            ActionSheet(
                title: Text(widget.label!),
                buttons: widget.options.map { option in
                    .default(Text(option.label!)) {
                        selectedValue = option.value
                    }
                } + [.cancel {}]
            )
        }
        .onAppear {
            if let value = widget.value {
                selectedValue = value
            }
        }
    }
}
