import XCTest
import SwiftUI
import Photos
import PhotosUI
#if canImport(_PhotosUI_SwiftUI)
import _PhotosUI_SwiftUI
#endif
import UIKit
import CryptoKit
import CalcCore
@testable import Arithen

/// Opt-in fixtures are generated and bundled only in the dedicated QA workflow.
@MainActor
final class CodexMediaBenchmarks: XCTestCase {
    func testLastWeeksPhotosAndThirtyMinuteVideosAcrossRepeatedBatches() async throws {
        let bundle = Bundle(for: Self.self)
        guard let movie30 = bundle.url(forResource: "qa-30", withExtension: "mp4"),
              let movie60 = bundle.url(forResource: "qa-60", withExtension: "mp4") else {
            throw XCTSkip("Generate the 4K fixtures with the media QA workflow.")
        }
        XCTAssertEqual(PHPhotoLibrary.authorizationStatus(for: .readWrite), .authorized)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let png = dir.appendingPathComponent("screen.png")
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: 1179, height: 2556)
        let screenshot = UIGraphicsImageRenderer(size: size, format: format).pngData { renderer in
            UIColor.systemTeal.setFill()
            renderer.fill(CGRect(origin: .zero, size: size))
            ("Arithen media fixture" as NSString).draw(at: CGPoint(x: 100, y: 180), withAttributes: [.font: UIFont.systemFont(ofSize: 72)])
        }
        try screenshot.write(to: png)
        let tag = UUID().uuidString
        let files = Array(repeating: png, count: 248) + [movie30, movie60]
        let date = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970) - 7 * 86400)
        try await PHPhotoLibrary.shared().performChanges {
            for (index, url) in files.enumerated() {
                let add = PHAssetCreationRequest.forAsset()
                add.creationDate = date.addingTimeInterval(Double(index))
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = "\(tag)-\(index).\(url.pathExtension)"
                add.addResource(with: index < 248 ? .photo : .video, fileURL: url, options: options)
            }
        }
        func assets() -> [PHAsset] {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", date as NSDate, date.addingTimeInterval(250) as NSDate)
            var matches: [PHAsset] = []
            PHAsset.fetchAssets(with: options).enumerateObjects { asset, _, _ in
                if PHAssetResource.assetResources(for: asset).contains(where: { $0.originalFilename.hasPrefix(tag) }) { matches.append(asset) }
            }
            return matches.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        }
        let seeded = assets()
        XCTAssertEqual(seeded.count, 250)
        guard seeded.count == 250 else { return }
        let engine = VaultEngine(root: dir.appendingPathComponent("vault"))
        let password = "synthetic temporary test phrase"
        _ = try await engine.create(password: password)
        let model = VaultModel(engine: engine)
        model.unlocked = true
        for batch in [150, 150, 150, 250] {
            let selection = seeded.prefix(batch).map { PhotosPickerItem(itemIdentifier: $0.localIdentifier) }
            let prior = model.items.filter(\.visible).count
            let start = ProcessInfo.processInfo.systemUptime
            model.importPhotos(selection)
            let queued = ProcessInfo.processInfo.systemUptime - start
            while model.photoImportReview == nil && ProcessInfo.processInfo.systemUptime - start < 480 {
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            let review = try XCTUnwrap(model.photoImportReview)
            XCTAssertEqual(review.imported, batch, review.importError ?? "")
            XCTAssertEqual(model.items.filter(\.visible).count, prior + batch)
            print("MEDIA_QA batch=\(batch) committed=\(review.imported) submittedSeconds=\(queued) committedSeconds=\(ProcessInfo.processInfo.systemUptime-start) fixturePNGBytes=\(screenshot.count)")
        }
        await engine.lock()
        let reopened = try await engine.unlock(password: password).filter(\.visible)
        XCTAssertEqual(reopened.count, 700)
        for index in [0, 248, 249] {
            let input = files[index]
            let name = "\(tag)-\(index).\(input.pathExtension)"
            let item = try XCTUnwrap(reopened.first { $0.name == name })
            let captured = date.addingTimeInterval(Double(index))
            XCTAssertEqual(try XCTUnwrap(item.captured).timeIntervalSince1970, captured.timeIntervalSince1970, accuracy: 0.1)
            let original = dir.appendingPathComponent("export-\(index).\(input.pathExtension)")
            try await engine.materialize(id: item.id, to: original)
            let prior = Set(assets().map(\.localIdentifier))
            try await MediaBridge.saveToPhotos(item: item, main: original, companion: nil)
            let saved = try XCTUnwrap(assets().first { !prior.contains($0.localIdentifier) })
            XCTAssertEqual(try XCTUnwrap(saved.creationDate).timeIntervalSince1970, captured.timeIntervalSince1970, accuracy: 0.1)
            if index >= 248 { XCTAssertEqual(saved.duration, 1800, accuracy: 0.2) }
            let returned = dir.appendingPathComponent("photos-\(index).\(input.pathExtension)")
            let resource = try XCTUnwrap(PHAssetResource.assetResources(for: saved).first { $0.originalFilename == name })
            try await PhotoResource.write(resource, to: returned)
            let expected = try Data(contentsOf: input, options: .mappedIfSafe)
            XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: returned, options: .mappedIfSafe)), SHA256.hash(data: expected))
            print("MEDIA_QA export=\(index) bytes=\(expected.count) date=\(captured.timeIntervalSince1970) duration=\(saved.duration) verifiedOriginal=true")
        }
    }
}
