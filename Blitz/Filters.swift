import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum SnapFilter: String, CaseIterable, Identifiable {
    case none = "Original"
    case vivid = "Vivid"
    case sunset = "Sunset"
    case ice = "Ice"
    case noir = "Noir"
    case mono = "Mono"
    case chrome = "Chrome"
    case vintage = "Vintage"
    case comic = "Comic"
    case vignette = "Vignette"
    case pixel = "Pixel"

    var id: String { rawValue }
}

enum FilterEngine {
    static let context = CIContext()

    static func apply(_ f: SnapFilter, to image: UIImage) -> UIImage {
        guard f != .none, let cg = image.cgImage else { return image }
        let input = CIImage(cgImage: cg)
        var out: CIImage?

        switch f {
        case .none:
            out = input
        case .vivid:
            let x = CIFilter.colorControls()
            x.inputImage = input
            x.saturation = 1.6
            x.contrast = 1.12
            out = x.outputImage
        case .sunset:
            let x = CIFilter.colorMatrix()
            x.inputImage = input
            x.rVector = CIVector(x: 1.15, y: 0, z: 0, w: 0)
            x.gVector = CIVector(x: 0, y: 1.0, z: 0, w: 0)
            x.bVector = CIVector(x: 0, y: 0, z: 0.8, w: 0)
            x.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            x.biasVector = CIVector(x: 0.03, y: 0.01, z: 0, w: 0)
            out = x.outputImage
        case .ice:
            let x = CIFilter.colorMatrix()
            x.inputImage = input
            x.rVector = CIVector(x: 0.85, y: 0, z: 0, w: 0)
            x.gVector = CIVector(x: 0, y: 1.0, z: 0, w: 0)
            x.bVector = CIVector(x: 0, y: 0, z: 1.2, w: 0)
            x.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
            x.biasVector = CIVector(x: 0, y: 0.01, z: 0.04, w: 0)
            out = x.outputImage
        case .noir:
            let x = CIFilter.photoEffectNoir()
            x.inputImage = input
            out = x.outputImage
        case .mono:
            let x = CIFilter.photoEffectMono()
            x.inputImage = input
            out = x.outputImage
        case .chrome:
            let x = CIFilter.photoEffectChrome()
            x.inputImage = input
            out = x.outputImage
        case .vintage:
            let x = CIFilter.photoEffectFade()
            x.inputImage = input
            out = x.outputImage
        case .comic:
            let x = CIFilter.comicEffect()
            x.inputImage = input
            out = x.outputImage
        case .vignette:
            let x = CIFilter.vignette()
            x.inputImage = input
            x.intensity = 1.4
            x.radius = 2.2
            out = x.outputImage
        case .pixel:
            let x = CIFilter.pixellate()
            x.inputImage = input
            x.scale = Float(max(input.extent.width, input.extent.height) / 70)
            x.center = CGPoint(x: input.extent.midX, y: input.extent.midY)
            out = x.outputImage
        }

        guard let result = out?.cropped(to: input.extent),
              let cgOut = context.createCGImage(result, from: input.extent) else { return image }
        return UIImage(cgImage: cgOut, scale: image.scale, orientation: .up)
    }
}
