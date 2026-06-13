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
            HStack(spacing: 10) {
                ForEach(ToolType.allCases) { tool in
                    let selected = model.activeTool == tool
                    Button {
                        model.selectTool(tool)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tool.systemImage)
                                .font(.system(size: 19))
                            Text(tool.title)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(width: 70, height: 56)
                        .background(selected ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06))
                        .foregroundStyle(selected ? Color.accentColor : Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.hasImage)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
