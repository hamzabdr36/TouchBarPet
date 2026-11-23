import AppKit

/// Loads the Mattz Art sprite sheets from the widget bundle, slices them into 80×64 frames
/// and builds a closed-eye copy of the idle frames (used for blinking, purring and napping).
final class CatSprites {
    static let cellWidth = 80
    static let cellHeight = 64
    /// Row inside a cell where the cat's paws touch the ground (same in every sheet).
    static let groundRow = 48

    private(set) var animations: [String: [CGImage]] = [:]

    init(bundle: Bundle) {
        let sheets: [(key: String, file: String, frames: Int)] = [
            ("idle", "IDLE", 8), ("walk", "WALK", 12), ("run", "RUN", 8),
            ("swat", "ATTACK 1", 8), ("hurt", "HURT", 4), ("hop", "JUMP", 3), ("leap", "RUNNING JUMP", 3)
        ]
        for sheet in sheets {
            guard let url = bundle.url(forResource: sheet.file, withExtension: "png", subdirectory: "Sprites")
                    ?? bundle.url(forResource: sheet.file, withExtension: "png"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { continue }
            var frames: [CGImage] = []
            for i in 0..<sheet.frames {
                let rect = CGRect(x: i * Self.cellWidth, y: 0, width: Self.cellWidth, height: Self.cellHeight)
                if let cell = image.cropping(to: rect), let rgba = Self.rgbaCopy(of: cell) { frames.append(rgba) }
            }
            animations[sheet.key] = frames
        }
        if let idle = animations["idle"] {
            animations["idleClosed"] = idle.map { Self.closingEyes($0) ?? $0 }
        }
    }

    func frame(_ name: String, _ index: Int) -> CGImage? {
        guard let list = animations[name] ?? animations["idle"], !list.isEmpty else { return nil }
        return list[((index % list.count) + list.count) % list.count]
    }

    // MARK: - Pixel helpers

    private static func makeContext() -> CGContext? {
        CGContext(data: nil, width: cellWidth, height: cellHeight, bitsPerComponent: 8, bytesPerRow: cellWidth * 4,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    private static func rgbaCopy(of image: CGImage) -> CGImage? {
        guard let ctx = makeContext() else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: cellWidth, height: cellHeight))
        return ctx.makeImage()
    }

    /// Finds the blue eye pixels, paints them with the surrounding fur colour and draws a
    /// one-pixel dark line through the middle, so the eyes read as closed.
    private static func closingEyes(_ image: CGImage) -> CGImage? {
        guard let ctx = makeContext() else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: cellWidth, height: cellHeight))
        guard let raw = ctx.data else { return nil }
        let px = raw.bindMemory(to: UInt8.self, capacity: cellWidth * cellHeight * 4)
        // Bitmap memory starts at the top row of the image.
        func at(_ x: Int, _ y: Int) -> Int { (y * cellWidth + x) * 4 }

        var eyes: [(Int, Int)] = []
        var darkest = (r: 60, g: 34, b: 30)
        for y in 0..<cellHeight {
            for x in 0..<cellWidth {
                let i = at(x, y)
                let r = Int(px[i]), g = Int(px[i + 1]), b = Int(px[i + 2]), a = Int(px[i + 3])
                guard a > 0 else { continue }
                if r < 30 && b > 140 && g > 80 && b > g { eyes.append((x, y)) }
                if r + g + b < darkest.r + darkest.g + darkest.b { darkest = (r, g, b) }
            }
        }
        guard !eyes.isEmpty else { return image }
        let top = eyes.map { $0.1 }.min()!, bottom = eyes.map { $0.1 }.max()!
        let lineY = min(cellHeight - 1, (top + bottom + 1) / 2 + 1)
        for (x, y) in eyes {
            var s = at(x, max(0, top - 2))
            if px[s + 3] == 0 { s = at(max(0, x - 1), y) }
            let i = at(x, y)
            px[i] = px[s]; px[i + 1] = px[s + 1]; px[i + 2] = px[s + 2]; px[i + 3] = 255
        }
        for x in Set(eyes.map { $0.0 }) {
            let i = at(x, lineY)
            px[i] = UInt8(darkest.r); px[i + 1] = UInt8(darkest.g); px[i + 2] = UInt8(darkest.b); px[i + 3] = 255
        }
        return ctx.makeImage()
    }
}
