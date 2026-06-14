//
//  ParameterSlider.swift
//  Mosaictor
//
//  The slider stack for the active tool: its primary parameter, brush width
//  (for finger tools), and the global Sharpness control.
//

import SwiftUI

struct ParameterControls: View {
    @Bindable var model: EditorModel

    var body: some View {
        VStack(spacing: 6) {
            let spec = model.activeTool.sliderSpec
            LabeledSlider(title: spec.title, value: primaryBinding(spec.param), range: spec.range)

            if model.activeTool.usesStrokeWidth {
                LabeledSlider(title: "Finger width",
                              value: strokeBinding,
                              range: 1...100)
            }

            LabeledSlider(title: "Sharpness %",
                          value: $model.sharpness,
                          range: 10...100)
        }
        .disabled(!model.hasImage)
    }

    private func primaryBinding(_ param: SliderParam) -> Binding<Double> {
        switch param {
        case .mosaic:
            return Binding(get: { model.liveParams.mosaicSlider },
                           set: { model.liveParams.mosaicSlider = $0; model.liveParamsChanged() })
        case .blur:
            return Binding(get: { model.liveParams.blurSlider },
                           set: { model.liveParams.blurSlider = $0; model.liveParamsChanged() })
        case .dark:
            return Binding(get: { model.liveParams.darkSlider },
                           set: { model.liveParams.darkSlider = $0; model.liveParamsChanged() })
        case .points:
            return Binding(get: { Double(model.liveParams.pointCount) },
                           set: { model.liveParams.pointCount = Int($0); model.liveParamsChanged() })
        }
    }

    private var strokeBinding: Binding<Double> {
        Binding(get: { model.liveParams.strokeSlider },
                set: { model.liveParams.strokeSlider = $0; model.liveParamsChanged() })
    }
}

struct LabeledSlider: View {
    let title: LocalizedStringResource
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 104, alignment: .leading)
            Slider(value: $value, in: range)
            Text("\(Int(value))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}
