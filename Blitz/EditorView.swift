import SwiftUI

struct EditorView: View {
    @EnvironmentObject var store: Store
    let original: UIImage
    /// true = Snap wurde verschickt
    let onClose: (Bool) -> Void

    @State private var filterIndex = 0
    @State private var filtered: UIImage
    @State private var caption = ""
    @State private var editingCaption = false
    @State private var captionY: CGFloat = 0.65
    @State private var duration = 5
    @State private var showSend = false
    @State private var toast: String?
    @FocusState private var captionFocused: Bool

    private let filters = SnapFilter.allCases
    private let durations = [1, 3, 5, 10, 0]

    init(original: UIImage, onClose: @escaping (Bool) -> Void) {
        self.original = original
        self.onClose = onClose
        _filtered = State(initialValue: original)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: filtered)
                .resizable()
                .scaledToFit()
                .overlay(captionOverlay)
                .contentShape(Rectangle())
                .onTapGesture {
                    if editingCaption {
                        captionFocused = false
                        editingCaption = false
                    } else {
                        startCaption()
                    }
                }
                .gesture(DragGesture(minimumDistance: 25).onEnded(swipe))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                topBar
                Spacer()
                filterStrip
                bottomBar
            }

            if let toast {
                Text(toast)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.75)))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: filterIndex) { _ in applyFilter() }
        .sheet(isPresented: $showSend) {
            SendToView(image: finalImage(), duration: duration, caption: caption) {
                onClose(true)
            }
            .environmentObject(store)
        }
        .statusBar(hidden: true)
    }

    // MARK: - Caption

    private var captionOverlay: some View {
        GeometryReader { geo in
            if editingCaption || !caption.isEmpty {
                TextField("", text: $caption)
                    .focused($captionFocused)
                    .font(.system(size: geo.size.width * 0.05, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .submitLabel(.done)
                    .onSubmit { editingCaption = false }
                    .padding(.horizontal, 16)
                    .frame(width: geo.size.width, height: geo.size.width * 0.1)
                    .background(Color.black.opacity(0.55))
                    .position(x: geo.size.width / 2, y: geo.size.height * captionY)
                    .gesture(
                        DragGesture(coordinateSpace: .named("editorImage"))
                            .onChanged { v in
                                captionY = min(max(v.location.y / max(geo.size.height, 1), 0.05), 0.95)
                            }
                    )
            }
        }
        .coordinateSpace(name: "editorImage")
    }

    private func startCaption() {
        editingCaption = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { captionFocused = true }
    }

    // MARK: - Leisten

    private var topBar: some View {
        HStack(alignment: .top) {
            CircleIconButton(systemName: "xmark") { onClose(false) }
            Spacer()
            Text(filters[filterIndex].rawValue)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.black.opacity(0.4)))
                .opacity(filterIndex == 0 ? 0 : 1)
            Spacer()
            VStack(spacing: 14) {
                CircleIconButton(systemName: "textformat") { startCaption() }
                Button(action: cycleDuration) {
                    VStack(spacing: 0) {
                        Image(systemName: "timer").font(.system(size: 16, weight: .semibold))
                        Text(duration == 0 ? "∞" : "\(duration)s").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.35)))
                }
                CircleIconButton(systemName: "arrow.down.to.line") { saveMemory() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var filterStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(filters.enumerated()), id: \.element.id) { i, f in
                        Button {
                            withAnimation { filterIndex = i }
                        } label: {
                            Text(f.rawValue)
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(i == filterIndex ? AnyShapeStyle(Theme.gradient)
                                                                    : AnyShapeStyle(Color.black.opacity(0.45)))
                                )
                        }
                        .id(i)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: filterIndex) { i in
                withAnimation { proxy.scrollTo(i, anchor: .center) }
            }
        }
        .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        HStack {
            Button {
                store.addStory(finalImage(), caption: caption.isEmpty ? nil : caption)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onClose(false)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Story")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.black.opacity(0.55)))
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
                .shadow(color: Theme.pink.opacity(0.5), radius: 10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    // MARK: - Aktionen

    private func swipe(_ v: DragGesture.Value) {
        guard abs(v.translation.width) > abs(v.translation.height), abs(v.translation.width) > 40 else { return }
        withAnimation {
            if v.translation.width < 0 {
                filterIndex = (filterIndex + 1) % filters.count
            } else {
                filterIndex = (filterIndex - 1 + filters.count) % filters.count
            }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func applyFilter() {
        let f = filters[filterIndex]
        let src = original
        DispatchQueue.global(qos: .userInitiated).async {
            let out = FilterEngine.apply(f, to: src)
            DispatchQueue.main.async {
                if filters[filterIndex] == f { filtered = out }
            }
        }
    }

    private func cycleDuration() {
        UISelectionFeedbackGenerator().selectionChanged()
        let i = durations.firstIndex(of: duration) ?? 0
        duration = durations[(i + 1) % durations.count]
    }

    private func finalImage() -> UIImage {
        Composer.render(image: filtered, caption: caption, yFraction: captionY)
    }

    private func saveMemory() {
        let img = finalImage()
        store.addMemory(img)
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast("Gespeichert ✓")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring()) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation { toast = nil }
        }
    }
}

struct SendToView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let duration: Int
    let caption: String
    let onSent: () -> Void

    @State private var selected: Set<UUID> = []
    @State private var toStory = false
    @State private var search = ""

    private var friends: [Friend] {
        let all = store.sortedFriends
        guard !search.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.username.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $toStory) {
                        Label("Meine Story", systemImage: "circle.dashed.inset.filled")
                    }
                    .tint(Theme.pink)
                }
                Section("Freunde") {
                    ForEach(friends) { f in
                        Button { toggle(f.id) } label: {
                            HStack(spacing: 12) {
                                AvatarView(emoji: f.emoji, colorHex: f.colorHex, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.name).font(.headline)
                                    Text("@\(f.username)").font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if f.streak > 0 {
                                    Text("\(f.streak) 🔥").font(.subheadline)
                                }
                                Image(systemName: selected.contains(f.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(selected.contains(f.id) ? AnyShapeStyle(Theme.gradient)
                                                                              : AnyShapeStyle(Color.secondary))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $search, prompt: "Freunde suchen")
            .navigationTitle("Senden an …")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zurück") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selected.isEmpty || toStory {
                    Button(action: send) {
                        HStack {
                            Text(summary).lineLimit(1)
                            Spacer()
                            Image(systemName: "paperplane.fill")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Theme.gradient))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private var summary: String {
        var names = store.data.friends.filter { selected.contains($0.id) }.map(\.name)
        if toStory { names.insert("Meine Story", at: 0) }
        return names.joined(separator: ", ")
    }

    private func toggle(_ id: UUID) {
        UISelectionFeedbackGenerator().selectionChanged()
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    private func send() {
        store.sendSnap(image, duration: duration, to: selected, toStory: toStory,
                       caption: caption.isEmpty ? nil : caption)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onSent() }
    }
}
