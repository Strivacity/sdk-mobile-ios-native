import Foundation

struct ErrorEnvelope: Decodable {
    let error: String
    let errorDescription: String?

    init(from: Data) throws {
        let decoder = JSONDecoder()
        self = try decoder.decode(ErrorEnvelope.self, from: from)
    }

    private enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}
