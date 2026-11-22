import XCTest
import UIKit
import ImageIO
import AVFoundation
import CoreVideo
import CalcCore
@testable import Arithen

@MainActor
final class MediaMetadataTests: XCTestCase {
    private var root: URL!
    private let expected = ISO8601DateFormatter().date(from: "2021-08-12T15:24:35Z")!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    private func jpeg() throws -> URL {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        let url = root.appendingPathComponent(UUID().uuidString + ".jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil))
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2021:08:12 08:24:35",
                "OffsetTimeOriginal" as CFString: "-07:00", kCGImagePropertyExifSubsecTimeOriginal: "125"],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 33.75, kCGImagePropertyGPSLatitudeRef: "S",
                kCGImagePropertyGPSLongitude: 118.25, kCGImagePropertyGPSLongitudeRef: "W"]
        ]
        CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }
    private func item(details: MediaDetails) throws -> VaultItem {
        let repo = VaultRepository(root: root.appendingPathComponent(UUID().uuidString))
        try repo.create(password: "disposable photo metadata test password")
        return try repo.add(data: Data([1]), name: "original.jpg", contentType: "public.jpeg", details: details)
    }
    func testJPEGEmbeddedDateOffsetSubsecondAndGPS() async throws {
        let url = try jpeg(), before = try Data(contentsOf: url)
        let details = await MediaBridge.metadata(url, type: "public.jpeg")
        XCTAssertEqual(try XCTUnwrap(details.captured).timeIntervalSince1970, expected.timeIntervalSince1970 + 0.125, accuracy: 0.002)
        XCTAssertEqual(details.latitude, -33.75); XCTAssertEqual(details.longitude, -118.25)
        XCTAssertEqual(try Data(contentsOf: url), before, "Metadata extraction must not rewrite originals")
    }
    func testSavedPhotosAdjustmentsWinAndLegacyItemsRecoverEmbeddedValues() async throws {
        let url = try jpeg()
        let adjusted = try item(details: .init(captured: expected.addingTimeInterval(86400), latitude: 51.5, longitude: 0.125))
        let saved = await MediaBridge.detailsForPhotoSave(item: adjusted, original: url)
        XCTAssertEqual(saved.captured, adjusted.captured)
        XCTAssertEqual(saved.latitude, 51.5); XCTAssertEqual(saved.longitude, 0.125)
        let legacy = try item(details: .init())
        let recovered = await MediaBridge.detailsForPhotoSave(item: legacy, original: url)
        XCTAssertEqual(try XCTUnwrap(recovered.captured).timeIntervalSince1970, expected.timeIntervalSince1970 + 0.125, accuracy: 0.002)
        XCTAssertNil(recovered.latitude); XCTAssertNil(recovered.longitude)
        let locationRemoved = try item(details: .init(captured: expected))
        let cleared = await MediaBridge.detailsForPhotoSave(item: locationRemoved, original: url)
        XCTAssertEqual(cleared.captured, expected)
        XCTAssertNil(cleared.latitude); XCTAssertNil(cleared.longitude)
        let missing = await MediaBridge.detailsForPhotoSave(item: legacy, original: root.appendingPathComponent("missing.jpg"))
        XCTAssertNil(missing.captured, "An import timestamp must not be invented as the capture timestamp")
    }
    func testMalformedCoordinatesAreIgnoredAndTIFFDateFallbackWorks() throws {
        let properties: [CFString: Any] = [
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFDateTime: "2021:08:12 15:24:35"],
            kCGImagePropertyExifDictionary: ["OffsetTime" as CFString: "+00:00"],
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 91.0, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 118.25, kCGImagePropertyGPSLongitudeRef: "W"]
        ]
        let parsed = MediaBridge.imageDetails(properties)
        XCTAssertEqual(parsed.captured, expected)
        XCTAssertNil(parsed.latitude); XCTAssertNil(parsed.longitude)
        let valid = try XCTUnwrap(MediaBridge.locationISO6709("+33.7500-118.2500+001.5/"))
        XCTAssertEqual(valid.latitude, 33.75); XCTAssertEqual(valid.longitude, -118.25)
        for invalid in ["+91.0-118.0/", "+33.0-181.0/", "33.0,-118.0", "nan", "+33.0-118.0/junk"] {
            XCTAssertNil(MediaBridge.locationISO6709(invalid), invalid)
        }
    }
    func testMOVCreationDateAndLocationMetadata() async throws {
        let url = root.appendingPathComponent("fixture.mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let creation = AVMutableMetadataItem()
        creation.identifier = .quickTimeMetadataCreationDate
        creation.value = "2021-08-12T08:24:35-07:00" as NSString
        creation.dataType = kCMMetadataBaseDataType_UTF8 as String
        let location = AVMutableMetadataItem()
        location.identifier = .quickTimeMetadataLocationISO6709
        location.value = "+33.7500-118.2500+001.5/" as NSString
        location.dataType = kCMMetadataBaseDataType_UTF8 as String
        writer.metadata = [creation, location]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 32, AVVideoHeightKey: 32])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 32, kCVPixelBufferHeightKey as String: 32])
        XCTAssertTrue(writer.canAdd(input)); writer.add(input)
        XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 32, 32, kCVPixelFormatType_32BGRA, nil, &buffer), kCVReturnSuccess)
        let pixel = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixel, [])
        if let base = CVPixelBufferGetBaseAddress(pixel) { memset(base, 0, CVPixelBufferGetBytesPerRow(pixel) * 32) }
        CVPixelBufferUnlockBaseAddress(pixel, [])
        for _ in 0..<200 {
            if input.isReadyForMoreMediaData { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(input.isReadyForMoreMediaData)
        XCTAssertTrue(adaptor.append(pixel, withPresentationTime: .zero))
        writer.endSession(atSourceTime: CMTime(value: 1, timescale: 1))
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "")
        let details = await MediaBridge.metadata(url, type: "com.apple.quicktime-movie")
        XCTAssertEqual(try XCTUnwrap(details.captured).timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.01)
        XCTAssertEqual(details.latitude, 33.75); XCTAssertEqual(details.longitude, -118.25)
    }
}
