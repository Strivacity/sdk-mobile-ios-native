import Foundation

public struct WidgetLayout: Decodable, Equatable {
    public let formId: String
    public let widgetId: String
}

public struct SingleLayout: Decodable, Equatable {
    public let items: [Layout]
}

public enum Layout {
    case widget(WidgetLayout)
    case horizontal(SingleLayout)
    case vertical(SingleLayout)
}

extension Layout: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "widget":
            self = try .widget(WidgetLayout(from: decoder))
        case "horizontal":
            self = try .horizontal(SingleLayout(from: decoder))
        case "vertical":
            self = try .vertical(SingleLayout(from: decoder))
        default:
            throw ParsingError.layout(type: type)
        }
    }
}
