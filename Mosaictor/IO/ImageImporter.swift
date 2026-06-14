//
//  ImageImporter.swift
//  Mosaictor
//
//  Decodes imported image data into a CGImage, honoring EXIF orientation and
//  capping the working resolution so huge HEIC/JPEG files don't blow up memory.
//

import Foundation
import ImageIO
import CoreGraphics

enum ImageImporter {

    /// Decodes `data` to an upright CGImage no larger than `maxPixel` on its
    /// longest edge.
    static func decode(_ data: Data, maxPixel: Int = 4096) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,    // bake in orientation
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Decodes the image at `url`, e.g. one handed to us by the Share Sheet or an
    /// "Open in" action from another app. Acquires security-scoped access first so
    /// it works for files that live outside the app's sandbox container.
    static func decode(contentsOf url: URL, maxPixel: Int = 4096) -> CGImage? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decode(data, maxPixel: maxPixel)
    }
}
