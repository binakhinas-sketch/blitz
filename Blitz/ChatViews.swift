import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var store: Store
    @State private var path: [Friend] = []
    @State private var viewing: SnapSession?
    @State private var showAdd = false
    @State private var showProfile = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.sortedFriends) { f in
                        ChatRow(friend: f)
                            .contentShape(Rectangle())
                            .onTapGesture { open(f) }
                            .contextMenu {
                                Button { path.append(f) } label: {
                                    Label("Chat öffnen", systemImage: "bubble.left")
                                }
                                Button(role: .destructive) { store.removeFriend(f.id) } label: {
                                    Label("Freund entfernen", systemImage: "person.badge.minus")
                                }
                            }
                        Divider()
                            .overlay(Color.white.opacity(0.06))
                            .padding(.leading, 80)
                    }
                    if store.data.friends.isEmpty {
                        VStack(spacing: 12) {
                            Text("👋").font(.system(size: 50))
                            Text("Noch keine Freunde").font(.headline)
                            Button("Freund hinzufügen") { showAdd = true }
                        }
                        .padding(.top, 80)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 70) }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showProfile = true } label: {
                        AvatarView(emoji: store.data.myEmoji, colorHex: store.data.myColorHex, size: 32)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(Theme.gradient)
                    }
                }
            }
            .navigationDestination(for: Friend.self) { f in
                ChatView(friendID: f.id)
            }
        }
        .fullScreenCover(item: $viewing) { s in
            SnapViewer(messages: s.messages).environmentObject(store)
        }
        .sheet(isPresented: $showAdd) {
            AddFriendView().environmentObject(store)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView().environmentObject(store)
        }
    }

    private func open(_ f: Friend) {
        let snaps = store.unopenedSnaps(from: f.id)
        if snaps.isEmpty {
            path.append(f)
        } else {
            viewing = SnapSession(messages: snaps)
        }
    }
}

struct ChatRow: View {
    @EnvironmentObject var store: Store
    let friend: Friend

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(emoji: friend.emoji, colorHex: friend.colorHex, size: 50)
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                status
            }
            Spacer()
            if friend.streak > 0 {
                Text("\(friend.streak) 🔥")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var status: some View {
        let unopened = store.unopenedSnaps(from: friend.id)
        if !unopened.isEmpty {
            statusLine(icon: "square.fill", color: Theme.pink,
                       text: unopened.count > 1 ? "\(unopened.count) neue Snaps" : "Neuer Snap", bold: true)
        } else if let m = store.lastMessage(for: friend.id) {
            switch (m.kind, m.fromMe) {
            case (.snap, true):
                statusLine(icon: m.opened ? "arrowtriangle.right" : "arrowtriangle.right.fill", color: Theme.pink,
                           text: (m.opened ? "Geöffnet" : "Zugestellt") + " · " + m.date.shortAgo, bold: false)
            case (.snap, false):
                statusLine(icon: "square", color: Theme.pink, text: "Angesehen · " + m.date.shortAgo, bold: false)
            case (.text, true):
                statusLine(icon: "arrowtriangle.right.fill", color: Theme.blue, text: "Gesendet · " + m.date.shortAgo, bold: false)
            case (.text, false):
                statusLine(icon: m.opened ? "bubble.left" : "bubble.left.fill", color: Theme.blue,
                           text: m.opened ? "Empfangen · " + m.date.shortAgo : "Neuer Chat", bold: !m.opened)
            case (.system, _):
                statusLine(icon: "camera.viewfinder", color: .green, text: "Screenshot · " + m.date.shortAgo, bold: false)
            }
        } else {
            statusLine(icon: "hand.wave.fill", color: Theme.orange, text: "Tippe zum Chatten", bold: false)
        }
    }

    private func statusLine(icon: String, color: Color, text: String, bold: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13, weight: bold ? .bold : .regular))
                .foregroundColor(bold ? color : .secondary)
        }
    }
}

struct ChatView: View {
    @EnvironmentObject var store: Store
    let friendID: UUID
    @State private var draft = ""
    @State private var viewing: SnapSession?

    var body: some View {
        let msgs = store.messages(for: friendID)
        let friend = store.friend(friendID)

        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(msgs) { m in
                        bubble(m).id(m.id)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                store.hideTabBar = true
                store.markChatRead(friendID)
                if let last = msgs.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .onChange(of: msgs.count) { _ in
                store.markChatRead(friendID)
                if let last = store.messages(for: friendID).last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { inputBar }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let friend {
                    HStack(spacing: 8) {
                        AvatarView(emoji: friend.emoji, colorHex: friend.colorHex, size: 30)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(friend.name).font(.headline)
                            Text(friend.streak > 0 ? "\(friend.streak) 🔥 Streak" : "@\(friend.username)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .onDisappear { store.hideTabBar = false }
        .fullScreenCover(item: $viewing) { s in
            SnapViewer(messages: s.messages).environmentObject(store)
        }
    }

    @ViewBuilder
    private func bubble(_ m: Message) -> some View {
        switch m.kind {
        case .system:
            Text(m.text ?? "")
                .font(.caption.weight(.semibold))
                .foregroundColor(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        case .text:
            HStack {
                if m.fromMe { Spacer(minLength: 50) }
                Text(m.text ?? "")
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(m.fromMe ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.card))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                if !m.fromMe { Spacer(minLength: 50) }
            }
        case .snap:
            HStack {
                if m.fromMe { Spacer() }
                Button {
                    if !m.fromMe && !m.opened { viewing = SnapSession(messages: [m]) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: m.opened ? "square" : "square.fill")
                            .foregroundColor(Theme.pink)
                        Text(snapLabel(m))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.pink.opacity(0.6), lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                if !m.fromMe { Spacer() }
            }
        }
    }

    private func snapLabel(_ m: Message) -> String {
        if m.fromMe { return m.opened ? "Snap geöffnet" : "Snap gesendet" }
        return m.opened ? "Snap angesehen" : "Tippe zum Ansehen"
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Nachricht senden", text: $draft)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Capsule().fill(Theme.card))
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.gradient))
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func send() {
        store.sendText(draft, to: friendID)
        draft = ""
    }
}

struct SnapViewer: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let messages: [Message]

    @State private var index = 0
    @State private var remaining: Double = 0
    @State private var image: UIImage?
    @State private var closed = false
    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var current: Message? {
        index < messages.count ? messages[index] : nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("Snap nicht mehr verfügbar").foregroundColor(.secondary)
            }
            VStack {
                HStack(spacing: 10) {
                    if let m = current, let f = store.friend(m.friendID) {
                        AvatarView(emoji: f.emoji, colorHex: f.colorHex, size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.name).font(.headline).foregroundColor(.white)
                            Text(m.date.shortAgo).font(.caption).foregroundColor(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    if let m = current, m.duration > 0 {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.3), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: max(0, remaining / Double(m.duration)))
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(Int(ceil(max(remaining, 0))))")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .frame(width: 34, height: 34)
                    }
                }
                .padding()
                .shadow(color: .black.opacity(0.4), radius: 4)
                Spacer()
                Text("Tippen zum Weiter · Snap verschwindet danach")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { next() }
        .onAppear { load() }
        .onReceive(tick) { _ in
            guard !closed, let m = current, m.duration > 0, image != nil else { return }
            remaining -= 0.05
            if remaining <= 0 { next() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            if let m = current { store.screenshotTaken(of: m.friendID) }
        }
        .statusBar(hidden: true)
    }

    private func load() {
        guard let m = current else { close(); return }
        image = ImageStore.load(m.imageFile)
        remaining = Double(m.duration)
    }

    private func next() {
        guard !closed else { return }
        if let m = current { store.openSnap(m.id) }
        index += 1
        if index >= messages.count { close() } else { load() }
    }

    private func close() {
        guard !closed else { return }
        closed = true
        dismiss()
    }
}

struct AddFriendView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "😀"
    private let emojis = ["😀", "😎", "🥳", "🤠", "👻", "🐱", "🐶", "🦁", "🐵", "🦄", "🍉", "⚽️", "🎸", "🚀", "💎", "🌈"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z. B. Alex", text: $name)
                }
                Section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(emojis, id: \.self) { e in
                            Text(e)
                                .font(.system(size: 28))
                                .padding(4)
                                .background(Circle().fill(e == emoji ? Theme.pink.opacity(0.35) : Color.clear))
                                .onTapGesture { emoji = e }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    Text("Freunde sind in dieser Version simuliert: Sie antworten automatisch auf deine Snaps und Nachrichten.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Freund hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        store.addFriend(name: name, emoji: emoji)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
