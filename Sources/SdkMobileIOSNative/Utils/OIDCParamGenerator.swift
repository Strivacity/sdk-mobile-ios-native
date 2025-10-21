import CommonCrypto
import Foundation

class OIDCParamGenerator {
    static func generateRandomString(byteLengths: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteLengths)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteLengths, &bytes)
        let randomString = Data(bytes).base64URLEncodedString()
        return randomString
    }

    static func generateCodeVerifier() -> String {
        let verifier = OIDCParamGenerator.generateRandomString(byteLengths: 64)
        return verifier
    }

    static func generateCodeChallenge(from verifier: String) -> String {
        let data = verifier.data(using: .ascii)!

        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }

        let hash = Data(buffer)
        return hash.base64URLEncodedString()
    }

    static func generateState() -> String {
        let state = OIDCParamGenerator.generateRandomString(byteLengths: 16)
        return state
    }

    static func generateNonce() -> String {
        let nonce = OIDCParamGenerator.generateRandomString(byteLengths: 16)
        return nonce
    }
}
