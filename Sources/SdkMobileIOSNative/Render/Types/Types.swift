import Foundation

public struct Screen: Decodable, Equatable {
    public let screen: String?
    public let branding: Branding?
    public let hostedUrl: String?
    public let finalizeUrl: String?

    public let forms: [FormWidget]?
    public let layout: Layout?
    public internal(set) var messages: Messages?
}

public struct Branding: Decodable, Equatable {
    public let logoUrl: String?
    public let copyright: String?
    public let siteTermUrl: String?
    public let privacyPolicyUrl: String?
}

enum ParsingError: Error, Equatable {
    case widget(type: String)
    case layout(type: String)
}
