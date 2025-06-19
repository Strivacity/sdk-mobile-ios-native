import SwiftUI

struct RadioSelect: View {
    @EnvironmentObject var loginController: LoginController

    let formId: String
    let widget: SelectWidget
    @Binding var selectedValue: String?

    var body: some View {
        var error = loginController.errorMessage(formId: formId, widgetId: widget.id) ?? ""

        VStack(alignment: .leading) {
            Group {
                if let hasSuboptions = widget.options[0].options {
                    ForEach(widget.options, id: \.self) { option in
                        Text(widget.label ?? "")

                        if let subOptions = option.options {
                            ForEach(subOptions, id: \.self) { subOption in
                                SelectOption(option: subOption, selectedValue: $selectedValue)
                            }
                        }
                    }
                } else {
                    Text(widget.label ?? "")

                    ForEach(widget.options, id: \.self) { option in
                        SelectOption(option: option, selectedValue: $selectedValue)
                    }
                }
            }
        }
        .onAppear {
            if widget.value != nil {
                selectedValue = widget.value
            } else if widget.options.first!.type == "item" {
                selectedValue = widget.options.first?.value
            } else if widget.options.first!.type == "group" {
                selectedValue = widget.options.first?.options?.first?.value
            }
        }.disabled(widget.readonly)
    }

    struct SelectOption: View {
        var option: SelectWidget.Option
        @Binding var selectedValue: String?

        var body: some View {
            HStack {
                Group {
                    Button {
                        selectedValue = option.value
                    } label: {
                        Image(systemName: selectedValue == option.value ? "record.circle" : "circle")

                        Text(option.label ?? "")
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
    }
}
