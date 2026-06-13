//
//  ImageExporter.swift
//  Mosaictor
//
//  Saves the exported JPEG to the photo library (iOS/visionOS) and writes a
//  temporary file for sharing.
//

import Foundation
#if canImport(Photos)
import Photos
#endif

enum ImageExporter {

    enum SaveResult { case success, denied, failed }

    #if os(iOS) || os(visionOS)
    /// Requests add-only Photos access and saves the JPEG. Requires the
    /// NSPhotoLibraryAddUsageDescription Info key (set in build settings).
    static func saveToPhotos(_ data: Data) async -> SaveResult {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return .denied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
            return .success
        } catch {
            return .failed
        }
    }
    #endif

    /// Writes JPEG data to a temporary file for ShareLink / share sheets.
    static func writeTemporaryFile(_ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Mosaictor-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
