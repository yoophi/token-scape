import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "docs/screenshot.png"
let imageSize = NSSize(width: 1440, height: 900)
let image = NSImage(size: imageSize)

let background = NSColor(calibratedWhite: 0.94, alpha: 1)
let windowBackground = NSColor(calibratedWhite: 0.985, alpha: 1)
let cardBackground = NSColor.white
let border = NSColor(calibratedWhite: 0.82, alpha: 1)
let text = NSColor(calibratedWhite: 0.12, alpha: 1)
let secondary = NSColor(calibratedWhite: 0.42, alpha: 1)
let claude = NSColor(red: 217 / 255, green: 119 / 255, blue: 87 / 255, alpha: 1)
let codex = NSColor(red: 16 / 255, green: 163 / 255, blue: 127 / 255, alpha: 1)
let orange = NSColor.systemOrange
let red = NSColor.systemRed

func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

func drawText(
    _ value: String,
    at point: NSPoint,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = text,
    alignment: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    value.draw(at: point, withAttributes: attributes)
}

func drawCenteredText(_ value: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = text) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let attributed = NSAttributedString(string: value, attributes: attributes)
    let textSize = attributed.size()
    let origin = NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2)
    attributed.draw(at: origin)
}

func progressBar(in rect: NSRect, progress: CGFloat, color: NSColor) {
    roundedRect(rect, radius: rect.height / 2, fill: NSColor(calibratedWhite: 0.9, alpha: 1))
    let fillRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width * max(0, min(1, progress)), height: rect.height)
    roundedRect(fillRect, radius: rect.height / 2, fill: color)
}

func drawWindowCard(
    rect: NSRect,
    title: String,
    subtitle: String,
    remaining: String,
    percent: String,
    supporting: String,
    progress: CGFloat,
    color: NSColor,
    reset: String
) {
    roundedRect(rect, radius: 8, fill: cardBackground, stroke: border)
    drawText(title, at: NSPoint(x: rect.minX + 18, y: rect.maxY - 42), size: 18, weight: .semibold)
    drawText(subtitle, at: NSPoint(x: rect.minX + 18, y: rect.maxY - 68), size: 13, color: secondary)
    drawText("남은 시간", at: NSPoint(x: rect.maxX - 150, y: rect.maxY - 35), size: 11, color: secondary)
    drawText(remaining, at: NSPoint(x: rect.maxX - 150, y: rect.maxY - 60), size: 22, weight: .bold)
    drawText("남은 비율", at: NSPoint(x: rect.maxX - 150, y: rect.maxY - 88), size: 11, color: secondary)
    drawText(percent, at: NSPoint(x: rect.maxX - 150, y: rect.maxY - 112), size: 17, weight: .bold)
    progressBar(in: NSRect(x: rect.minX + 18, y: rect.minY + 70, width: rect.width - 36, height: 10), progress: progress, color: color)
    drawText("한도 사용률", at: NSPoint(x: rect.minX + 18, y: rect.minY + 40), size: 12, color: secondary)
    drawText(supporting, at: NSPoint(x: rect.maxX - 150, y: rect.minY + 40), size: 12, color: secondary)
    drawText(reset, at: NSPoint(x: rect.minX + 18, y: rect.minY + 18), size: 12, color: secondary)
}

func drawProductColumn(rect: NSRect, title: String, icon: String, accent: NSColor, plan: String?) {
    drawText("\(icon) \(title)", at: NSPoint(x: rect.minX, y: rect.maxY - 28), size: 22, weight: .bold, color: accent)
    if let plan {
        let badge = NSRect(x: rect.maxX - 92, y: rect.maxY - 36, width: 82, height: 26)
        roundedRect(badge, radius: 13, fill: accent.withAlphaComponent(0.14))
        drawCenteredText(plan, in: badge, size: 12, weight: .bold, color: accent)
    }

    drawWindowCard(
        rect: NSRect(x: rect.minX, y: rect.maxY - 230, width: rect.width, height: 170),
        title: "5시간 창",
        subtitle: title == "Codex" ? "짧은 기간 사용량" : "세션 블록",
        remaining: title == "Codex" ? "03:42:18" : "01:18:06",
        percent: title == "Codex" ? "74%" : "26%",
        supporting: title == "Codex" ? "사용 26%" : "82.4K tokens",
        progress: title == "Codex" ? 0.26 : 0.74,
        color: title == "Codex" ? accent : orange,
        reset: title == "Codex" ? "03:42:18 남음 · 03:12 리셋" : "01:18:06 남음 · 00:48 리셋"
    )

    drawWindowCard(
        rect: NSRect(x: rect.minX, y: rect.maxY - 430, width: rect.width, height: 170),
        title: "주간 창",
        subtitle: title == "Codex" ? "긴 기간 사용량" : "7일 블록",
        remaining: title == "Codex" ? "6d 08:14:22" : "4d 11:05:40",
        percent: title == "Codex" ? "91%" : "64%",
        supporting: title == "Codex" ? "사용 9%" : "418.7K tokens",
        progress: title == "Codex" ? 0.09 : 0.36,
        color: accent,
        reset: title == "Codex" ? "6d 08:14:22 남음 · 금 07:30 리셋" : "4d 11:05:40 남음 · 수 18:21 리셋"
    )

    let tokenRect = NSRect(x: rect.minX, y: rect.maxY - 510, width: rect.width, height: 56)
    roundedRect(tokenRect, radius: 8, fill: cardBackground, stroke: border)
    drawText("# 토큰", at: NSPoint(x: tokenRect.minX + 18, y: tokenRect.midY - 7), size: 13, weight: .semibold, color: secondary)
    drawText(title == "Codex" ? "129.4K" : "418.7K", at: NSPoint(x: tokenRect.minX + 100, y: tokenRect.midY - 10), size: 20, weight: .bold)
    drawText(title == "Codex" ? "최근 응답 8.2K tokens" : "1,284개 메시지", at: NSPoint(x: tokenRect.maxX - 170, y: tokenRect.midY - 6), size: 12, color: secondary)
}

image.lockFocus()
background.setFill()
NSRect(origin: .zero, size: imageSize).fill()

let window = NSRect(x: 120, y: 100, width: 1200, height: 700)
roundedRect(window, radius: 14, fill: windowBackground, stroke: NSColor(calibratedWhite: 0.72, alpha: 1))
roundedRect(NSRect(x: window.minX, y: window.maxY - 52, width: window.width, height: 52), radius: 14, fill: NSColor(calibratedWhite: 0.96, alpha: 1))
drawText("AI Code 사용량", at: NSPoint(x: window.minX + 28, y: window.maxY - 36), size: 24, weight: .bold)

let controlsY = window.maxY - 39
let modeRect = NSRect(x: window.maxX - 620, y: controlsY, width: 132, height: 28)
roundedRect(modeRect, radius: 7, fill: NSColor(calibratedWhite: 0.89, alpha: 1), stroke: border)
roundedRect(NSRect(x: modeRect.minX + 2, y: modeRect.minY + 2, width: 64, height: 24), radius: 6, fill: cardBackground)
drawCenteredText("간단히", in: NSRect(x: modeRect.minX, y: modeRect.minY, width: 66, height: 28), size: 12, weight: .semibold)
drawCenteredText("자세히", in: NSRect(x: modeRect.minX + 66, y: modeRect.minY, width: 66, height: 28), size: 12, color: secondary)
drawText("↻ 자동 새로고침", at: NSPoint(x: window.maxX - 475, y: window.maxY - 34), size: 12, color: secondary)
let refreshRect = NSRect(x: window.maxX - 340, y: controlsY, width: 148, height: 28)
roundedRect(refreshRect, radius: 7, fill: NSColor(calibratedWhite: 0.89, alpha: 1), stroke: border)
drawCenteredText("1분   5분   안함", in: refreshRect, size: 12)
roundedRect(NSRect(x: window.maxX - 178, y: controlsY, width: 34, height: 28), radius: 7, fill: cardBackground, stroke: border)
drawCenteredText("↻", in: NSRect(x: window.maxX - 178, y: controlsY, width: 34, height: 28), size: 15, weight: .semibold)
roundedRect(NSRect(x: window.maxX - 132, y: controlsY, width: 34, height: 28), radius: 7, fill: cardBackground, stroke: border)
drawCenteredText("⌖", in: NSRect(x: window.maxX - 132, y: controlsY, width: 34, height: 28), size: 15, weight: .semibold, color: orange)

let contentTop = window.maxY - 86
let columnWidth: CGFloat = 548
drawProductColumn(rect: NSRect(x: window.minX + 28, y: 160, width: columnWidth, height: contentTop - 160), title: "Claude Code", icon: "✦", accent: claude, plan: nil)
let divider = NSRect(x: window.midX - 0.5, y: 150, width: 1, height: contentTop - 150)
border.setFill()
divider.fill()
drawProductColumn(rect: NSRect(x: window.midX + 28, y: 160, width: columnWidth, height: contentTop - 160), title: "Codex", icon: "⌘", accent: codex, plan: "PLUS")

border.setFill()
NSRect(x: window.minX + 24, y: 132, width: window.width - 48, height: 1).fill()
drawText("마지막 업데이트: 23:58:12", at: NSPoint(x: window.minX + 28, y: 108), size: 11, color: secondary)
drawText("자동 새로고침 1분 · 57초 후 새로고침", at: NSPoint(x: window.maxX - 260, y: 108), size: 11, color: secondary)
image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Failed to render screenshot")
}

try FileManager.default.createDirectory(
    at: URL(fileURLWithPath: outputPath).deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: URL(fileURLWithPath: outputPath))
