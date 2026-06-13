//
//  ToolType.swift
//  Mosaictor
//
//  The six censoring tools.
//

import Foundation

/// How a tool collects input from the user.
enum InputMode {
    case rectangle   // drag a rectangle
    case path        // freehand brush stroke
    case whole       // applies to the entire image
}

/// Which slider parameter a tool primarily controls.
enum SliderParam {
    case mosaic   // pixelate block size   (1...100)
    case blur     // gaussian intensity    (2...81)
    case dark     // highlight darkness    (72...255)
    case points   // low-poly point count  (20...4000)
}

struct SliderSpec {
    let title: LocalizedStringResource
    let range: ClosedRange<Double>
    let param: SliderParam
}

enum ToolType: String, CaseIterable, Identifiable, Hashable, Codable {
    case rectMosaic
    case rectBlur
    case fingerMosaic
    case fingerBlur
    case highlight
    case lowPoly

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .rectMosaic:   "Mosaic"
        case .rectBlur:     "Blur"
        case .fingerMosaic: "Brush Mosaic"
        case .fingerBlur:   "Brush Blur"
        case .highlight:    "Highlight"
        case .lowPoly:      "Low Poly"
        }
    }

    var systemImage: String {
        switch self {
        case .rectMosaic:   "square.grid.3x3.fill"
        case .rectBlur:     "drop.fill"
        case .fingerMosaic: "scribble.variable"
        case .fingerBlur:   "paintbrush.pointed.fill"
        case .highlight:    "rectangle.dashed"
        case .lowPoly:      "triangle.fill"
        }
    }

    var inputMode: InputMode {
        switch self {
        case .rectMosaic, .rectBlur, .highlight, .lowPoly: .rectangle
        case .fingerMosaic, .fingerBlur:                   .path
        }
    }

    /// Brush tools also expose a stroke-width slider.
    var usesStrokeWidth: Bool { inputMode == .path }

    var sliderSpec: SliderSpec {
        switch self {
        case .rectMosaic, .fingerMosaic:
            SliderSpec(title: "Mosaic width", range: 1...100, param: .mosaic)
        case .rectBlur, .fingerBlur:
            SliderSpec(title: "Blur intensity", range: 2...81, param: .blur)
        case .highlight:
            SliderSpec(title: "Darkness", range: 72...255, param: .dark)
        case .lowPoly:
            SliderSpec(title: "Point count", range: 20...4000, param: .points)
        }
    }
}
