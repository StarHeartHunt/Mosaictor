//
//  ToolbarView.swift
//  Mosaictor
//
//  Horizontal selector for the six censoring tools.
//

import SwiftUI

struct ToolbarView: View {
    @Bindable var model: EditorModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ToolType.allCases) { tool in
                    let selected = model.activeTool == tool
                    Button {
                        model.selectTool(tool)
                    } label: {
                        Image(systemName: tool.systemImage)
                            .font(.system(size: 20))
                            .frame(width: 52, height: 52)
                            .background(selected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06))
                            .foregroundStyle(selected ? Color.accentColor : Color.primary.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.hasImage)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
