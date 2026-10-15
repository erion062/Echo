import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

extension Color {
    static let echoAccent = Color(red: 1.0, green: 0.22, blue: 0.37)
    static let echoCard = Color(white: 0.11)
}

@MainActor
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds > 0 else { return "0:00" }
    let total = Int(seconds.rounded(.down))
    let (h, m, s) = (total / 3600, total / 60 % 60, total % 60)
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}

func formatLength(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    if minutes < 60 { return "\(minutes) min" }
    return "\(minutes / 60) hr \(minutes % 60) min"
}

/// Loads saved artwork from disk and derives a background tint from it.
@MainActor
enum ArtworkStore {
    private static let cache = NSCache<NSString, UIImage>()
    private static var tints: [String: Color] = [:]
    private static let context = CIContext(options: [.workingColorSpace: NSNull()])

    static func image(for id: String) -> UIImage? {
        if let cached = cache.object(forKey: id as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: Storage.artworkURL(id).path) else { return nil }
        cache.setObject(image, forKey: id as NSString)
        return image
    }

    static func tint(for id: String) -> Color? {
        if let tint = tints[id] { return tint }
        guard let image = image(for: id), let input = CIImage(image: image) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = input
        filter.extent = input.extent
        guard let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255, blue: CGFloat(pixel[2]) / 255, alpha: 1)
            .getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let tint = Color(hue: hue, saturation: min(saturation * 1.35, 0.8), brightness: min(max(brightness, 0.32), 0.58))
        tints[id] = tint
        return tint
    }

    static func forget(_ id: String) {
        cache.removeObject(forKey: id as NSString)
        tints[id] = nil
    }
}

/// Springy press feedback used across the app.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Large white Apple-style call-to-action.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.white.opacity(isEnabled ? 1 : 0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(.smooth, value: isEnabled)
    }
}
