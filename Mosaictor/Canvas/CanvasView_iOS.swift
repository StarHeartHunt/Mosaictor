//
//  CanvasView_iOS.swift
//  Mosaictor
//
//  The interactive editing surface on iOS/visionOS. Single-finger pan draws
//  (rectangle or freehand); two-finger pan + pinch pan/zoom the canvas.
//  Touch points are converted to normalized image space (0...1, top-left).
//

#if canImport(UIKit)
import SwiftUI
import UIKit
import AVFoundation

struct CanvasView: UIViewRepresentable {
    let image: CGImage?
    let imageSize: CGSize
    let selection: CGRect?
    let drawingEnabled: Bool
    let onBegin: (CGPoint) -> Void
    let onMove: (CGPoint) -> Void
    let onEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> CanvasContentView {
        let view = CanvasContentView()
        view.backgroundColor = .black
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ view: CanvasContentView, context: Context) {
        context.coordinator.parent = self
        view.imagePixelSize = imageSize
        view.selectionRect = selection
        view.displayCGImage = image
        context.coordinator.drawingEnabled = drawingEnabled
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: CanvasView
        var drawingEnabled = true
        private weak var view: CanvasContentView?

        init(_ parent: CanvasView) { self.parent = parent }

        func attach(to view: CanvasContentView) {
            self.view = view

            let draw = UIPanGestureRecognizer(target: self, action: #selector(handleDraw(_:)))
            draw.maximumNumberOfTouches = 1
            draw.delegate = self
            view.addGestureRecognizer(draw)

            let twoFinger = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            twoFinger.minimumNumberOfTouches = 2
            twoFinger.maximumNumberOfTouches = 2
            twoFinger.delegate = self
            view.addGestureRecognizer(twoFinger)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            view.addGestureRecognizer(pinch)
        }

        @objc private func handleDraw(_ g: UIPanGestureRecognizer) {
            guard drawingEnabled, let view else { return }
            let p = g.location(in: view)
            guard let n = view.normalized(from: p) else {
                if g.state == .ended || g.state == .cancelled { parent.onEnd() }
                return
            }
            switch g.state {
            case .began:   parent.onBegin(n)
            case .changed: parent.onMove(n)
            case .ended, .cancelled, .failed: parent.onEnd()
            default: break
            }
        }

        @objc private func handlePan(_ g: UIPanGestureRecognizer) {
            guard let view else { return }
            let t = g.translation(in: view)
            view.pan.x += t.x
            view.pan.y += t.y
            g.setTranslation(.zero, in: view)
        }

        @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard let view else { return }
            view.zoom = min(8, max(0.5, view.zoom * g.scale))
            g.scale = 1
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            // Let two-finger pan and pinch run together; keep draw exclusive.
            !(g is UIPinchGestureRecognizer && other.isSingleTouchPan)
                && !(other is UIPinchGestureRecognizer && g.isSingleTouchPan)
        }
    }
}

private extension UIGestureRecognizer {
    var isSingleTouchPan: Bool {
        (self as? UIPanGestureRecognizer)?.maximumNumberOfTouches == 1
    }
}

final class CanvasContentView: UIView {
    var displayCGImage: CGImage? { didSet { setNeedsDisplay() } }
    var imagePixelSize: CGSize = .zero { didSet { setNeedsDisplay() } }
    var selectionRect: CGRect? { didSet { setNeedsDisplay() } }
    var zoom: CGFloat = 1 { didSet { setNeedsDisplay() } }
    var pan: CGPoint = .zero { didSet { setNeedsDisplay() } }

    override var contentMode: UIView.ContentMode { didSet {} }

    /// Rect (in view coords) the image is drawn into, after aspect-fit + zoom/pan.
    var displayRect: CGRect {
        guard imagePixelSize.width > 0, imagePixelSize.height > 0 else { return bounds }
        let fit = AVMakeRect(aspectRatio: imagePixelSize, insideRect: bounds)
        let w = fit.width * zoom, h = fit.height * zoom
        let cx = bounds.midX + pan.x, cy = bounds.midY + pan.y
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    func normalized(from point: CGPoint) -> CGPoint? {
        let r = displayRect
        guard r.width > 0, r.height > 0 else { return nil }
        let nx = (point.x - r.minX) / r.width
        let ny = (point.y - r.minY) / r.height
        guard nx >= -0.02, nx <= 1.02, ny >= -0.02, ny <= 1.02 else { return nil }
        return CGPoint(x: min(1, max(0, nx)), y: min(1, max(0, ny)))
    }

    override func draw(_ rect: CGRect) {
        UIColor.black.setFill()
        UIBezierPath(rect: bounds).fill()
        guard let cg = displayCGImage else { return }
        UIImage(cgImage: cg).draw(in: displayRect)
        drawSelection()
    }

    private func drawSelection() {
        guard let sel = selectionRect, sel.width > 0, sel.height > 0 else { return }
        let r = displayRect
        let vr = CGRect(x: r.minX + sel.minX * r.width,
                        y: r.minY + sel.minY * r.height,
                        width: sel.width * r.width,
                        height: sel.height * r.height)

        // Two-tone marching-ants border for visibility on any image.
        let outline = UIBezierPath(rect: vr)
        outline.lineWidth = 3
        UIColor.black.withAlphaComponent(0.55).setStroke()
        outline.stroke()
        let dashed = UIBezierPath(rect: vr)
        dashed.lineWidth = 1.5
        dashed.setLineDash([7, 4], count: 2, phase: 0)
        UIColor.white.setStroke()
        dashed.stroke()

        // Live pixel-size label.
        let wpx = Int((sel.width * imagePixelSize.width).rounded())
        let hpx = Int((sel.height * imagePixelSize.height).rounded())
        let text = "\(wpx) × \(hpx)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]
        let textSize = text.size(withAttributes: attrs)
        let pad: CGFloat = 6
        var labelOrigin = CGPoint(x: vr.minX, y: vr.minY - textSize.height - pad * 2 - 2)
        if labelOrigin.y < bounds.minY + 4 { labelOrigin.y = vr.minY + 4 }
        let labelRect = CGRect(x: labelOrigin.x, y: labelOrigin.y,
                               width: textSize.width + pad * 2, height: textSize.height + pad)
        let bg = UIBezierPath(roundedRect: labelRect, cornerRadius: 5)
        UIColor.black.withAlphaComponent(0.6).setFill()
        bg.fill()
        text.draw(at: CGPoint(x: labelRect.minX + pad, y: labelRect.minY + pad / 2), withAttributes: attrs)
    }
}
#endif
