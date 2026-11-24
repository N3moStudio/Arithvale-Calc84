import UIKit

/// Screen-local image measurements for the system Photos picker in the UI journey.
struct PickerScreenshot {
    let width: Int
    let height: Int
    private let pixels: [UInt8]

    init?(_ image: CGImage, width: Int = 180) {
        let height = max(1, width * image.height / image.width)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.width = width; self.height = height; self.pixels = pixels
    }

    private func color(_ x: Int, _ y: Int) -> SIMD3<Int32> {
        let offset = 4 * (y * width + x)
        return SIMD3(Int32(pixels[offset]), Int32(pixels[offset + 1]), Int32(pixels[offset + 2]))
    }

    private func difference(_ a: SIMD3<Int32>, _ b: SIMD3<Int32>) -> Int {
        Int(abs(a.x - b.x) + abs(a.y - b.y) + abs(a.z - b.z))
    }

    /// Compare the seeded PNG's interior features at grid sizes from two to twelve columns.
    func thumbnail(matching icon: PickerScreenshot) -> CGRect? {
        let samples = (0..<6).flatMap { y in (0..<6).map { x in
            (x: x * 2 + 1, y: y * 2 + 1, color: icon.color((x * 2 + 1) * icon.width / 12, (y * 2 + 1) * icon.height / 12))
        } }
        var bestError = samples.count * 3 * 18
        var best: CGRect?
        for columns in 2...12 {
            let size = width / columns
            guard size <= height else { continue }
            for y in stride(from: 0, through: height - size, by: 2) {
                for x in stride(from: 0, through: width - size, by: 2) {
                    var error = 0
                    for sample in samples {
                        error += difference(color(x + sample.x * size / 12, y + sample.y * size / 12), sample.color)
                        if error >= bestError { break }
                    }
                    if error < bestError {
                        bestError = error; best = CGRect(x: x, y: y, width: size, height: size)
                    }
                }
            }
        }
        return best
    }

    /// The disabled check button changes fill across its face when selection becomes valid.
    /// Require an actual visual change around the AX control's estimated center before tapping.
    func confirmation(after: PickerScreenshot, near center: CGPoint, radius: CGFloat) -> CGPoint? {
        guard width == after.width, height == after.height, radius >= 3, radius.isFinite,
              center.x.isFinite, center.y.isFinite else { return nil }
        let offsets = [(-0.5, -0.5), (0.5, -0.5), (-0.5, 0.5), (0.5, 0.5)]
        let changed = offsets.filter { offset in
            let x = Int(center.x + radius * CGFloat(offset.0)), y = Int(center.y + radius * CGFloat(offset.1))
            guard (0..<width).contains(x), (0..<height).contains(y) else { return false }
            let old = color(x, y)
            return (80...235).contains(old.x) && max(old.x, old.y, old.z) - min(old.x, old.y, old.z) < 25
                && difference(old, after.color(x, y)) > 80
        }
        return changed.count >= 3 ? center : nil
    }

    func changedHeaderButton(after: PickerScreenshot, above thumbnail: CGRect, radius: CGFloat) -> CGPoint? {
        var bounds = CGRect.null
        for y in 0..<Int(thumbnail.minY) {
            for x in (width / 2)..<width {
                let point = CGPoint(x: x, y: y)
                if confirmation(after: after, near: point, radius: radius) != nil {
                    bounds = bounds.union(CGRect(origin: point, size: CGSize(width: 1, height: 1)))
                }
            }
        }
        guard !bounds.isNull, bounds.width >= radius / 2, bounds.height >= radius / 2,
              bounds.width <= 3 * radius, bounds.height <= 3 * radius else { return nil }
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
}
