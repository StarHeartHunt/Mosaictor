//
//  MaskBuilder.swift
//  Mosaictor
//
//  Builds a grayscale/alpha mask CIImage from an operation's geometry.
//  White (opaque) where the effect should show, clear elsewhere. This single
//  primitive serves both rectangle and freehand-brush tools.
//

import CoreImage
import CoreGraphics

enum MaskBuilder {

    /// Converts the brush slider (1...100) to a stroke width in pixels,
    /// proportional to the image so it looks the same at any resolution.
    static func strokeWidthPixels(slider: Double, refDim: CGFloat) -> CGFloat {
        max(2, CGFloat(slider) / 100.0 * refDim * 0.30)
    }

    /// Renders the mask for one geometry at the given pixel size.
    /// Returns `nil` for `.whole` (callers treat that as "no mask / full image").
    static func mask(for geometry: Geometry,
                     size: CGSize,
                     refDim: CGFloat,
                     strokeSlider: Double,
                     feather: Bool) -> CIImage? {
        let w = Int(size.width.rounded())
        let h = Int(size.height.rounded())
        guard w > 0, h > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(data: nil,
                                  width: w,
                                  height: h,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return nil
        }

        // Black background = effect hidden.
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Flip to a top-left origin so normalized coords map directly.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)

        ctx.setFillColor(gray: 1, alpha: 1)   // white = effect visible
        ctx.setStrokeColor(gray: 1, alpha: 1)

        switch geometry {
        case .rect(let r):
            let pr = CGRect(x: r.minX * size.width,
                            y: r.minY * size.height,
                            width: r.width * size.width,
                            height: r.height * size.height)
            ctx.fill(pr.standardized)

        case .path(let pts):
            guard !pts.isEmpty else { return nil }
            let width = strokeWidthPixels(slider: strokeSlider, refDim: refDim)
            ctx.setLineWidth(width)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            let path = CGMutablePath()
            let p0 = CGPoint(x: pts[0].x * size.width, y: pts[0].y * size.height)
            path.move(to: p0)
            if pts.count == 1 {
                // A single tap: draw a dot.
                path.addLine(to: CGPoint(x: p0.x + 0.01, y: p0.y))
            } else {
                for p in pts.dropFirst() {
                    path.addLine(to: CGPoint(x: p.x * size.width, y: p.y * size.height))
                }
            }
            ctx.addPath(path)
            ctx.strokePath()

        case .whole:
            return nil
        }

        guard let cg = ctx.makeImage() else { return nil }
        var mask = CIImage(cgImage: cg)

        if feather, case .path = geometry {
            // Subtle soft edge for brush strokes (the "modernize" win).
            let radius = max(1, refDim * 0.004)
            if let f = CIFilter(name: "CIGaussianBlur",
                                parameters: [kCIInputImageKey: mask.clampedToExtent(),
                                             kCIInputRadiusKey: radius]),
               let out = f.outputImage {
                mask = out.cropped(to: CIImage(cgImage: cg).extent)
            }
        }
        return mask
    }
}
