import SwiftUI

struct StaticView: View {
    // periphery:ignore
    let screen: String
    // periphery:ignore
    let formId: String
    // periphery:ignore
    let widgetId: String

    let widget: StaticWidget

    @State var htmlContentValue: String = ""

    var body: some View {
        if widget.render.type == "html" {
            HtmlTextView(htmlContent: $htmlContentValue)
                .onAppear {
                    htmlContentValue = widget.value
                }
                .onChange(of: widget.value) { value in
                    htmlContentValue = value
                }
        } else if widget.render.type == "text" {
            Text(widget.value)
        } else {
            FallbackTriggerView()
        }
    }
}
