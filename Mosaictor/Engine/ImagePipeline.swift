//
//  ImagePipeline.swift
//  Mosaictor
//
//  The compositing engine. One reused Core Image context renders the same
//  filter graph at working resolution (preview) and full resolution (export),
//  so what you see is what you save.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class ImagePipeline {

    private let context = CIContext(options: [.cacheIntermediates: false])
    private(set) var sourceCGImage: CGImage?

    /// Low-poly results are CPU-expensive; cache by (pointCount, renderSize).
    private var lowPolyCache: [String: CIImage] = [:]

    func loadSource(_ cg: CGImage) {
        sourceCGImage = cg
        lowPolyCache.removeAll()
    }

    var hasImage: Bool { sourceCGImage != nil }

    // MARK: Sizing

    func fullSize() -> CGSize {
        guard let s = sourceCGImage else { return .zero }
        return CGSize(width: s.width, height: s.height)
    }

    /// Export resolution honors the Sharpness slider (lower = smaller output).
    func exportSize(sharpness: Double) -> CGSize {
        let full = fullSize()
        let scale = max(0.1, sharpness / 100.0)
        return CGSize(width: (full.width * scale).rounded(),
                      height: (full.height * scale).rounded())
    }

    /// Preview resolution: export size capped for real-time compositing.
    func previewSize(sharpness: Double, maxDimension: CGFloat) -> CGSize {
        let full = exportSize(sharpness: sharpness)
        let m = max(full.width, full.height)
        guard m > maxDimension, m > 0 else { return full }
        let k = maxDimension / m
        return CGSize(width: (full.width * k).rounded(), height: (full.height * k).rounded())
    }

    // MARK: Rendering

    /// Renders the composite. Low Poly is a selection effect (like mosaic/blur):
    /// its full-image layer is clipped to the drawn region. For previews,
    /// `computeLowPolySync` is false so the expensive low-poly pass never blocks
    /// the main thread (a cached layer prepared via `prepareLowPoly` is used).
    func render(operations: [Operation], targetSize: CGSize, computeLowPolySync: Bool = false) -> CGImage? {
        guard sourceCGImage != nil, targetSize.width >= 1, targetSize.height >= 1 else { return nil }
        let base = baseImage(sourceCGImage!, targetSize: targetSize)
        let extent = base.extent
        let refDim = min(extent.width, extent.height)
        var result = base
        for op in operations {
            result = apply(op, base: base, running: result, size: extent.size,
                           refDim: refDim, computeLowPolySync: computeLowPolySync)
        }
        return context.createCGImage(result, from: extent)
    }

    /// Computes (off the main actor) and caches the low-poly image for a size.
    func prepareLowPoly(pointCount: Int, targetSize: CGSize) async {
        let w = targetSize.width.rounded(), h = targetSize.height.rounded()
        let size = CGSize(width: w, height: h)
        let key = lowPolyKey(pointCount, size)
        if lowPolyCache[key] != nil { return }
        guard let src = sourceCGImage else { return }
        let result = await Task.detached(priority: .userInitiated) {
            LowPolyRenderer.render(base: src, size: size, pointCount: pointCount)
        }.value
        guard let cg = result else { return }
        lowPolyCache[key] = CIImage(cgImage: cg)
    }

    func jpegData(operations: [Operation], sharpness: Double) -> Data? {
        guard let cg = render(operations: operations,
                              targetSize: exportSize(sharpness: sharpness),
                              computeLowPolySync: true) else {
            return nil
        }
        let ci = CIImage(cgImage: cg)
        let quality = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        return context.jpegRepresentation(of: ci,
                                           colorSpace: CGColorSpaceCreateDeviceRGB(),
                                           options: [quality: 1.0])
    }

    // MARK: Internals

    private func baseImage(_ src: CGImage, targetSize: CGSize) -> CIImage {
        let ci = CIImage(cgImage: src)
        let sx = targetSize.width / ci.extent.width
        let sy = targetSize.height / ci.extent.height
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
        return scaled.cropped(to: CGRect(x: 0, y: 0,
                                         width: targetSize.width.rounded(),
                                         height: targetSize.height.rounded()))
    }

    private func apply(_ op: Operation, base: CIImage, running: CIImage,
                       size: CGSize, refDim: CGFloat, computeLowPolySync: Bool) -> CIImage {
        switch op.tool {
        case .highlight:
            guard let mask = MaskBuilder.mask(for: op.geometry, size: size, refDim: refDim,
                                              strokeSlider: op.params.strokeSlider, feather: false) else {
                return running
            }
            let darkened = EffectLayers.darken(running, slider: op.params.darkSlider)
            // Keep the bright original inside the rect, darkened everywhere else.
            return EffectLayers.blend(running, over: darkened, mask: mask)

        case .lowPoly:
            guard let mask = MaskBuilder.mask(for: op.geometry, size: size, refDim: refDim,
                                              strokeSlider: op.params.strokeSlider, feather: false) else {
                return running
            }
            let effect: CIImage
            if let cached = cachedLowPoly(pointCount: op.params.pointCount, size: size) {
                effect = cached
            } else if computeLowPolySync, let computed = lowPolyImage(pointCount: op.params.pointCount, size: size) {
                effect = computed
            } else {
                return running   // layer not ready yet in preview; region stays unprocessed
            }
            return EffectLayers.blend(effect, over: running, mask: mask)

        case .rectMosaic, .fingerMosaic, .rectBlur, .fingerBlur:
            let feather = op.tool.inputMode == .path
            guard let mask = MaskBuilder.mask(for: op.geometry, size: size, refDim: refDim,
                                              strokeSlider: op.params.strokeSlider, feather: feather) else {
                return running
            }
            let effect: CIImage
            if op.tool == .rectMosaic || op.tool == .fingerMosaic {
                effect = EffectLayers.pixelate(base, slider: op.params.mosaicSlider, refDim: refDim)
            } else {
                effect = EffectLayers.blur(base, slider: op.params.blurSlider, refDim: refDim)
            }
            return EffectLayers.blend(effect, over: running, mask: mask)
        }
    }

    private func cachedLowPoly(pointCount: Int, size: CGSize) -> CIImage? {
        lowPolyCache[lowPolyKey(pointCount, size)]
    }

    func hasLowPoly(pointCount: Int, size: CGSize) -> Bool {
        let s = CGSize(width: size.width.rounded(), height: size.height.rounded())
        return lowPolyCache[lowPolyKey(pointCount, s)] != nil
    }

    private func lowPolyKey(_ pointCount: Int, _ size: CGSize) -> String {
        "\(pointCount)-\(Int(size.width))x\(Int(size.height))"
    }

    private func lowPolyImage(pointCount: Int, size: CGSize) -> CIImage? {
        guard let src = sourceCGImage else { return nil }
        let key = lowPolyKey(pointCount, size)
        if let cached = lowPolyCache[key] { return cached }
        guard let cg = LowPolyRenderer.render(base: src, size: size, pointCount: pointCount) else {
            return nil
        }
        let ci = CIImage(cgImage: cg)
        lowPolyCache[key] = ci
        return ci
    }
}
