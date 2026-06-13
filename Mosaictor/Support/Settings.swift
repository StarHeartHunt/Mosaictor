//
//  Settings.swift
//  Mosaictor
//
//  Lightweight UserDefaults persistence for the last-used tool and slider
//  values (the original's "Save settings"). Restored on launch.
//

import Foundation

enum Settings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let tool = "tool"
        static let mosaic = "mosaicSlider"
        static let blur = "blurSlider"
        static let dark = "darkSlider"
        static let stroke = "strokeSlider"
        static let points = "pointCount"
        static let sharpness = "sharpness"
        static let saved = "hasSavedSettings"
    }

    static var hasSaved: Bool { defaults.bool(forKey: Key.saved) }

    static func save(tool: ToolType, params: EffectParams, sharpness: Double) {
        defaults.set(tool.rawValue, forKey: Key.tool)
        defaults.set(params.mosaicSlider, forKey: Key.mosaic)
        defaults.set(params.blurSlider, forKey: Key.blur)
        defaults.set(params.darkSlider, forKey: Key.dark)
        defaults.set(params.strokeSlider, forKey: Key.stroke)
        defaults.set(params.pointCount, forKey: Key.points)
        defaults.set(sharpness, forKey: Key.sharpness)
        defaults.set(true, forKey: Key.saved)
    }

    static func loadTool() -> ToolType {
        ToolType(rawValue: defaults.string(forKey: Key.tool) ?? "") ?? .rectMosaic
    }

    static func loadParams() -> EffectParams {
        var p = EffectParams()
        p.mosaicSlider = defaults.double(forKey: Key.mosaic)
        p.blurSlider = defaults.double(forKey: Key.blur)
        p.darkSlider = defaults.double(forKey: Key.dark)
        p.strokeSlider = defaults.double(forKey: Key.stroke)
        p.pointCount = defaults.integer(forKey: Key.points)
        return p
    }

    static func loadSharpness() -> Double { defaults.double(forKey: Key.sharpness) }
}
