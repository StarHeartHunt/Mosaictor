//
//  Operation.swift
//  Mosaictor
//
//  Non-destructive operation model. Each committed operation captures the
//  slider params at draw time, so two regions of the same tool can differ.
//  All geometry is stored in NORMALIZED image space (0...1, origin top-left)
//  so it is invariant to zoom, view size and working resolution.
//

import CoreGraphics
import Foundation

/// Geometry of one operation, in normalized image space (0...1).
enum Geometry: Equatable {
    case rect(CGRect)        // normalized rectangle
    case path([CGPoint])     // normalized polyline, stroked at `params.strokeSlider`
    case whole               // entire image (low poly)
}

/// Slider values captured for one operation. Stored as raw slider readings;
/// the pipeline converts them to pixels for whatever resolution it renders at,
/// so preview (working res) and export (full res) look identical.
struct EffectParams: Equatable, Hashable {
    var mosaicSlider: Double = 10    // 1...100   pixelate block size
    var blurSlider:   Double = 40    // 2...81    gaussian intensity
    var darkSlider:   Double = 172   // 72...255  highlight darkness (alpha)
    var strokeSlider: Double = 22    // 1...100   brush width
    var pointCount:   Int    = 1300  // 20...4000 low poly points
}

struct Operation: Identifiable, Equatable {
    let id = UUID()
    var tool: ToolType
    var geometry: Geometry
    var params: EffectParams
}
