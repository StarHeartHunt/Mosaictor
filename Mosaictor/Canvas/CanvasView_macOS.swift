//
//  CanvasView_macOS.swift
//  Mosaictor
//
//  The interactive editing surface on macOS. Mouse drag draws (rectangle or
//  freehand); pinch zooms; two-finger scroll pans. Mirrors the iOS canvas and
//  shares the same normalized-image-space (0...1, top-left) contract.
//

#if os(macOS)
import SwiftUI
import AppKit
import AVFoundation

struct CanvasView: NSViewRepresentable {
    let image: CGImage?
    let imageSize: CGSize
    let selection: CGRect?
    let drawingEnabled: Bool
    let onBegin: (CGPoint) -> Void
    let onMove: (CGPoint) -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> CanvasContentNSView {
        let view = CanvasContentNSView()
        return view
    }

    func updateNSView(_ view: CanvasContentNSView, context: Context) {
        view.imagePixelSize = imageSize
        view.selectionRect = selection
        view.displayCGImage = image
        view.drawingEnabled = drawingEnabled
        view.onBegin = onBegin
        view.onMove = onMove
        view.onEnd = onEnd
    }
}

final class CanvasContentNSView: NSView {
    var displayCGImage: CGImage? { didSet { needsDisplay = true } }
    var imagePixelSize: CGSize = .zero { didSet { needsDisplay = true } }
    var selectionRect: CGRect? { didSet { needsDisplay = true } }
    var zoom: CGFloat = 1 { didSet { needsDisplay = true } }
    var pan: CGPoint = .zero { didSet { needsDisplay = true } }
    var drawingEnabled = true
    var onBegin: ((CGPoint) -> Void)?
    var onMove: ((CGPoint) -> Void)?
    var onEnd: (() -> Void)?

    // Default (non-flipped, bottom-left) view: CGContext.draw renders upright,
    // and we flip Y when mapping mouse points to top-left normalized space.

    var displayRect: CGRect {
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else { return bounds }
        let fit = AVMakeRect(aspectRatio: imagePixelSize, insideRect: bounds)
        let w = fit.width * zoom, h = fit.height * zoom
        let cx = bounds.midX + pan.x, cy = bounds.midY + pan.y
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    /// Maps a (bottom-left origin) view point to normalized top-left image space.
    func normalized(from point: CGPoint) -> CGPoint? {
        let r = displayRect
        guard r.width > 0, r.height > 0 else { return nil }
        let nx = (point.x - r.minX) / r.width
        let ny = (r.maxY - point.y) / r.height        // flip Y to top-left
        guard nx >= -0.02, nx <= 1.02, ny >= -0.02, ny <= 1.02 else { return nil }
        return CGPoint(x: min(1, max(0, nx)), y: min(1, max(0, ny)))
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true                       // repaint backdrop on light/dark switch
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // Backdrop follows the system appearance (resolved against the view's
        // current drawing appearance inside draw(_:)).
        ctx.setFillColor(NSColor.windowBackgroundColor.cgColor)
        ctx.fill(bounds)
        guard let cg = displayCGImage else { return }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: displayRect)             // upright in bottom-left context
        drawSelection(ctx)
    }

    private func drawSelection(_ ctx: CGContext) {
        guard let sel = selectionRect, sel.width > 0, sel.height > 0 else { return }
        let r = displayRect
        // Map top-left normalized rect into the bottom-left view space.
        let vw = sel.width * r.width
        let vh = sel.height * r.height
        let vx = r.minX + sel.minX * r.width
        let vyTop = r.maxY - sel.minY * r.height
        let vr = CGRect(x: vx, y: vyTop - vh, width: vw, height: vh)

        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.55).cgColor)
        ctx.setLineWidth(3)
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.stroke(vr)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [7, 4])
        ctx.stroke(vr)
        ctx.setLineDash(phase: 0, lengths: [])

        // Live pixel-size label above the selection.
        let wpx = Int((sel.width * imagePixelSize.width).rounded())
        let hpx = Int((sel.height * imagePixelSize.height).rounded())
        let text = "\(wpx) × \(hpx)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attrs)
        let pad: CGFloat = 5
        let labelRect = CGRect(x: vr.minX, y: vr.maxY + 4,
                               width: textSize.width + pad * 2, height: textSize.height + pad)
        let bg = NSBezierPath(roundedRect: labelRect, xRadius: 5, yRadius: 5)
        NSColor.black.withAlphaComponent(0.6).setFill()
        bg.fill()
        text.draw(at: CGPoint(x: labelRect.minX + pad, y: labelRect.minY + pad / 2), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        guard drawingEnabled, let n = normalized(from: convert(event.locationInWindow, from: nil)) else { return }
        onBegin?(n)
    }

    override func mouseDragged(with event: NSEvent) {
        guard drawingEnabled, let n = normalized(from: convert(event.locationInWindow, from: nil)) else { return }
        onMove?(n)
    }

    override func mouseUp(with event: NSEvent) {
        guard drawingEnabled else { return }
        onEnd?()
    }

    override func magnify(with event: NSEvent) {
        zoom = min(8, max(0.5, zoom * (1 + event.magnification)))
    }

    override func scrollWheel(with event: NSEvent) {
        pan.x += event.scrollingDeltaX
        pan.y += event.scrollingDeltaY
    }
}
#endif
