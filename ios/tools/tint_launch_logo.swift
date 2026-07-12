// Tints the white launch-screen ੴ glyph into the brand saffron (light + dark legs) so it
// reads on the paper/ink launch backgrounds. Deterministic: white-alpha source × flat color.
// Usage: swift tint_launch_logo.swift <source.png> <outdir>
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3, let src = NSImage(contentsOfFile: args[1]) else {
    fatalError("usage: swift tint_launch_logo.swift <source.png> <outdir>")
}
let outDir = args[2]

func tinted(_ image: NSImage, rgb: (CGFloat, CGFloat, CGFloat), name: String) {
    var rect = CGRect(origin: .zero, size: image.size)
    guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
          let ctx = CGContext(data: nil, width: cg.width, height: cg.height,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("cannot rasterise \(name)") }
    let full = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
    ctx.draw(cg, in: full)
    ctx.setBlendMode(.sourceIn)                       // keep alpha, replace color
    ctx.setFillColor(CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1))
    ctx.fill(full)
    guard let out = ctx.makeImage() else { fatalError("no output for \(name)") }
    let rep = NSBitmapImageRep(cgImage: out)
    rep.size = image.size
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png encode") }
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print("wrote \(outDir)/\(name).png")
}

// Brand saffron — MUST match AccentPalette.saffron in ios/App/Shared/DesignTokens.swift.
tinted(src, rgb: (0xE0 / 255.0, 0x6E / 255.0, 0x09 / 255.0), name: "launch_logo")
tinted(src, rgb: (0xFF / 255.0, 0x8F / 255.0, 0x2E / 255.0), name: "launch_logo_dark")
