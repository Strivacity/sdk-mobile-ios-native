import SwiftUI

public struct FallbackTriggerView: View {
    @EnvironmentObject var loginController: LoginController

    public init() {}

    public var body: some View {
        VStack {}
            .task {
                await loginController.triggerFallback()
            }
    }
}
