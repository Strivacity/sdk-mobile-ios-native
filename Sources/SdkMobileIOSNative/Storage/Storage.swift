import Foundation

public protocol Storage {
    func set(key: String, value: String) -> Bool
    func get(key: String) -> String?
    func delete(key: String) -> Bool
}
