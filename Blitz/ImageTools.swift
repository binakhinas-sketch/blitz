import UIKit

/// Speichert Bilder als JPEG im Dokumente-Ordner der App.
enum ImageStore {
    static let dir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let d = docs.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    private static let cache = NSCache<NSString, UIImage>()

    static func save(_ image: UIImage) -> String {
        let name = UUID().uuidString + ".jpg"
        if let jpg = image.jpegData(compressionQuality: 0.85) {
            try? jpg.write(to: dir.appendingPathComponent(name), options: .atomic)
        }
        cache.setObject(image, forKey: name as NSString)
        return name
    }

    static func load(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        if let c = cache.object(forKey: name as NSString) { return c }
        guard let img = UIImage(contentsOfFile: dir.appendingPathComponent(name).path) else { return nil }
        cache.setObject(img, forKey: name as NSString)
        return img
    }

    static func delete(_ name: String?) {
        guard let name else { return }
        cache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
    }

    static func deleteAll() {
        cache.removeAllObjects()
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }
}

extension UIImage {
    /// Dreht das Bild richtig herum und verkleinert es auf eine handliche Größe.
    func normalized(maxDimension: CGFloat = 1600) -> UIImage {
        let longest = max(size.width, size.height)
        let factor = longest > maxDimension ? maxDimension / longest : 1
        let newSize = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: fmt).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

enum Composer {
    /// Brennt die Textzeile (Caption) ins Bild ein.
    static func render(image: UIImage, caption: String, yFraction: CGFloat) -> UIImage {
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return image }
        let size = image.size
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = image.scale
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            let fontSize = size.width * 0.05
            let barHeight = fontSize * 2
            let y = min(max(0, size.height * yFraction - barHeight / 2), size.height - barHeight)
            UIColor.black.withAlphaComponent(0.55).setFill()
            ctx.fill(CGRect(x: 0, y: y, width: size.width, height: barHeight))
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: para
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let h = str.size().height
            str.draw(in: CGRect(x: 16, y: y + (barHeight - h) / 2, width: size.width - 32, height: h + 4))
        }
    }

    /// Erzeugt ein buntes Bild mit Emoji und Text (für simulierte Snaps und Stories der Freunde).
    static func art(emoji: String, text: String, colors: [UIColor]) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let cg = ctx.cgContext
            let cgColors = colors.map { $0.cgColor } as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) {
                cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            let e = NSAttributedString(string: emoji, attributes: [.font: UIFont.systemFont(ofSize: 380)])
            let es = e.size()
            e.draw(at: CGPoint(x: (size.width - es.width) / 2, y: size.height * 0.36 - es.height / 2))
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            let tAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 86, weight: .heavy),
                .foregroundColor: UIColor.white,
                .paragraphStyle: para
            ]
            NSAttributedString(string: text, attributes: tAttr)
                .draw(in: CGRect(x: 60, y: size.height * 0.6, width: size.width - 120, height: 420))
        }
    }
}
