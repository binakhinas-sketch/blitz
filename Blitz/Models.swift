import Foundation

struct Friend: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var username: String
    var emoji: String
    var colorHex: String
    var streak: Int
}

enum MessageKind: String, Codable {
    case text, snap, system
}

struct Message: Identifiable, Codable, Hashable {
    let id: UUID
    let friendID: UUID
    let fromMe: Bool
    let kind: MessageKind
    var text: String?
    var imageFile: String?
    var duration: Int      // Sekunden, 0 = unbegrenzt
    var opened: Bool
    let date: Date

    static func text(_ t: String, friend: UUID, fromMe: Bool, opened: Bool = false, date: Date = Date()) -> Message {
        Message(id: UUID(), friendID: friend, fromMe: fromMe, kind: .text, text: t,
                imageFile: nil, duration: 0, opened: opened, date: date)
    }

    static func snap(file: String?, friend: UUID, fromMe: Bool, duration: Int, opened: Bool = false, date: Date = Date()) -> Message {
        Message(id: UUID(), friendID: friend, fromMe: fromMe, kind: .snap, text: nil,
                imageFile: file, duration: duration, opened: opened, date: date)
    }

    static func system(_ t: String, friend: UUID) -> Message {
        Message(id: UUID(), friendID: friend, fromMe: true, kind: .system, text: t,
                imageFile: nil, duration: 0, opened: true, date: Date())
    }
}

struct Story: Identifiable, Codable, Hashable {
    let id: UUID
    let ownerID: UUID?          // nil = meine Story
    let imageFile: String
    let caption: String?
    let date: Date
    var seen: Bool

    var isExpired: Bool { Date().timeIntervalSince(date) > 24 * 3600 }
}

struct Memory: Identifiable, Codable, Hashable {
    let id: UUID
    let imageFile: String
    let date: Date
}

struct AppData: Codable {
    var friends: [Friend]
    var messages: [Message]
    var stories: [Story]
    var memories: [Memory]
    var myName: String
    var myUsername: String
    var myEmoji: String
    var myColorHex: String
    var score: Int
}

struct SnapSession: Identifiable {
    let id = UUID()
    let messages: [Message]
}

struct StorySession: Identifiable {
    let id = UUID()
    let stories: [Story]
}
