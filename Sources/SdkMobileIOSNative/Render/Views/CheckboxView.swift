import SwiftUI

struct CheckboxView: View {
    @EnvironmentObject var loginController: LoginController

    // periphery:ignore
    let screen: String
    let formId: String
    let widgetId: String

    let widget: CheckboxWidget

    var body: some View {
        var error = loginController.errorMessage(formId: formId, widgetId: widgetId) ?? ""

        CheckField(widget: widget,
                   isOn: loginController.bindingForWidget(
                       formId: formId,
                       widgetId: widgetId,
                       defaultValue: widget.value
                   ))
    }

    struct CheckField: View {
        let widget: CheckboxWidget

        @State var htmlContentValue: String = ""
        @Binding var isOn: Bool

        var body: some View {
            if widget.render.type == "checkboxShown" {
                Toggle(isOn: $isOn) {
                    Label(widget: widget, htmlContentValue: htmlContentValue)
                }
                .toggleStyle(DefaultToggleStyle())
            } else if widget.render.type == "checkboxHidden" {
                Toggle(isOn: $isOn) {
                    Label(widget: widget, htmlContentValue: htmlContentValue)
                }
                .toggleStyle(HiddenToggleVisibleLabelStyle())
                .onAppear {
                    isOn = true
                }
            } else {
                FallbackTriggerView()
            }
        }

        struct Label: View {
            var widget: CheckboxWidget
            @State var htmlContentValue: String

            var body: some View {
                Group {
                    if widget.render.labelType == "html" {
                        HtmlTextView(htmlContent: $htmlContentValue)
                            .onAppear {
                                htmlContentValue = widget.label
                            }
                            .onChange(of: widget.label) { label in
                                htmlContentValue = label
                            }
                    } else if widget.render.labelType == "text" {
                        Text(widget.label)
                    } else {
                        FallbackTriggerView()
                    }
                }
            }
        }

        struct HiddenToggleVisibleLabelStyle: ToggleStyle {
            func makeBody(configuration: Configuration) -> some View {
                HStack {
                    configuration.label
                }
            }
        }
    }
}
