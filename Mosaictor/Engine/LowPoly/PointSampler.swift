//
//  PointSampler.swift
//  Mosaictor
//
//  Samples feature points for low-poly: the four corners + edge-weighted points
//  (clustered on detail) + some uniform fill. Deterministic per point count so
//  the preview and the full-res export triangulate identically.
//

import CoreGraphics

enum PointSampler {

    /// Returns normalized (0...1, top-left) points for triangulation.
    nonisolated static func sample(from image: CGImage, count: Int) -> [CGPoint] {
        let target = max(3, count)
        var rng = SeededRNG(seed: UInt64(bitPattern: Int64(target)) &* 0x2545F4914F6CDD1D)

        var points: [CGPoint] = [
            CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 0),
            CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 1),
        ]

        let gw = 160, gh = 160
        let cdf = edgeCDF(image: image, gw: gw, gh: gh)
        let total = cdf.last ?? 0

        let edgeQuota = total > 0 ? Int(Double(target) * 0.7) : 0
        let uniformQuota = target - edgeQuota

        for _ in 0..<edgeQuota {
            let r = Double.random(in: 0..<total, using: &rng)
            let idx = lowerBound(cdf, value: r)
            let gx = idx % gw, gy = idx / gw
            let jx = (Double(gx) + Double.random(in: 0..<1, using: &rng)) / Double(gw)
            let jy = (Double(gy) + Double.random(in: 0..<1, using: &rng)) / Double(gh)
            points.append(CGPoint(x: jx, y: jy))
        }
        for _ in 0..<uniformQuota {
            points.append(CGPoint(x: Double.random(in: 0...1, using: &rng),
                                  y: Double.random(in: 0...1, using: &rng)))
        }
        return points
    }

    /// Cumulative distribution of edge magnitude over a gw×gh grid.
    nonisolated private static func edgeCDF(image: CGImage, gw: Int, gh: Int) -> [Double] {
        guard let bmp = SampledBitmap(image: image, maxDimension: max(gw, gh)) else {
            return []
        }
        var cdf = [Double](repeating: 0, count: gw * gh)
        var running = 0.0
        for y in 0..<gh {
            let sy = Int(CGFloat(y) / CGFloat(gh) * CGFloat(bmp.height))
            for x in 0..<gw {
                let sx = Int(CGFloat(x) / CGFloat(gw) * CGFloat(bmp.width))
                let gxv = abs(bmp.luma(sx + 1, sy) - bmp.luma(sx - 1, sy))
                let gyv = abs(bmp.luma(sx, sy + 1) - bmp.luma(sx, sy - 1))
                // Bias keeps flat areas from being completely starved of points.
                let weight = Double(gxv + gyv) + 0.02
                running += weight
                cdf[y * gw + x] = running
            }
        }
        return cdf
    }

    nonisolated private static func lowerBound(_ cdf: [Double], value: Double) -> Int {
        var lo = 0, hi = cdf.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if cdf[mid] < value { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}
