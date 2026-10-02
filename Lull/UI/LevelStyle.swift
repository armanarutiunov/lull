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

    // Each level has its own shape so it reads without relying on colour.
    var symbolName: String {
        switch self {
        case .safe: "moon.fill"
        case .caution: "exclamationmark.circle.fill"
        case .unsafe: "flame.fill"
        }
    }

    var color: Color { Color(nsColor: nsColor) }

    var nsColor: NSColor {
        switch self {
        case .safe: .systemGreen
        case .caution: .systemYellow
        case .unsafe: .systemRed
        }
    }

    var menuBarImage: NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [nsColor]))
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)?
            .withSymbolConfiguration(configuration) ?? NSImage()
        // Template images are tinted monochrome by the menu bar, which would hide the level colour.
        image.isTemplate = false
        return image
    }
}
