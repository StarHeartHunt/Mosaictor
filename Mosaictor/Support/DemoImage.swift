//
//  DemoImage.swift
//  Mosaictor
//
//  DEBUG-only helper: generates a synthetic image and seeds sample operations
//  so the rendering path can be exercised in the running app (e.g. UI tests /
//  screenshots) without going through the system photo picker.
//

#if DEBUG
import CoreGraphics

enum DemoImage {
    static func make(width w: Int = 1000, height h: Int = 750) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let colors = [CGColor(red: 0.10, green: 0.30, blue: 0.85, alpha: 1),
                      CGColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1)] as CFArray
        let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
        ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: w, y: h), options: [])
        let circ = [CGColor(red: 1, green: 0, blue: 0, alpha: 1),
                    CGColor(red: 0, green: 1, blue: 0.2, alpha: 1),
                    CGColor(red: 1, green: 1, blue: 0, alpha: 1)]
        for (i, c) in circ.enumerated() {
            ctx.setFillColor(c)
            ctx.fillEllipse(in: CGRect(x: 110 + i * 270, y: 190, width: 190, height: 190))
        }
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 130, y: 540, width: 740, height: 56))
        return ctx.makeImage()!
    }
}
#endif
