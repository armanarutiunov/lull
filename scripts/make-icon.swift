import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow(); shadow.shadowBlurRadius = 28; shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.set()
NSColor(red: 0.07, green: 0.09, blue: 0.2, alpha: 1).setFill(); tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

tilePath.addClip()
NSGradient(colors: [
    NSColor(red: 0.20, green: 0.27, blue: 0.52, alpha: 1),
    NSColor(red: 0.10, green: 0.12, blue: 0.30, alpha: 1),
    NSColor(red: 0.04, green: 0.05, blue: 0.14, alpha: 1),
])!.draw(in: tile, angle: -90)

let center = CGPoint(x: 540, y: 540)
let glow = NSGradient(colors: [NSColor(red: 1, green: 0.92, blue: 0.7, alpha: 0.35), NSColor(red: 1, green: 0.92, blue: 0.7, alpha: 0)])!
glow.draw(fromCenter: center, radius: 0, toCenter: center, radius: 360, options: [])

let r: CGFloat = 230
ctx.saveGState()
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
let disc = NSBezierPath(ovalIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r))
NSGradient(colors: [NSColor(red: 1, green: 0.96, blue: 0.84, alpha: 1), NSColor(red: 0.98, green: 0.84, blue: 0.55, alpha: 1)])!.draw(in: disc, angle: -60)
ctx.setBlendMode(.clear)
let cut = NSBezierPath(ovalIn: CGRect(x: center.x - r + 120, y: center.y - r + 85, width: 2 * r * 0.95, height: 2 * r * 0.95))
cut.fill()
ctx.endTransparencyLayer()
ctx.restoreGState()

for (x, y, s, a) in [(300.0, 720.0, 9.0, 0.9), (720, 770, 6, 0.7), (760, 330, 8, 0.8), (260, 330, 5, 0.6), (650, 640, 4, 0.5), (380, 820, 4, 0.5)] {
    NSColor.white.withAlphaComponent(a).setFill()
    NSBezierPath(ovalIn: CGRect(x: x - s, y: y - s, width: 2 * s, height: 2 * s)).fill()
}

NSGradient(colors: [NSColor.white.withAlphaComponent(0.12), NSColor.white.withAlphaComponent(0)])!
    .draw(in: CGRect(x: 100, y: 600, width: 824, height: 324), angle: -90)

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"))
