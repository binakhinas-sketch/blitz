import SwiftUI
import PhotosUI
import AVFoundation

struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct CameraScreen: View {
    @EnvironmentObject var store: Store
    @ObservedObject var camera: CameraService
    @Binding var tab: AppTab

    @State private var captured: CapturedPhoto?
    @State private var showMemories = false
    @State private var showProfile = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var flashOverlay = false
    @State private var baseZoom: CGFloat = 1
    @State private var zoom: CGFloat = 1

    var body: some View {
        ZStack {
            preview
                .ignoresSafeArea()
            controls
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                let raw = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    if let raw, let img = UIImage(data: raw) {
                        captured = CapturedPhoto(image: img.normalized())
                    }
                    pickerItem = nil
                }
            }
        }
        .fullScreenCover(item: $captured) { photo in
            EditorView(original: photo.image) { sent in
                captured = nil
                if sent {
                    withAnimation { tab = .chat }
                }
            }
            .environmentObject(store)
        }
        .sheet(isPresented: $showMemories) {
            MemoriesView().environmentObject(store)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView().environmentObject(store)
        }
    }

    // MARK: - Vorschau

    private var preview: some View {
        ZStack {
            Color.black
            if camera.denied {
                deniedView
            } else {
                CameraPreview(session: camera.session)
            }
            if flashOverlay {
                Color.white.transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { flip() }
        .gesture(
            MagnificationGesture()
                .onChanged { v in
                    zoom = min(max(baseZoom * v, 1), 8)
                    camera.setZoom(zoom)
                }
                .onEnded { _ in baseZoom = zoom }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 40)
                .onEnded { v in
                    guard abs(v.translation.width) > abs(v.translation.height) else { return }
                    if v.translation.width > 80 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { tab = .chat }
                    } else if v.translation.width < -80 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { tab = .stories }
                    }
                }
        )
    }

    private var deniedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.gradient)
            Text("Kein Kamerazugriff")
                .font(.title3.bold())
                .foregroundColor(.white)
            Text("Erlaube Blitz den Zugriff auf die Kamera in den Einstellungen.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Einstellungen öffnen") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Capsule().fill(Theme.gradient))
        }
    }

    // MARK: - Bedienelemente

    private var controls: some View {
        VStack {
            HStack(alignment: .top) {
                Button { showProfile = true } label: {
                    AvatarView(emoji: store.data.myEmoji, colorHex: store.data.myColorHex, size: 40)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                }
                Spacer()
                VStack(spacing: 14) {
                    CircleIconButton(systemName: "arrow.triangle.2.circlepath") { flip() }
                    CircleIconButton(systemName: camera.flashOn ? "bolt.fill" : "bolt.slash.fill") {
                        camera.flashOn.toggle()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            if zoom > 1.05 {
                Text(String(format: "%.1fx", zoom))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.4)))
                    .padding(.bottom, 10)
            }

            HStack {
                Button { showMemories = true } label: {
                    sideIcon("photo.stack.fill")
                }
                Spacer()
                shutter
                Spacer()
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    sideIcon("photo.on.rectangle.angled")
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 84)
        }
    }

    private func sideIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 22, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .background(Circle().fill(Color.black.opacity(0.35)))
            .shadow(color: .black.opacity(0.35), radius: 4)
    }

    private var shutter: some View {
        Button(action: takePhoto) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 6)
                    .frame(width: 86, height: 86)
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 72, height: 72)
            }
            .shadow(color: .black.opacity(0.35), radius: 6)
        }
    }

    // MARK: - Aktionen

    private func flip() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        zoom = 1
        baseZoom = 1
        camera.flip()
    }

    private func takePhoto() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeOut(duration: 0.08)) { flashOverlay = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeIn(duration: 0.25)) { flashOverlay = false }
        }
        camera.capture { img in
            if let img {
                captured = CapturedPhoto(image: img.normalized())
            }
        }
    }
}
