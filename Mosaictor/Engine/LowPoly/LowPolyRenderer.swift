//
//  LowPolyRenderer.swift
//  Mosaictor
//
//  Renders a low-poly (Delaunay-triangulated, flat-shaded) version of an image:
//  sample points -> triangulate -> fill each triangle with its centroid color.
//

import CoreGraphics

enum LowPolyRenderer {

    /// Produces a low-poly CGImage at `size` pixels. Pure CPU work — runs off
    /// the main actor for large point counts.
    nonisolated static func render(base: CGImage, size: CGSize, pointCount: Int) -> CGImage? {
        let w = Int(size.width.rounded()), h = Int(size.height.rounded())
        guard w > 0, h > 0 else { return nil }
        guard let colors = SampledBitmap(image: base, maxDimension: 400) else { return nil }

        let normalized = PointSampler.sample(from: base, count: pointCount)
        let scaled = normalized.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let tris = Delaunay.triangulate(points: scaled)
        guard !tris.isEmpty else { return base }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        // Work in a top-left origin to match normalized sampling.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.setShouldAntialias(true)

        for t in tris {
            let p0 = scaled[t.0], p1 = scaled[t.1], p2 = scaled[t.2]
            let cx = (p0.x + p1.x + p2.x) / 3 / size.width
            let cy = (p0.y + p1.y + p2.y) / 3 / size.height
            let c = colors.color(atNormalized: cx, cy)
            ctx.setFillColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
            // Slight stroke in the same color closes antialiased seams between faces.
            ctx.setStrokeColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
            ctx.setLineWidth(1)
            ctx.beginPath()
            ctx.move(to: p0)
            ctx.addLine(to: p1)
            ctx.addLine(to: p2)
            ctx.closePath()
            ctx.drawPath(using: .fillStroke)
        }
        return ctx.makeImage()
    }
}
