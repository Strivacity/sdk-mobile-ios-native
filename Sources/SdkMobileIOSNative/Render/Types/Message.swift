import Foundation

public struct Message: Decodable, Equatable {
    public let type: String
    public let text: String
}

public enum Messages {
    case global(Message)
    case form([String: [String: Message]])
}

extension Messages: Decodable, Equatable {
    enum CodingKeys: String, CodingKey {
        case global
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let global = try? container.decodeIfPresent(Message.self, forKey: .global)

        if let global = global {
            self = .global(global)
        } else {
            self = try .form(decoder.singleValueContainer().decode([String: [String: Message]].self))
        }
    }
}
