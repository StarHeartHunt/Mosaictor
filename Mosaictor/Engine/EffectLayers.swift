//
//  EffectLayers.swift
//  Mosaictor
//
//  Produces the full-image effect CIImages (pixelate / blur / dark overlay)
//  that get clipped to operation masks during compositing. Slider values are
//  mapped to pixels proportionally to the render resolution.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics

enum EffectLayers {

    static func pixelateScale(slider: Double, refDim: CGFloat) -> CGFloat {
        max(2, CGFloat(slider) / 100.0 * refDim * 0.25)
    }

    static func blurRadius(slider: Double, refDim: CGFloat) -> CGFloat {
        max(1, CGFloat(slider) / 100.0 * refDim * 0.06)
    }

    /// Pixelated copy of `base`, cropped to its extent.
    static func pixelate(_ base: CIImage, slider: Double, refDim: CGFloat) -> CIImage {
        let f = CIFilter.pixellate()
        f.inputImage = base.clampedToExtent()
        f.scale = Float(pixelateScale(slider: slider, refDim: refDim))
        f.center = CGPoint(x: base.extent.minX, y: base.extent.minY)
        return (f.outputImage ?? base).cropped(to: base.extent)
    }

    /// Gaussian-blurred copy of `base`. Clamp-to-extent then crop kills the
    /// gray/transparent edge bleed CIGaussianBlur otherwise produces.
    static func blur(_ base: CIImage, slider: Double, refDim: CGFloat) -> CIImage {
        let f = CIFilter.gaussianBlur()
        f.inputImage = base.clampedToExtent()
        f.radius = Float(blurRadius(slider: slider, refDim: refDim))
        return (f.outputImage ?? base).cropped(to: base.extent)
    }

    /// `running` darkened everywhere by a semi-transparent black overlay.
    /// Used by Highlight: the rect mask later keeps `running` bright inside.
    static func darken(_ running: CIImage, slider: Double) -> CIImage {
        let alpha = CGFloat(slider) / 255.0
        let overlay = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: alpha))
            .cropped(to: running.extent)
        let comp = CIFilter.sourceOverCompositing()
        comp.inputImage = overlay
        comp.backgroundImage = running
        return (comp.outputImage ?? running).cropped(to: running.extent)
    }

    /// Blends `top` over `background`, keeping `top` where the mask is opaque.
    static func blend(_ top: CIImage, over background: CIImage, mask: CIImage) -> CIImage {
        let f = CIFilter.blendWithMask()
        f.inputImage = top
        f.backgroundImage = background
        f.maskImage = mask
        return (f.outputImage ?? background).cropped(to: background.extent)
    }
}
