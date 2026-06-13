//
//  EditorModel.swift
//  Mosaictor
//
//  Observable editor state: source image, ordered operation stack, undo/redo,
//  live drawing draft, and the composited preview image. Geometry is normalized
//  so the same ops re-render at any resolution.
//

import SwiftUI
import CoreGraphics

@MainActor
@Observable
final class EditorModel {

    private let pipeline = ImagePipeline()

    private(set) var operations: [Operation] = []
    private var redoStack: [Operation] = []
    private(set) var draft: Operation?
    private var dragStart: CGPoint = .zero

    var activeTool: ToolType = .rectMosaic
    var liveParams = EffectParams()
    var sharpness: Double = 100 {
        didSet {
            guard oldValue != sharpness else { return }
            recomposite()
            persist()
            scheduleLowPoly(debounce: true)   // preview size changed → recompute low poly
        }
    }

    private var isRestoring = false

    init() {
        guard Settings.hasSaved else { return }
        isRestoring = true
        activeTool = Settings.loadTool()
        liveParams = Settings.loadParams()
        sharpness = min(100, max(10, Settings.loadSharpness()))
        isRestoring = false
    }

    private func persist() {
        guard !isRestoring else { return }
        Settings.save(tool: activeTool, params: liveParams, sharpness: sharpness)
    }

    /// The composited preview, ready to display.
    private(set) var displayImage: CGImage?
    /// Pixel size of the loaded source (for aspect ratio / coordinate mapping).
    private(set) var imageSize: CGSize = .zero
    /// True while a low-poly image is being computed off the main thread.
    private(set) var isProcessingLowPoly = false
    private var lowPolyTask: Task<Void, Never>?

    var hasImage: Bool { pipeline.hasImage }
    var canUndo: Bool { !operations.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// The in-progress rectangle selection (normalized), for the canvas overlay.
    var selectionRect: CGRect? {
        guard let d = draft, case .rect(let r) = d.geometry else { return nil }
        return r
    }

    private let previewMaxDimension: CGFloat = 1400

    // MARK: Loading

    func loadImage(_ cg: CGImage) {
        pipeline.loadSource(cg)
        imageSize = CGSize(width: cg.width, height: cg.height)
        operations.removeAll()
        redoStack.removeAll()
        draft = nil
        recomposite()
    }

    // MARK: Tool selection

    func selectTool(_ tool: ToolType) {
        activeTool = tool
        persist()
        // Pre-compute the low-poly layer so drawing a region shows it instantly.
        if tool == .lowPoly { scheduleLowPoly(debounce: false) }
    }

    /// Called when the parameter sliders change.
    func liveParamsChanged() {
        persist()
        if activeTool == .lowPoly {
            recomposite()                     // live feedback for any in-progress region
            scheduleLowPoly(debounce: true)   // debounced precompute of the new density
        } else if draft != nil {
            recomposite()
        }
    }

    /// Ensures the low-poly layers needed by the current/active point counts are
    /// computed off the main thread (debounced for sliders), then recomposites.
    private func scheduleLowPoly(debounce: Bool) {
        guard hasImage else { return }
        var needed = Set<Int>()
        if activeTool == .lowPoly { needed.insert(liveParams.pointCount) }
        for op in operations where op.tool == .lowPoly { needed.insert(op.params.pointCount) }
        if let d = draft, d.tool == .lowPoly { needed.insert(d.params.pointCount) }

        let size = pipeline.previewSize(sharpness: sharpness, maxDimension: previewMaxDimension)
        let pending = needed.filter { !pipeline.hasLowPoly(pointCount: $0, size: size) }
        guard !pending.isEmpty else { recomposite(); return }

        lowPolyTask?.cancel()
        isProcessingLowPoly = true
        lowPolyTask = Task { [weak self] in
            if debounce { try? await Task.sleep(for: .milliseconds(200)) }
            guard !Task.isCancelled, let self else { return }
            for pointCount in pending {
                await self.pipeline.prepareLowPoly(pointCount: pointCount, targetSize: size)
                if Task.isCancelled { return }
                self.recomposite()   // reveal each region as its layer becomes ready
            }
            self.isProcessingLowPoly = false
            self.recomposite()
        }
    }

    // MARK: Drawing (coordinates are normalized 0...1, top-left)

    func beginStroke(at p: CGPoint) {
        guard hasImage else { return }
        switch activeTool.inputMode {
        case .rectangle:
            dragStart = p
            draft = Operation(tool: activeTool, geometry: .rect(CGRect(origin: p, size: .zero)), params: liveParams)
        case .path:
            draft = Operation(tool: activeTool, geometry: .path([p]), params: liveParams)
        case .whole:
            return
        }
        recomposite()
    }

    func updateStroke(to p: CGPoint) {
        guard var d = draft else { return }
        switch d.geometry {
        case .rect:
            let s = dragStart
            d.geometry = .rect(CGRect(x: min(s.x, p.x), y: min(s.y, p.y),
                                      width: abs(p.x - s.x), height: abs(p.y - s.y)))
        case .path(var pts):
            pts.append(p)
            d.geometry = .path(pts)
        case .whole:
            break
        }
        draft = d
        recomposite()
    }

    func endStroke() {
        guard let d = draft, isMeaningful(d) else { draft = nil; recomposite(); return }
        operations.append(d)
        redoStack.removeAll()
        draft = nil
        recomposite()
        if d.tool == .lowPoly { scheduleLowPoly(debounce: false) }
    }

    // MARK: History

    func undo() {
        guard let last = operations.popLast() else { return }
        redoStack.append(last)
        recomposite()
        scheduleLowPoly(debounce: false)
    }

    func redo() {
        guard let op = redoStack.popLast() else { return }
        operations.append(op)
        recomposite()
        scheduleLowPoly(debounce: false)
    }

    // MARK: Export

    func exportJPEG() -> Data? {
        pipeline.jpegData(operations: operations, sharpness: sharpness)
    }

    // MARK: Compositing

    private func recomposite() {
        guard hasImage else { displayImage = nil; return }
        let ops = operations + (draft.map { [$0] } ?? [])
        let size = pipeline.previewSize(sharpness: sharpness, maxDimension: previewMaxDimension)
        displayImage = pipeline.render(operations: ops, targetSize: size)
    }

    private func isMeaningful(_ op: Operation) -> Bool {
        switch op.geometry {
        case .rect(let r): r.width > 0.004 && r.height > 0.004
        case .path(let pts): !pts.isEmpty
        case .whole: true
        }
    }
}

#if DEBUG
extension EditorModel {
    /// Loads a synthetic image and seeds one op per region tool, so the
    /// in-app rendering path can be screenshotted without the photo picker.
    func loadDemo() {
        loadImage(DemoImage.make())
        operations = [
            Operation(tool: .rectMosaic, geometry: .rect(CGRect(x: 0.06, y: 0.22, width: 0.22, height: 0.26)), params: EffectParams()),
            Operation(tool: .rectBlur, geometry: .rect(CGRect(x: 0.40, y: 0.22, width: 0.22, height: 0.26)), params: EffectParams()),
            Operation(tool: .fingerMosaic, geometry: .path((0..<24).map { CGPoint(x: 0.10 + Double($0) * 0.033, y: 0.74 + 0.05 * sin(Double($0) * 0.6)) }), params: EffectParams()),
        ]
        recomposite()
    }

    /// Drives the exact interactive contract the gesture handler uses
    /// (begin/update/end + commit + undo) to validate the drawing path.
    func runInteractiveDemo() {
        loadImage(DemoImage.make())

        // Rectangle mosaic, drawn as a drag.
        selectTool(.rectMosaic)
        beginStroke(at: CGPoint(x: 0.06, y: 0.22))
        for i in 1...6 { updateStroke(to: CGPoint(x: 0.06 + Double(i) * 0.035, y: 0.22 + Double(i) * 0.035)) }
        endStroke()

        // Brush blur, drawn as a freehand stroke.
        selectTool(.fingerBlur)
        beginStroke(at: CGPoint(x: 0.45, y: 0.30))
        for i in 1...20 { updateStroke(to: CGPoint(x: 0.45 + Double(i) * 0.02, y: 0.30 + 0.06 * sin(Double(i) * 0.5))) }
        endStroke()

        // Highlight, then an undo to prove history works (should disappear).
        selectTool(.highlight)
        beginStroke(at: CGPoint(x: 0.20, y: 0.66))
        for i in 1...6 { updateStroke(to: CGPoint(x: 0.20 + Double(i) * 0.06, y: 0.66 + Double(i) * 0.02)) }
        endStroke()
        undo()   // remove the highlight; mosaic + blur remain
    }

    /// Loads a demo image and leaves an active rectangle selection (no endStroke)
    /// so the live selection overlay can be screenshotted.
    func startDemoSelection() {
        loadImage(DemoImage.make())
        selectTool(.rectMosaic)
        beginStroke(at: CGPoint(x: 0.18, y: 0.24))
        for i in 1...8 { updateStroke(to: CGPoint(x: 0.18 + Double(i) * 0.055, y: 0.24 + Double(i) * 0.045)) }
    }

    /// Loads a demo image, then (after the view settles) draws a low-poly
    /// selection rectangle — mimicking real use where the view is established
    /// before the async low-poly compute completes.
    func loadLowPolyDemo() {
        loadImage(DemoImage.make())
        liveParams.pointCount = 1300
        Task {
            try? await Task.sleep(for: .seconds(1)) // let the view settle first
            selectTool(.lowPoly)
            beginStroke(at: CGPoint(x: 0.12, y: 0.18))
            for i in 1...8 { updateStroke(to: CGPoint(x: 0.12 + Double(i) * 0.075, y: 0.18 + Double(i) * 0.06)) }
            endStroke()
        }
    }
}
#endif
