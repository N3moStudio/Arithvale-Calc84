#if os(iOS)
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PrivatePhotoCopy {
    /// Decode only pixels, apply orientation, and encode a new JPEG without copying
    /// EXIF, GPS, filenames or source metadata. Originals and Live Photo pairs stay intact.
    static func make(from source: URL, to destination: URL) throws {
        guard let image = CGImageSourceCreateWithURL(source as CFURL, nil),
              let pixels = CGImageSourceCreateThumbnailAtIndex(image, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 4096] as CFDictionary),
              let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        CGImageDestinationAddImage(output, pixels, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
        guard CGImageDestinationFinalize(output) else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: destination.path)
    }
}
#endif
