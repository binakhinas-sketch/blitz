import SwiftUI

struct StoriesView: View {
    @EnvironmentObject var store: Store
    @State private var playing: StorySession?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            myStoryBubble
                            ForEach(store.friendsWithStories) { f in
                                Button { play(store.stories(of: f.id)) } label: {
                                    VStack(spacing: 6) {
                                        AvatarView(emoji: f.emoji, colorHex: f.colorHex, size: 62,
                                                   ring: store.hasUnseen(f.id))
                                        Text(f.name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 78)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                    }

                    Text("Entdecken")
                        .font(.title2.bold())
                        .padding(.horizontal)

                    if store.allStories.isEmpty {
                        Text("Gerade keine Stories. Mach einen Snap und poste ihn in deine Story!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(store.allStories) { s in
                            StoryCard(story: s)
                                .onTapGesture { play([s]) }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 4)
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 70) }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Stories")
            .refreshable { store.pruneExpiredStories() }
        }
        .onAppear { store.pruneExpiredStories() }
        .fullScreenCover(item: $playing) { s in
            StoryPlayer(stories: s.stories).environmentObject(store)
        }
    }

    private var myStoryBubble: some View {
        Button {
            if !store.myStories.isEmpty { play(store.myStories) }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(emoji: store.data.myEmoji, colorHex: store.data.myColorHex, size: 62,
                               ring: !store.myStories.isEmpty)
                    if store.myStories.isEmpty {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.white, Theme.pink)
                    }
                }
                Text("Meine Story")
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(width: 78)
        }
        .buttonStyle(.plain)
    }

    private func play(_ stories: [Story]) {
        guard !stories.isEmpty else { return }
        playing = StorySession(stories: stories)
    }
}

struct StoryCard: View {
    @EnvironmentObject var store: Store
    let story: Story

    var body: some View {
        Color.clear
            .frame(height: 250)
            .overlay(
                Group {
                    if let img = ImageStore.load(story.imageFile) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Theme.card
                    }
                }
            )
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    if let id = story.ownerID, let f = store.friend(id) {
                        AvatarView(emoji: f.emoji, colorHex: f.colorHex, size: 22)
                        Text(f.name).font(.caption.bold())
                    } else {
                        AvatarView(emoji: store.data.myEmoji, colorHex: store.data.myColorHex, size: 22)
                        Text("Ich").font(.caption.bold())
                    }
                    Spacer()
                    Text(story.date.shortAgo).font(.caption2)
                }
                .foregroundColor(.white)
                .padding(8)
                .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(story.seen ? Color.clear : Theme.pink, lineWidth: 2)
            )
    }
}

struct StoryPlayer: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let stories: [Story]

    @State private var index = 0
    @State private var progress: Double = 0
    @State private var closed = false
    @State private var confirmDelete = false
    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let perStory = 5.0

    private var current: Story? { index < stories.count ? stories[index] : nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let s = current, let img = ImageStore.load(s.imageFile) {
                Image(uiImage: img).resizable().scaledToFit()
            }
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { prev() }
                Color.clear.contentShape(Rectangle()).onTapGesture { next() }
            }
            VStack(spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(stories.indices, id: \.self) { i in
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.3))
                                Capsule().fill(Color.white).frame(width: g.size.width * barValue(i))
                            }
                        }
                        .frame(height: 3)
                    }
                }
                HStack(spacing: 10) {
                    if let s = current {
                        if let id = s.ownerID, let f = store.friend(id) {
                            AvatarView(emoji: f.emoji, colorHex: f.colorHex, size: 34)
                            Text(f.name).font(.headline)
                        } else {
                            AvatarView(emoji: store.data.myEmoji, colorHex: store.data.myColorHex, size: 34)
                            Text("Meine Story").font(.headline)
                        }
                        Text(s.date.shortAgo).font(.caption).foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    if let s = current, s.ownerID == nil {
                        Button { confirmDelete = true } label: {
                            Image(systemName: "trash").font(.system(size: 18, weight: .semibold))
                        }
                    }
                    Button { close() } label: {
                        Image(systemName: "xmark").font(.system(size: 20, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .shadow(color: .black.opacity(0.4), radius: 4)
        }
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.translation.height > 100 { close() }
        })
        .onAppear { markSeen() }
        .onReceive(tick) { _ in
            guard !closed, !confirmDelete else { return }
            progress += 0.05 / perStory
            if progress >= 1 { next() }
        }
        .confirmationDialog("Story löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let s = current { store.deleteStory(s.id) }
                close()
            }
            Button("Abbrechen", role: .cancel) { }
        }
        .statusBar(hidden: true)
    }

    private func barValue(_ i: Int) -> CGFloat {
        if i < index { return 1 }
        if i == index { return CGFloat(min(progress, 1)) }
        return 0
    }

    private func markSeen() {
        if let s = current { store.markSeen(s.id) }
    }

    private func next() {
        guard !closed else { return }
        if index < stories.count - 1 {
            index += 1
            progress = 0
            markSeen()
        } else {
            close()
        }
    }

    private func prev() {
        if index > 0 { index -= 1 }
        progress = 0
    }

    private func close() {
        guard !closed else { return }
        closed = true
        dismiss()
    }
}
