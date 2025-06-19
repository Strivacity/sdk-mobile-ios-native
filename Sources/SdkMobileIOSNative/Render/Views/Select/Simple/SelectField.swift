import SwiftUI

struct SelectField: View {
    let widget: SelectWidget
    @Binding var showOptions: Bool
    @Binding var selectedValue: String?

    var body: some View {
        Button {
            showOptions = true
        }
        label: {
            HStack {
                VStack(alignment: .leading) {
                    if let label = widget.label {
                        SelectLabel(widget: widget, label: label, selectedValue: $selectedValue)
                    } else {
                        SelectLabel(
                            widget: widget,
                            label: widget.options[0].label!,
                            selectedValue: $selectedValue
                        )
                    }
                }

                Spacer()

                Button {
                    selectedValue = nil
                } label: {
                    if selectedValue != nil && !widget.validator.required {
                        Image(systemName: "xmark")
                    }
                }
                Image(systemName: "chevron.up.chevron.down")
            }
        }
    }

    private struct SelectLabel: View {
        let widget: SelectWidget
        let label: String

        @Binding var selectedValue: String?
        @State var selectedLabel: String?

        var body: some View {
            HStack(spacing: 0) {
                Text(label)
            }
            .onAppear {
                setSelectedLabel(widget.options)
            }
            .onChange(of: selectedValue) { _ in
                if selectedValue == nil {
                    selectedLabel = nil
                } else {
                    setSelectedLabel(widget.options)
                }
            }

            Text(selectedLabel ?? "")
        }

        private func setSelectedLabel(_ options: [SelectWidget.Option]) {
            for option in options {
                if option.value == selectedValue {
                    selectedLabel = option.label
                    return
                }
                if let nestedOptions = option.options {
                    setSelectedLabel(nestedOptions)
                }
            }
        }
    }
}
