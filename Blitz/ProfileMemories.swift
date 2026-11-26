import SwiftUI

struct MemoriesView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Memory?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 3)

    private var memories: [Memory] {
        store.data.memories.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 50))
                            .foregroundStyle(Theme.gradient)
                        Text("Noch keine Erinnerungen").font(.headline)
                        Text("Tippe beim Bearbeiten eines Snaps auf ⬇︎, um ihn hier zu speichern.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 3) {
                            ForEach(memories) { m in
                                Color.clear
                                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                                    .overlay(
                                        Group {
                                            if let img = ImageStore.load(m.imageFile) {
                                                Image(uiImage: img).resizable().scaledToFill()
                                            } else {
                                                Theme.card
                                            }
                                        }
                                    )
                                    .clipped()
                                    .contentShape(Rectangle())
                                    .onTapGesture { selected = m }
                            }
                        }
                    }
                }
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Erinnerungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .fullScreenCover(item: $selected) { m in
            MemoryDetail(memory: m).environmentObject(store)
        }
    }
}

struct MemoryDetail: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let memory: Memory
    @State private var showSend = false
    @State private var confirmDelete = false

    var body: some View {
        let img = ImageStore.load(memory.imageFile)
        ZStack {
            Color.black.ignoresSafeArea()
            if let img {
                Image(uiImage: img).resizable().scaledToFit()
            }
            VStack {
                HStack {
                    CircleIconButton(systemName: "xmark") { dismiss() }
                    Spacer()
                    Text(memory.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Spacer()
                    CircleIconButton(systemName: "trash") { confirmDelete = true }
                }
                .padding()
                Spacer()
                HStack(spacing: 12) {
                    if let img {
                        ShareLink(item: Image(uiImage: img),
                                  preview: SharePreview("Blitz Snap", image: Image(uiImage: img))) {
                            Label("Teilen", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.black.opacity(0.55)))
                        }
                    }
                    Spacer()
                    Button { showSend = true } label: {
                        HStack(spacing: 8) {
                            Text("Senden an")
                            Image(systemName: "paperplane.fill")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.gradient))
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showSend) {
            if let img {
                SendToView(image: img, duration: 5, caption: "") { dismiss() }
                    .environmentObject(store)
            }
        }
        .confirmationDialog("Erinnerung löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                store.deleteMemory(memory.id)
                dismiss()
            }
            Button("Abbrechen", role: .cancel) { }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    private let emojis = ["🤩", "😎", "🦊", "🐼", "👽", "🤖", "🐸", "🦄", "🔥", "💀", "👑", "🍕", "🐯", "🌚", "🥷", "🧸"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 10) {
                        AvatarView(emoji: store.data.myEmoji, colorHex: store.data.myColorHex, size: 96, ring: true)
                        Text(store.data.myName).font(.title2.bold())
                        Text("@\(store.data.myUsername)")
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                            Text("\(store.data.score) Blitz-Score")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.gradient)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Profil") {
                    TextField("Name", text: $store.data.myName)
                    TextField("Benutzername", text: $store.data.myUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(emojis, id: \.self) { e in
                            Text(e)
                                .font(.system(size: 28))
                                .padding(4)
                                .background(Circle().fill(e == store.data.myEmoji ? Theme.pink.opacity(0.35) : Color.clear))
                                .onTapGesture { store.data.myEmoji = e }
                        }
                    }
                    .padding(.vertical, 4)
                    HStack {
                        ForEach(Theme.avatarColors, id: \.self) { c in
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 28, height: 28)
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: c == store.data.myColorHex ? 3 : 0))
                                .onTapGesture { store.data.myColorHex = c }
                            if c != Theme.avatarColors.last { Spacer(minLength: 0) }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Statistik") {
                    statRow("Freunde", "\(store.data.friends.count)")
                    statRow("Snaps gesendet", "\(store.sentSnapCount)")
                    statRow("Längste Streak", "\(store.data.friends.map(\.streak).max() ?? 0) 🔥")
                    statRow("Erinnerungen", "\(store.data.memories.count)")
                }

                Section {
                    Button("Alles zurücksetzen", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Mein Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .confirmationDialog("Wirklich alles löschen? Chats, Stories und Erinnerungen sind dann weg.",
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Alles löschen", role: .destructive) {
                    store.resetAll()
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) { }
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary)
        }
    }
}
