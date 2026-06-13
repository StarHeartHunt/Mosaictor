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
}
