import SwiftUI

@main
struct BlitzApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.pink)
        }
    }
}

enum AppTab: Int {
    case chat = 0, camera = 1, stories = 2
}

struct RootView: View {
    @EnvironmentObject var store: Store
    @StateObject private var camera = CameraService()
    @State private var tab: AppTab = .camera

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            Group {
                switch tab {
                case .chat:
                    ChatListView()
                        .transition(.move(edge: .leading))
                case .camera:
                    CameraScreen(camera: camera, tab: $tab)
                        .transition(.opacity)
                case .stories:
                    StoriesView()
                        .transition(.move(edge: .trailing))
                }
            }

            if !store.hideTabBar {
                BottomBar(tab: $tab, unread: store.unreadCount)
            }
        }
    }
}

struct BottomBar: View {
    @Binding var tab: AppTab
    let unread: Int

    var body: some View {
        HStack {
            barButton(.chat, icon: "bubble.left.fill", label: "Chat", badge: unread)
            Spacer()
            barButton(.camera, icon: "camera.fill", label: "Kamera", badge: 0)
            Spacer()
            barButton(.stories, icon: "person.2.fill", label: "Stories", badge: 0)
        }
        .padding(.horizontal, 44)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(tab == .camera ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Material.ultraThinMaterial))
    }

    private func barButton(_ t: AppTab, icon: String, label: String, badge: Int) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { tab = t }
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .frame(width: 34, height: 26)
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.pink))
                            .offset(x: 10, y: -6)
                    }
                }
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(tab == t ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color.white.opacity(0.8)))
            .shadow(color: .black.opacity(tab == .camera ? 0.4 : 0), radius: 3)
        }
    }
}
