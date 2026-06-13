//
//  Bitmap.swift
//  Mosaictor
//
//  Small CPU bitmap sampling helpers used by the low-poly pipeline.
//

import CoreGraphics

/// A downsampled RGBA8 copy of an image for fast CPU pixel sampling.
struct SampledBitmap {
    let width: Int
    let height: Int
    let pixels: [UInt8]   // RGBA, row-major, top-left origin

    nonisolated init?(image: CGImage, maxDimension: Int) {
        let aspect = CGFloat(image.width) / CGFloat(max(1, image.height))
        var w = maxDimension, h = maxDimension
        if aspect >= 1 { h = max(1, Int(CGFloat(maxDimension) / aspect)) }
        else { w = max(1, Int(CGFloat(maxDimension) * aspect)) }

        let cs = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = w * 4
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * h)
        let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress,
                                      width: w, height: h,
                                      bitsPerComponent: 8,
                                      bytesPerRow: bytesPerRow,
                                      space: cs,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        self.width = w
        self.height = h
        self.pixels = buffer
    }

    /// Samples RGBA (0...1) at a normalized coordinate (0...1, top-left origin).
    nonisolated func color(atNormalized x: CGFloat, _ y: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let px = min(width - 1, max(0, Int(x * CGFloat(width))))
        let py = min(height - 1, max(0, Int(y * CGFloat(height))))
        let i = (py * width + px) * 4
        return (CGFloat(pixels[i]) / 255,
                CGFloat(pixels[i + 1]) / 255,
                CGFloat(pixels[i + 2]) / 255,
                CGFloat(pixels[i + 3]) / 255)
    }

    /// Luminance (0...1) at integer grid coordinates.
    nonisolated func luma(_ x: Int, _ y: Int) -> CGFloat {
        let px = min(width - 1, max(0, x))
        let py = min(height - 1, max(0, y))
        let i = (py * width + px) * 4
        return (0.299 * CGFloat(pixels[i]) + 0.587 * CGFloat(pixels[i + 1]) + 0.114 * CGFloat(pixels[i + 2])) / 255
    }
}

/// Deterministic RNG (SplitMix64) so preview and export sample identical points.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    nonisolated init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    nonisolated mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
