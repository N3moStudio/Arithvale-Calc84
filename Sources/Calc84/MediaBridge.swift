#if os(iOS)
import Foundation
import Photos
import PhotosUI
#if canImport(_PhotosUI_SwiftUI)
import _PhotosUI_SwiftUI
#endif
import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import AVFoundation
import CoreLocation
import CalcCore

struct PhotoOriginal: Sendable {
    let identifier: String
    let modified: Date?
}

struct PreparedMedia {
    let url: URL
    let name: String
    let type: String
    let details: MediaDetails
    let companion: URL?
    let thumbnail: Data?
    let original: PhotoOriginal?
    func clean() {
        try? FileManager.default.removeItem(at: url)
        if let companion { try? FileManager.default.removeItem(at: companion) }
    }
}

enum MediaBridge {
    static func prepare(_ selection: PhotosPickerItem) async throws -> PreparedMedia {
        if let identifier = selection.itemIdentifier,
           let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject {
            let resources = PHAssetResource.assetResources(for: asset)
            let wanted: PHAssetResourceType = asset.mediaType == .video ? .video : .photo
            // Keep edited/alternate-resource assets: importing the original alone
            // does not preserve Photos-only edits or every RAW/alternate resource.
            let completeOriginal = resources.filter { $0.type == wanted }.count == 1
                && resources.allSatisfy { $0.type == wanted || ($0.type == .pairedVideo && asset.mediaSubtypes.contains(.photoLive)) }
                && resources.filter { $0.type == .pairedVideo }.count == (asset.mediaSubtypes.contains(.photoLive) ? 1 : 0)
            let original = completeOriginal && asset.canPerform(.delete)
                ? PhotoOriginal(identifier: identifier, modified: asset.modificationDate) : nil
            guard let main = resources.first(where: { $0.type == wanted }) else { throw VaultError.missing }
            let url = try await extract(main)
            var companion: URL?
            do {
                if asset.mediaSubtypes.contains(.photoLive) {
                    guard let paired = resources.first(where: { $0.type == .pairedVideo }) else {
                        throw failure("The Live Photo’s video could not be read. Keep the original and try again.")
                    }
                    companion = try await extract(paired)
                }
                let details = MediaDetails(captured: asset.creationDate, duration: asset.mediaType == .video ? asset.duration : nil,
                    latitude: asset.location?.coordinate.latitude, longitude: asset.location?.coordinate.longitude)
                return PreparedMedia(url: url, name: main.originalFilename, type: main.uniformTypeIdentifier,
                    details: details, companion: companion, thumbnail: await thumbnail(url, type: main.uniformTypeIdentifier), original: original)
            } catch {
                try? FileManager.default.removeItem(at: url)
                if let companion { try? FileManager.default.removeItem(at: companion) }
                throw error
            }
        }
        if selection.supportedContentTypes.contains(where: { $0.conforms(to: .livePhoto) }) {
            throw failure("Allow access to this Live Photo in Settings → Photos, then import it again. Its original has not changed.")
        }
        guard let media = try await selection.loadTransferable(type: PickedMedia.self) else { throw VaultError.missing }
        if Task.isCancelled { try? FileManager.default.removeItem(at: media.url); throw CancellationError() }
        let type = UTType(filenameExtension: media.url.pathExtension)?.identifier
            ?? selection.supportedContentTypes.first?.identifier ?? UTType.data.identifier
        return PreparedMedia(url: media.url, name: media.name, type: type, details: await metadata(media.url, type: type),
            companion: nil, thumbnail: await thumbnail(media.url, type: type), original: nil)
    }
    /// Exact library identifiers only. Never match sources by name, date, or thumbnail.
    static func originalsForDeletion(_ originals: [PhotoOriginal]) throws -> [PHAsset] {
        let permission = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard permission == .authorized || permission == .limited else {
            throw failure("Photos access is unavailable. Keep your originals, or allow access in Settings and import them again.")
        }
        var assets: [PHAsset] = []
        var seen = Set<String>()
        for original in originals {
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [original.identifier], options: nil).firstObject,
                  asset.modificationDate == original.modified, asset.canPerform(.delete) else {
                throw failure("An original changed or is no longer accessible. Nothing was requested for deletion. Keep the originals and import them again if needed.")
            }
            if seen.insert(original.identifier).inserted { assets.append(asset) }
        }
        guard !assets.isEmpty else { throw failure("No imported originals are available to delete.") }
        return assets
    }
    private static func extract(_ resource: PHAssetResource) async throws -> URL {
        let suffix = UTType(resource.uniformTypeIdentifier)?.preferredFilenameExtension ?? "bin"
        let url = try TemporaryFiles.fresh(extension: suffix)
        do {
            try Task.checkCancellation()
            try await PhotoResource.write(resource, to: url)
            return url
        } catch { try? FileManager.default.removeItem(at: url); throw error }
    }
    static func metadata(_ url: URL, type: String) async -> MediaDetails {
        if UTType(type)?.conforms(to: .image) == true {
            return await Task.detached(priority: .utility) {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return MediaDetails() }
                let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
                let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
                let raw = exif?[kCGImagePropertyExifDateTimeOriginal] as? String ?? tiff?[kCGImagePropertyTIFFDateTime] as? String
                let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                if let offset = exif?["OffsetTimeOriginal" as CFString] as? String {
                    let f = DateFormatter(); f.locale = formatter.locale; f.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
                    return MediaDetails(captured: raw.flatMap { f.date(from: $0 + offset) })
                }
                return MediaDetails(captured: raw.flatMap { formatter.date(from: $0) })
            }.value
        }
        if UTType(type)?.conforms(to: .movie) == true {
            let asset = AVURLAsset(url: url)
            let duration = try? await asset.load(.duration).seconds
            let creation = try? await asset.load(.creationDate)
            let date = try? await creation?.load(.dateValue)
            return MediaDetails(captured: date ?? nil, duration: duration?.isFinite == true ? duration : nil)
        }
        return MediaDetails()
    }
    static func thumbnail(_ url: URL, type: String) async -> Data? {
        await Task.detached(priority: .utility) {
            if UTType(type)?.conforms(to: .image) == true,
               let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: 420,
                    kCGImageSourceCreateThumbnailWithTransform: true
               ] as CFDictionary) { return UIImage(cgImage: image).jpegData(compressionQuality: 0.78) }
            if UTType(type)?.conforms(to: .movie) == true {
                let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
                generator.appliesPreferredTrackTransform = true; generator.maximumSize = CGSize(width: 420, height: 420)
                if let image = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                    return UIImage(cgImage: image).jpegData(compressionQuality: 0.78)
                }
            }
            return nil
        }.value
    }
    static func saveToPhotos(item: VaultItem, main: URL, companion: URL?) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw failure("Allow Add Photos in Settings to save a copy. Your library is unchanged.")
        }
        let isVideo = UTType(item.contentType)?.conforms(to: .movie) == true
        guard isVideo || UTType(item.contentType)?.conforms(to: .image) == true else { throw failure("This file can be exported to Files.") }
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = item.name; options.uniformTypeIdentifier = item.contentType
            request.addResource(with: isVideo ? .video : .photo, fileURL: main, options: options)
            if let companion { request.addResource(with: .pairedVideo, fileURL: companion, options: nil) }
            request.creationDate = item.captured ?? item.added
            if let latitude = item.latitude, let longitude = item.longitude {
                request.location = CLLocation(latitude: latitude, longitude: longitude)
            }
        }
    }
    static func failure(_ text: String) -> NSError {
        NSError(domain: "Calc84.Media", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

enum TemporaryFiles {
    static var directory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Calc84Temporary", isDirectory: true)
    }
    static func fresh(extension suffix: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        return directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(String(suffix.prefix(12)).filter { $0.isLetter || $0.isNumber })
    }
    static func clean() {
        guard directory.lastPathComponent == "Calc84Temporary" else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}
struct PickedMedia: Transferable, Sendable {
    let url: URL
    let name: String
    static func receive(_ incoming: ReceivedTransferredFile) throws -> PickedMedia {
        let size = try incoming.file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= VaultLimits.fileBytes else { throw VaultError.limit }
        let url = try TemporaryFiles.fresh(extension: incoming.file.pathExtension)
        do {
            // Copy incrementally; a large video must not be loaded into a single Data value.
            let input = try FileHandle(forReadingFrom: incoming.file); defer { try? input.close() }
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.protectionKey: FileProtectionType.complete])
            let output = try FileHandle(forWritingTo: url); defer { try? output.close() }
            var written = 0
            while let chunk = try input.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                try Task.checkCancellation()
                written += chunk.count; guard written <= VaultLimits.fileBytes else { throw VaultError.limit }
                try output.write(contentsOf: chunk)
            }
            try output.synchronize()
            return PickedMedia(url: url, name: incoming.file.lastPathComponent)
        } catch { try? FileManager.default.removeItem(at: url); throw error }
    }
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { try receive($0) }
        FileRepresentation(importedContentType: .movie) { try receive($0) }
    }
}
#endif
