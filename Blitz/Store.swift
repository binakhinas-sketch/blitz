import SwiftUI
import UIKit

@MainActor
final class Store: ObservableObject {
    @Published var data: AppData {
        didSet { save() }
    }
    /// Blendet die untere Leiste aus (z. B. im Chat).
    @Published var hideTabBar = false

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("blitz-data.json")
        if let raw = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: raw) {
            data = decoded
        } else {
            data = Store.makeSeed()
        }
        pruneExpiredStories()
        save()
    }

    private func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }

    // MARK: - Abfragen

    func friend(_ id: UUID) -> Friend? {
        data.friends.first { $0.id == id }
    }

    func messages(for id: UUID) -> [Message] {
        data.messages.filter { $0.friendID == id }.sorted { $0.date < $1.date }
    }

    func lastMessage(for id: UUID) -> Message? {
        messages(for: id).last
    }

    func unopenedSnaps(from id: UUID) -> [Message] {
        messages(for: id).filter { !$0.fromMe && $0.kind == .snap && !$0.opened }
    }

    var sortedFriends: [Friend] {
        data.friends.sorted {
            (lastMessage(for: $0.id)?.date ?? .distantPast) > (lastMessage(for: $1.id)?.date ?? .distantPast)
        }
    }

    var unreadCount: Int {
        data.messages.filter { !$0.fromMe && !$0.opened }.count
    }

    var sentSnapCount: Int {
        data.messages.filter { $0.fromMe && $0.kind == .snap }.count
    }

    // MARK: - Snaps & Chat

    func sendSnap(_ image: UIImage, duration: Int, to friendIDs: Set<UUID>, toStory: Bool, caption: String?) {
        var d = data
        let now = Date()
        for id in friendIDs {
            let alreadyToday = d.messages.contains {
                $0.friendID == id && $0.fromMe && $0.kind == .snap && Calendar.current.isDateInToday($0.date)
            }
            if !alreadyToday, let i = d.friends.firstIndex(where: { $0.id == id }) {
                d.friends[i].streak += 1
            }
            d.messages.append(.snap(file: nil, friend: id, fromMe: true, duration: duration, date: now))
        }
        if toStory {
            d.stories.append(Story(id: UUID(), ownerID: nil, imageFile: ImageStore.save(image),
                                   caption: caption, date: now, seen: true))
        }
        d.score += friendIDs.count + (toStory ? 2 : 0)
        data = d
        friendIDs.forEach { scheduleReply(from: $0) }
    }

    func addStory(_ image: UIImage, caption: String?) {
        data.stories.append(Story(id: UUID(), ownerID: nil, imageFile: ImageStore.save(image),
                                  caption: caption, date: Date(), seen: true))
        data.score += 2
    }

    func sendText(_ text: String, to id: UUID) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        data.messages.append(.text(t, friend: id, fromMe: true))
        scheduleReply(from: id)
    }

    func openSnap(_ messageID: UUID) {
        guard let i = data.messages.firstIndex(where: { $0.id == messageID }), !data.messages[i].opened else { return }
        var d = data
        ImageStore.delete(d.messages[i].imageFile)
        d.messages[i].opened = true
        d.messages[i].imageFile = nil
        d.score += 1
        data = d
    }

    func markChatRead(_ friendID: UUID) {
        let hasUnread = data.messages.contains { $0.friendID == friendID && !$0.fromMe && $0.kind == .text && !$0.opened }
        guard hasUnread else { return }
        var d = data
        for i in d.messages.indices where d.messages[i].friendID == friendID && !d.messages[i].fromMe && d.messages[i].kind == .text {
            d.messages[i].opened = true
        }
        data = d
    }

    func screenshotTaken(of friendID: UUID) {
        data.messages.append(.system("📸 Du hast einen Screenshot gemacht!", friend: friendID))
    }

    // MARK: - Simulierte Freunde

    private static let replies = [
        "haha safe 😂", "digga was 💀", "wie krass", "bin grad unterwegs, meld mich später",
        "lol 😭", "sieht gut aus 🔥", "wann treffen wir uns?", "nicer snap",
        "😂😂😂", "bro was machst du", "sheesh", "omg 😍", "warte ich ruf dich gleich an"
    ]

    private static let snapIdeas: [(String, String)] = [
        ("🍕", "Pizza Time"), ("🎮", "Zocke grad"), ("🏀", "Training"), ("🌇", "Was ein View"),
        ("😴", "Bin so müde"), ("🎧", "Neuer Song 🔥"), ("🍔", "Hunger"), ("🚗", "Unterwegs"),
        ("📚", "Lernen 😩"), ("☕️", "Erstmal Kaffee"), ("🐶", "Guck mal wer da ist")
    ]

    private func scheduleReply(from friendID: UUID) {
        let delay = Double.random(in: 2.5...6)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.markMySentOpened(friendID)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.receiveReply(from: friendID)
        }
    }

    private func markMySentOpened(_ friendID: UUID) {
        guard data.messages.contains(where: { $0.friendID == friendID && $0.fromMe && $0.kind == .snap && !$0.opened }) else { return }
        var d = data
        for i in d.messages.indices where d.messages[i].friendID == friendID && d.messages[i].fromMe && d.messages[i].kind == .snap {
            d.messages[i].opened = true
        }
        data = d
    }

    private func receiveReply(from friendID: UUID) {
        guard let f = friend(friendID) else { return }
        if Int.random(in: 0..<10) < 4 {
            let idea = Store.snapIdeas.randomElement() ?? ("⚡️", "Yo")
            let img = Composer.art(emoji: idea.0, text: idea.1,
                                   colors: [UIColor(hex: f.colorHex), UIColor(hex: "#120E1C")])
            let duration = [3, 5, 10].randomElement() ?? 5
            data.messages.append(.snap(file: ImageStore.save(img), friend: friendID, fromMe: false, duration: duration))
        } else {
            data.messages.append(.text(Store.replies.randomElement() ?? "😂", friend: friendID, fromMe: false))
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Freunde verwalten

    func addFriend(name: String, emoji: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let username = clean.lowercased().replacingOccurrences(of: " ", with: ".")
        let f = Friend(id: UUID(), name: clean, username: username, emoji: emoji,
                       colorHex: Theme.avatarColors.randomElement() ?? "#3A86FF", streak: 0)
        var d = data
        d.friends.append(f)
        d.messages.append(.text("Hey, danke fürs Adden! 👋", friend: f.id, fromMe: false))
        data = d
    }

    func removeFriend(_ id: UUID) {
        var d = data
        d.messages.filter { $0.friendID == id }.forEach { ImageStore.delete($0.imageFile) }
        d.stories.filter { $0.ownerID == id }.forEach { ImageStore.delete($0.imageFile) }
        d.messages.removeAll { $0.friendID == id }
        d.stories.removeAll { $0.ownerID == id }
        d.friends.removeAll { $0.id == id }
        data = d
    }

    // MARK: - Stories

    var myStories: [Story] {
        data.stories.filter { $0.ownerID == nil && !$0.isExpired }.sorted { $0.date < $1.date }
    }

    func stories(of id: UUID) -> [Story] {
        data.stories.filter { $0.ownerID == id && !$0.isExpired }.sorted { $0.date < $1.date }
    }

    func hasUnseen(_ id: UUID) -> Bool {
        stories(of: id).contains { !$0.seen }
    }

    var friendsWithStories: [Friend] {
        data.friends
            .filter { !stories(of: $0.id).isEmpty }
            .sorted { hasUnseen($0.id) && !hasUnseen($1.id) }
    }

    var allStories: [Story] {
        data.stories.filter { !$0.isExpired }.sorted { $0.date > $1.date }
    }

    func markSeen(_ storyID: UUID) {
        guard let i = data.stories.firstIndex(where: { $0.id == storyID }), !data.stories[i].seen else { return }
        data.stories[i].seen = true
    }

    func deleteStory(_ storyID: UUID) {
        guard let s = data.stories.first(where: { $0.id == storyID }) else { return }
        ImageStore.delete(s.imageFile)
        data.stories.removeAll { $0.id == storyID }
    }

    func pruneExpiredStories() {
        var d = data
        let expired = d.stories.filter { $0.isExpired }
        let friendStoriesLeft = d.stories.contains { $0.ownerID != nil && !$0.isExpired }
        guard !expired.isEmpty || !friendStoriesLeft else { return }
        expired.forEach { ImageStore.delete($0.imageFile) }
        d.stories.removeAll { $0.isExpired }
        if !friendStoriesLeft {
            d.stories += Store.generateFriendStories(d.friends)
        }
        data = d
    }

    private static func generateFriendStories(_ friends: [Friend]) -> [Story] {
        var result: [Story] = []
        for f in friends.shuffled().prefix(4) {
            for _ in 0..<Int.random(in: 1...2) {
                let idea = snapIdeas.randomElement() ?? ("⚡️", "Yo")
                let img = Composer.art(emoji: idea.0, text: idea.1,
                                       colors: [UIColor(hex: f.colorHex), UIColor(hex: "#120E1C")])
                result.append(Story(id: UUID(), ownerID: f.id, imageFile: ImageStore.save(img), caption: idea.1,
                                    date: Date().addingTimeInterval(-Double.random(in: 300...36000)), seen: false))
            }
        }
        return result
    }

    // MARK: - Erinnerungen

    func addMemory(_ image: UIImage) {
        data.memories.append(Memory(id: UUID(), imageFile: ImageStore.save(image), date: Date()))
    }

    func deleteMemory(_ id: UUID) {
        guard let m = data.memories.first(where: { $0.id == id }) else { return }
        ImageStore.delete(m.imageFile)
        data.memories.removeAll { $0.id == id }
    }

    // MARK: - Reset

    func resetAll() {
        ImageStore.deleteAll()
        data = Store.makeSeed()
    }

    // MARK: - Startdaten

    static func makeSeed() -> AppData {
        let leon = Friend(id: UUID(), name: "Leon", username: "leon.x", emoji: "😎", colorHex: "#3A86FF", streak: 12)
        let mia = Friend(id: UUID(), name: "Mia", username: "mia_20", emoji: "🦋", colorHex: "#FF006E", streak: 34)
        let can = Friend(id: UUID(), name: "Can", username: "can.k", emoji: "🏀", colorHex: "#FB5607", streak: 5)
        let lea = Friend(id: UUID(), name: "Lea", username: "lea.vibes", emoji: "🌸", colorHex: "#8338EC", streak: 0)
        let jonas = Friend(id: UUID(), name: "Jonas", username: "jonas07", emoji: "🎮", colorHex: "#06D6A0", streak: 2)
        let friends = [leon, mia, can, lea, jonas]
        let now = Date()

        let miaSnap = Composer.art(emoji: "☀️", text: "Guten Morgen!",
                                   colors: [UIColor(hex: mia.colorHex), UIColor(hex: "#120E1C")])
        let messages: [Message] = [
            .snap(file: ImageStore.save(miaSnap), friend: mia.id, fromMe: false, duration: 5,
                  date: now.addingTimeInterval(-600)),
            .text("yo was geht heute?", friend: leon.id, fromMe: false, date: now.addingTimeInterval(-1800)),
            .snap(file: nil, friend: can.id, fromMe: true, duration: 3, opened: true,
                  date: now.addingTimeInterval(-5400)),
            .text("hast du die Hausaufgaben?", friend: jonas.id, fromMe: true, date: now.addingTimeInterval(-9000)),
            .text("Hiii 👋", friend: lea.id, fromMe: false, opened: true, date: now.addingTimeInterval(-86000))
        ]

        return AppData(friends: friends,
                       messages: messages,
                       stories: generateFriendStories(friends),
                       memories: [],
                       myName: "Ich",
                       myUsername: "ich",
                       myEmoji: "🤩",
                       myColorHex: "#7B2FF7",
                       score: 120)
    }
}
