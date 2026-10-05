import AppKit
import SwiftUI

extension Level {
    var title: String {
        switch self {
        case .safe: "Safe to leave"
        case .caution: "Keep an eye on it"
        case .unsafe: "Not safe to leave"
        }
    }

    // Each level has its own shape so it reads without relying on colour: resting moon,
    // working fan, fire.
    var symbolName: String {
        switch self {
        case .safe: "moon.stars.fill"
        case .caution: "fan.fill"
        case .unsafe: "flame.fill"
        }
    }

    // Top to bottom. Mid-tones chosen to stay legible on both light and dark menu bars.
    var gradientColors: [NSColor] {
        switch self {
        case .safe: [NSColor(rgb: 0x5EEAD4), NSColor(rgb: 0x10B981)]
        case .caution: [NSColor(rgb: 0xFCD34D), NSColor(rgb: 0xF59E0B)]
        case .unsafe: [NSColor(rgb: 0xFF9F0A), NSColor(rgb: 0xFF3B30)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors.map { Color(nsColor: $0) }, startPoint: .top, endPoint: .bottom)
    }

    var menuBarImage: NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)?
            .withSymbolConfiguration(configuration)
        else { return NSImage() }
        let colors = gradientColors
        let image = NSImage(size: symbol.size, flipped: false) { rect in
            NSGradient(colors: colors)?.draw(in: rect, angle: -90)
            symbol.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        // Template images are tinted monochrome by the menu bar, which would hide the level colour.
        image.isTemplate = false
        image.accessibilityDescription = title
        return image
    }
}

private extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(
            srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255,
            green: CGFloat(rgb >> 8 & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
