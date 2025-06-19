import Foundation

public class Session: ObservableObject {
    private let storage: Storage

    @Published public internal(set) var loginInProgress: Bool = false
    @Published public internal(set) var profile: Profile?

    init(storage: Storage) {
        self.storage = storage
    }

    @MainActor
    func load() {
        if let profileData = storage.get(key: "profile")?.data(using: .utf8) {
            do {
                profile = try JSONDecoder().decode(Profile.self, from: profileData)
            } catch {}
        }
    }

    @MainActor
    func update(tokenResponse: TokenResponse) {
        loginInProgress = false
        profile = Profile(tokenResponse: tokenResponse)

        guard let profileData = try? String(decoding: JSONEncoder().encode(profile), as: UTF8.self) else {
            assert(false, "Failed to serialize session content")
        }

        guard storage.set(key: "profile", value: profileData) else {
            assert(false, "Failed to store content to storage")
        }
    }

    @MainActor
    func clear() {
        loginInProgress = false
        profile = nil

        storage.delete(key: "profile")
    }
}

public struct Profile: Codable {
    enum CodingKeys: String, CodingKey {
        case tokenResponse
        case accessTokenExpiresAt
    }

    var tokenResponse: TokenResponse
    var accessTokenExpiresAt: Date

    public internal(set) var claims: [String: Any]

    init(tokenResponse: TokenResponse) {
        self.tokenResponse = tokenResponse
        accessTokenExpiresAt = Date(timeIntervalSinceNow: Double(tokenResponse.expiresIn))

        claims = JWTUtils.parseJWT(tokenResponse.idToken)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokenResponse = try container.decode(TokenResponse.self, forKey: .tokenResponse)
        accessTokenExpiresAt = try container.decode(Date.self, forKey: .accessTokenExpiresAt)

        claims = JWTUtils.parseJWT(tokenResponse.idToken)
    }
}
