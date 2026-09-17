// Deterministic app-icon generator — ੴ set in Sant Lipi, brand gold on warm ink (concept A).
// Produces the three iOS 18 appearance legs at 1024×1024:
//   icon-1024.png        light: warm-ink field #171412, brand-gold glyph #FFBC0D
//   icon-1024-dark.png   dark: deepest ink #0E0C0A, brand-gold glyph
//   icon-1024-tinted.png tinted: grayscale glyph on black (system applies the tint)
// Colors MUST match AccentPalette/Ink in ios/App/Shared/DesignTokens.swift.
// Usage: swift make_app_icon.swift <path-to-SantLipi.ttf> <outdir>
import AppKit
import CoreText

let args = CommandLine.arguments
guard args.count == 3 else { fatalError("usage: swift make_app_icon.swift <SantLipi.ttf> <outdir>") }
let fontURL = URL(fileURLWithPath: args[1])
let outDir = args[2]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

guard CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil) ||
      NSFont(name: "SantLipi-ExtraLight", size: 12) != nil else {
    fatalError("could not register \(fontURL.path)")
}

let SIZE = 1024
func rgb(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

func render(_ name: String, background: (CGContext) -> Void, glyphColor: NSColor) {
    guard let ctx = CGContext(data: nil, width: SIZE, height: SIZE, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("ctx") }
    background(ctx)

    // ੴ centred, sized to sit comfortably inside the icon grid (~55% of the canvas —
    // the kaar's sweep needs clear margin; at 640 it grazed the top-right edge).
    let font = NSFont(name: "SantLipi-ExtraLight", size: 540)!
    let str = NSAttributedString(string: "ੴ", attributes: [.font: font, .foregroundColor: glyphColor])
    let line = CTLineCreateWithAttributedString(str)
    let bounds = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: (CGFloat(SIZE) - bounds.width) / 2 - bounds.minX,
                               y: (CGFloat(SIZE) - bounds.height) / 2 - bounds.minY)
    CTLineDraw(line, ctx)

    guard let img = ctx.makeImage() else { fatalError("img") }
    let rep = NSBitmapImageRep(cgImage: img)
    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    print("wrote \(outDir)/\(name).png")
}

let full = CGRect(x: 0, y: 0, width: SIZE, height: SIZE)

// light — brand-book icon concept A: warm-ink field, brand-gold glyph. Flat (no gradient),
// and never a gold mark on red (see docs/brand/gurbani-soul-brand-book.md §5).
render("icon-1024", background: { ctx in
    ctx.setFillColor(rgb(0x171412).cgColor)
    ctx.fill(full)
}, glyphColor: rgb(0xFFBC0D))

// dark — deepest ink field (Ink.paper darkHC), brand-gold glyph
render("icon-1024-dark", background: { ctx in
    ctx.setFillColor(rgb(0x0E0C0A).cgColor)
    ctx.fill(full)
}, glyphColor: rgb(0xFFBC0D))

// tinted — grayscale on black; iOS applies the user's tint to the glyph luminance
render("icon-1024-tinted", background: { ctx in
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fill(full)
}, glyphColor: NSColor.white)
