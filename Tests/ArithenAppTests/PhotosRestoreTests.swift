import XCTest
import UIKit
import Photos
import ImageIO
import UniformTypeIdentifiers
import AVFoundation
import CoreVideo
import CalcCore
@testable import Arithen

/// These assets exist only in the disposable CI simulator's Photos library.
/// The source vault and source file are removed before recovery/export so the
/// archive, rather than a surviving original, must supply bytes and chronology.
@MainActor
final class PhotosRestoreTests: XCTestCase {
    private var root: URL!
    private let secret = "disposable media recovery password"
    private let latitude = 37.3317
    private let longitude = -122.0301
    private let captured = ISO8601DateFormatter().date(from: "2001-02-03T04:05:06Z")!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }

    func testPhotoCaptureDateAndLocationSurviveBackupRestoreAndSaveToPhotos() async throws {
        let file = try photo()
        let details = await MediaBridge.metadata(file, type: UTType.jpeg.identifier)
        try assertDetails(details)
        try await roundTrip(file, type: UTType.jpeg.identifier, details: details, importIntoNewVault: false)
    }

    func testVideoCaptureDateAndLocationSurviveBackupReencryptionAndSaveToPhotos() async throws {
        let file = try await video()
        let details = await MediaBridge.metadata(file, type: UTType.quickTimeMovie.identifier)
        try assertDetails(details)
        try await roundTrip(file, type: UTType.quickTimeMovie.identifier, details: details, importIntoNewVault: true)
    }

    func testLegacyPhotoUsesEmbeddedCaptureDateAfterRestoreAndSaveToPhotos() async throws {
        // Older archives may retain original EXIF bytes without manifest fields.
        try await roundTrip(photo(), type: UTType.jpeg.identifier, details: .init(), importIntoNewVault: false)
    }

    private func assertDetails(_ details: MediaDetails) throws {
        XCTAssertEqual(try XCTUnwrap(details.captured).timeIntervalSince1970, captured.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(details.latitude), latitude, accuracy: 0.00001)
        XCTAssertEqual(try XCTUnwrap(details.longitude), longitude, accuracy: 0.00001)
    }

    private func roundTrip(_ original: URL, type: String, details: MediaDetails, importIntoNewVault: Bool) async throws {
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            throw fixtureError("The preceding UI journey must grant Photos full access before native restoration tests; status=\(PHPhotoLibrary.authorizationStatus(for: .readWrite).rawValue)")
        }
        let originalBytes = try Data(contentsOf: original)
        let name = "arithen-restore-" + UUID().uuidString + "." + original.pathExtension
        let sourceRoot = root.appendingPathComponent("source")
        let source = VaultRepository(root: sourceRoot)
        try source.create(password: secret)
        let first = try source.add(file: original, name: name, contentType: type, details: details)
        let archive = root.appendingPathComponent("media.c84backup")
        try source.exportBackup(to: archive)
        source.lock()
        try FileManager.default.removeItem(at: sourceRoot)
        try FileManager.default.removeItem(at: original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceRoot.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: original.path))

        let restored = VaultRepository(root: root.appendingPathComponent("restored"))
        try restored.restore(from: archive, password: secret)
        let exportRepository: VaultRepository
        if importIntoNewVault {
            let destination = VaultRepository(root: root.appendingPathComponent("new-library"))
            try destination.create(password: "different disposable destination password")
            let result = try destination.importBackup(restored, selected: [first.id])
            XCTAssertEqual(result.added, 1)
            XCTAssertNotEqual(try XCTUnwrap(result.items.first).id, first.id)
            let credential = try destination.credential()
            destination.lock(); try destination.unlock(credential: credential)
            exportRepository = destination
        } else { exportRepository = restored }
        let item = try XCTUnwrap(exportRepository.items.first { $0.visible })
        if let originalDate = details.captured {
            XCTAssertEqual(try XCTUnwrap(item.captured).timeIntervalSince1970, originalDate.timeIntervalSince1970, accuracy: 0.01)
            XCTAssertEqual(item.chronologicalDate, originalDate)
        } else { XCTAssertNil(item.captured) }
        let output = root.appendingPathComponent("export." + original.pathExtension)
        try exportRepository.materialize(id: item.id, to: output)
        XCTAssertEqual(try Data(contentsOf: output), originalBytes)

        let before = assetIdentifiers()
        try await MediaBridge.saveToPhotos(item: item, main: output, companion: nil)
        let newAssets = PHAsset.fetchAssets(with: nil)
        var matches: [PHAsset] = []
        newAssets.enumerateObjects { asset, _, _ in
            if !before.contains(asset.localIdentifier),
               PHAssetResource.assetResources(for: asset).contains(where: { $0.originalFilename == name }) {
                matches.append(asset)
            }
        }
        XCTAssertEqual(matches.count, 1)
        let saved = try XCTUnwrap(matches.first)
        XCTAssertEqual(try XCTUnwrap(saved.creationDate).timeIntervalSince1970, captured.timeIntervalSince1970, accuracy: 0.01)
        if details.latitude != nil, details.longitude != nil {
            let location = try XCTUnwrap(saved.location)
            XCTAssertEqual(location.coordinate.latitude, latitude, accuracy: 0.00001)
            XCTAssertEqual(location.coordinate.longitude, longitude, accuracy: 0.00001)
        }
        // Legacy nil location has no explicit GPS assignment; Photos may itself
        // interpret original-file metadata. This test does not claim GPS removal.
        XCTAssertEqual(saved.mediaType, UTType(type)?.conforms(to: .movie) == true ? .video : .image)
        if saved.mediaType == .video { XCTAssertGreaterThan(saved.duration, 0) }
        XCTAssertEqual(try Data(contentsOf: output), originalBytes, "Saving to Photos must not rewrite the exported original")
    }

    private func assetIdentifiers() -> Set<String> {
        var ids = Set<String>()
        PHAsset.fetchAssets(with: nil).enumerateObjects { asset, _, _ in ids.insert(asset.localIdentifier) }
        return ids
    }

    private func photo() throws -> URL {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        let url = root.appendingPathComponent(UUID().uuidString + ".jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2001:02:03 04:05:06", "OffsetTimeOriginal" as CFString: "+00:00"],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: latitude, kCGImagePropertyGPSLatitudeRef: "N",
                                          kCGImagePropertyGPSLongitude: abs(longitude), kCGImagePropertyGPSLongitudeRef: "W"]
        ]
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func video() async throws -> URL {
        let url = root.appendingPathComponent(UUID().uuidString + ".mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let date = AVMutableMetadataItem()
        date.identifier = .quickTimeMetadataCreationDate
        date.value = "2001-02-03T04:05:06Z" as NSString
        date.dataType = "com.apple.metadata.datatype.UTF-8"
        let location = AVMutableMetadataItem()
        location.identifier = .quickTimeMetadataLocationISO6709
        location.value = "+37.3317-122.0301/" as NSString
        location.dataType = "com.apple.metadata.datatype.UTF-8"
        writer.metadata = [date, location]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64
        ])
        guard writer.canAdd(input) else { throw fixtureError("Cannot add synthetic video track") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? fixtureError("Cannot start synthetic video") }
        writer.startSession(atSourceTime: .zero)
        var buffer: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA, nil, &buffer) == kCVReturnSuccess,
              let buffer else { throw fixtureError("Cannot allocate video frame") }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, 128, CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        for frame in 0..<3 {
            for _ in 0..<500 {
                if input.isReadyForMoreMediaData || writer.status == .failed { break }
                try await Task.sleep(nanoseconds: 10_000_000)
            }
            guard input.isReadyForMoreMediaData,
                  adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 2)) else {
                throw writer.error ?? fixtureError("Cannot append synthetic video frame")
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? fixtureError("Cannot finish synthetic video") }
        return url
    }

    private func fixtureError(_ description: String) -> NSError {
        NSError(domain: "Arithen.PhotosRestoreTests", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
