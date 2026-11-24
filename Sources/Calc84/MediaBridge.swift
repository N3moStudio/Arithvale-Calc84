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
    static func selectedAssets(_ identifiers: [String]) -> [String: PHAsset] {
        guard !identifiers.isEmpty else { return [:] }
        var assets: [String: PHAsset] = [:]
        PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil).enumerateObjects { asset, _, _ in
            assets[asset.localIdentifier] = asset
        }
        return assets
    }

    static func prepare(_ selection: PhotosPickerItem, asset: PHAsset?) async throws -> PreparedMedia {
        if let asset {
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
                return imageDetails(properties)
            }.value
        }
        if UTType(type)?.conforms(to: .movie) == true {
            let asset = AVURLAsset(url: url)
            let duration = try? await asset.load(.duration).seconds
            let creation = try? await asset.load(.creationDate)
            var date = try? await creation?.load(.dateValue)
            var coordinates: CLLocationCoordinate2D?
            let metadata = (try? await asset.load(.metadata)) ?? []
            for item in metadata {
                if item.identifier == .quickTimeMetadataLocationISO6709 || item.identifier == .quickTimeUserDataLocationISO6709,
                   let value = try? await item.load(.stringValue), let location = locationISO6709(value) {
                    coordinates = location
                }
                if date == nil, item.identifier == .quickTimeMetadataCreationDate,
                   let value = try? await item.load(.stringValue) {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    date = formatter.date(from: value)
                    if date == nil { formatter.formatOptions = [.withInternetDateTime]; date = formatter.date(from: value) }
                }
            }
            return MediaDetails(captured: date ?? nil, duration: duration?.isFinite == true ? duration : nil,
                latitude: coordinates?.latitude, longitude: coordinates?.longitude)
        }
        return MediaDetails()
    }
    static func imageDetails(_ properties: [CFString: Any]) -> MediaDetails {
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let candidates: [(String?, String?, String?)] = [
            (exif[kCGImagePropertyExifDateTimeOriginal] as? String, exif["OffsetTimeOriginal" as CFString] as? String, exif[kCGImagePropertyExifSubsecTimeOriginal] as? String),
            (exif[kCGImagePropertyExifDateTimeDigitized] as? String, exif["OffsetTimeDigitized" as CFString] as? String, exif[kCGImagePropertyExifSubsecTimeDigitized] as? String),
            (tiff[kCGImagePropertyTIFFDateTime] as? String, exif["OffsetTime" as CFString] as? String, exif[kCGImagePropertyExifSubsecTime] as? String)
        ]
        var captured: Date?
        for (raw, offset, fraction) in candidates {
            guard let raw else { continue }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.isLenient = false
            // Without an embedded offset, preserve the historical local-time
            // interpretation. There is no reliable camera timezone to invent.
            formatter.dateFormat = offset == nil ? "yyyy:MM:dd HH:mm:ss" : "yyyy:MM:dd HH:mm:ssXXXXX"
            guard let base = formatter.date(from: raw + (offset ?? "")) else { continue }
            let digits = fraction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let subsecond = !digits.isEmpty && digits.utf8.allSatisfy { (48...57).contains($0) }
                ? Double("0." + String(digits.prefix(9))) ?? 0 : 0
            captured = base.addingTimeInterval(subsecond); break
        }
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
        func coordinate(_ value: CFString, _ reference: CFString, positive: String, negative: String, limit: Double) -> Double? {
            guard let number = (gps[value] as? NSNumber)?.doubleValue, number.isFinite, (0...limit).contains(number),
                  let ref = (gps[reference] as? String)?.uppercased(), ref == positive || ref == negative else { return nil }
            return ref == negative ? -number : number
        }
        let latitude = coordinate(kCGImagePropertyGPSLatitude, kCGImagePropertyGPSLatitudeRef, positive: "N", negative: "S", limit: 90)
        let longitude = coordinate(kCGImagePropertyGPSLongitude, kCGImagePropertyGPSLongitudeRef, positive: "E", negative: "W", limit: 180)
        return MediaDetails(captured: captured, latitude: longitude == nil ? nil : latitude, longitude: latitude == nil ? nil : longitude)
    }
    static func locationISO6709(_ raw: String) -> CLLocationCoordinate2D? {
        // QuickTime stores signed decimal degrees, optionally followed by altitude.
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: #"^([+-]\d{2}(?:\.\d+)?)([+-]\d{3}(?:\.\d+)?)(?:[+-]\d+(?:\.\d+)?)?/?$"#),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let latRange = Range(match.range(at: 1), in: value), let lonRange = Range(match.range(at: 2), in: value),
              let latitude = Double(value[latRange]), let longitude = Double(value[lonRange]),
              latitude.isFinite, longitude.isFinite else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }
    static func detailsForPhotoSave(item: VaultItem, original: URL) async -> MediaDetails {
        // Photos adjustments saved in the vault win over embedded originals.
        // Old backups may lack these fields; read original bytes before falling
        // back, without rewriting the file or changing the encrypted schema.
        let storedLocation: CLLocationCoordinate2D? = {
            guard let latitude = item.latitude, let longitude = item.longitude else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
        }()
        let embedded = item.captured == nil ? await metadata(original, type: item.contentType) : MediaDetails()
        // Older manifests cannot distinguish absent GPS from a location the user
        // deliberately cleared in Photos. Do not explicitly fill absent saved GPS.
        return MediaDetails(captured: item.captured ?? embedded.captured, duration: item.duration ?? embedded.duration,
            latitude: storedLocation?.latitude, longitude: storedLocation?.longitude)
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
        let details = await detailsForPhotoSave(item: item, original: main)
        try Task.checkCancellation()
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = item.name; options.uniformTypeIdentifier = item.contentType
            request.addResource(with: isVideo ? .video : .photo, fileURL: main, options: options)
            if let companion { request.addResource(with: .pairedVideo, fileURL: companion, options: nil) }
            if let captured = details.captured { request.creationDate = captured }
            if let latitude = details.latitude, let longitude = details.longitude {
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
