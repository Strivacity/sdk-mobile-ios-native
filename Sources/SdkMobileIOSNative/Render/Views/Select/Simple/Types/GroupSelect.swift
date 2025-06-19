import SwiftUI

struct GroupSelect: View {
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
        ).sheet(isPresented: $showOptions) {
            GroupSheet(
                widgetOptions: widget.options,
                selectedValue: $selectedValue,
                isPresented: $showOptions
            )
        }
        .onAppear {
            if let value = widget.value {
                selectedValue = value
            }
        }
    }
}

struct GroupSheet: View {
    let widgetOptions: [SelectWidget.Option]
    @Binding var selectedValue: String?
    @Binding var isPresented: Bool

    var body: some View {
        List {
            ForEach(widgetOptions, id: \.self) { option in
                Section(header: Text(option.label!)) {
                    OptionButtons(
                        options: option.options!,
                        selectedValue: $selectedValue,
                        isPresented: $isPresented
                    )
                }
            }
        }

        Button("Cancel") {
            isPresented = false
        }
    }
}

struct OptionButtons: View {
    let options: [SelectWidget.Option]
    @Binding var selectedValue: String?
    @Binding var isPresented: Bool

    var body: some View {
        ForEach(options, id: \.self) { option in
            Button {
                selectedValue = option.value
                isPresented = false
            } label: {
                Text(option.label!)
            }
        }
    }
}
