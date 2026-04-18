import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "Assets/AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let fileManager = FileManager.default
let iconsetURL = outputURL
    .deletingPathExtension()
    .appendingPathExtension("iconset")

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let emoji = "📊"
let sizes: [(points: Int, scale: Int, suffix: String)] = [
    (16, 1, ""),
    (16, 2, "@2x"),
    (32, 1, ""),
    (32, 2, "@2x"),
    (128, 1, ""),
    (128, 2, "@2x"),
    (256, 1, ""),
    (256, 2, "@2x"),
    (512, 1, ""),
    (512, 2, "@2x")
]

for size in sizes {
    let pixels = size.points * size.scale
    let image = NSImage(size: NSSize(width: pixels, height: pixels))

    image.lockFocus()
    NSColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1).setFill()
    NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        xRadius: CGFloat(pixels) * 0.22,
        yRadius: CGFloat(pixels) * 0.22
    ).fill()

    NSColor(red: 0.20, green: 0.82, blue: 0.54, alpha: 1).withAlphaComponent(0.18).setFill()
    NSBezierPath(
        roundedRect: NSRect(
            x: CGFloat(pixels) * 0.08,
            y: CGFloat(pixels) * 0.08,
            width: CGFloat(pixels) * 0.84,
            height: CGFloat(pixels) * 0.84
        ),
        xRadius: CGFloat(pixels) * 0.18,
        yRadius: CGFloat(pixels) * 0.18
    ).fill()

    let fontSize = CGFloat(pixels) * 0.64
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize),
        .paragraphStyle: centeredParagraphStyle
    ]
    let attributed = NSAttributedString(string: emoji, attributes: attributes)
    let textSize = attributed.size()
    let textRect = NSRect(
        x: (CGFloat(pixels) - textSize.width) / 2,
        y: (CGFloat(pixels) - textSize.height) / 2 + CGFloat(pixels) * 0.02,
        width: textSize.width,
        height: textSize.height
    )
    attributed.draw(in: textRect)
    image.unlockFocus()

    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:])
    else {
        throw IconGenerationError.pngEncodingFailed
    }

    let filename = "icon_\(size.points)x\(size.points)\(size.suffix).png"
    try pngData.write(to: iconsetURL.appendingPathComponent(filename))
}

try? fileManager.removeItem(at: outputURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw IconGenerationError.iconutilFailed(process.terminationStatus)
}

try? fileManager.removeItem(at: iconsetURL)

private var centeredParagraphStyle: NSParagraphStyle {
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    return paragraphStyle
}

private enum IconGenerationError: Error {
    case pngEncodingFailed
    case iconutilFailed(Int32)
}
