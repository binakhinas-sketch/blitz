import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = CGFloat((v >> 16) & 0xFF) / 255
        let g = CGFloat((v >> 8) & 0xFF) / 255
        let b = CGFloat(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

enum Theme {
    static let purple = Color(hex: "#7B2FF7")
    static let pink = Color(hex: "#FF3D8B")
    static let orange = Color(hex: "#FFA41B")
    static let blue = Color(hex: "#3DA9FF")
    static let bg = Color(hex: "#0E0B16")
    static let card = Color(hex: "#1D1729")
    static let gradient = LinearGradient(colors: [purple, pink, orange],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
    static let avatarColors = ["#3A86FF", "#FF006E", "#FB5607", "#8338EC", "#06D6A0", "#FFBE0B", "#EF476F", "#118AB2"]
}

struct AvatarView: View {
    let emoji: String
    let colorHex: String
    var size: CGFloat = 44
    var ring: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.55)],
                                     startPoint: .top, endPoint: .bottom))
            Text(emoji).font(.system(size: size * 0.55))
        }
        .frame(width: size, height: size)
        .padding(ring ? 4 : 0)
        .overlay(
            Circle().strokeBorder(Theme.gradient, lineWidth: ring ? 3 : 0)
        )
    }
}

extension Date {
    var shortAgo: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: "de_DE")
        if Date().timeIntervalSince(self) < 60 { return "gerade eben" }
        return f.localizedString(for: self, relativeTo: Date())
    }
}

struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.black.opacity(0.35)))
                .shadow(color: .black.opacity(0.35), radius: 4)
        }
    }
}
