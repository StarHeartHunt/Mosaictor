//
//  EditorScreen.swift
//  Mosaictor
//
//  The single-screen editor: top actions, interactive canvas, tool selector
//  and parameter sliders.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct EditorScreen: View {
    @State private var model = EditorModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var statusMessage: String?
    @State private var isExporting = false

    #if canImport(UIKit)
    @State private var shareItems: [Any]?
    #endif
    #if os(macOS)
    @State private var dropTargeted = false
    #endif

    var body: some View {
        VStack(spacing: 0) {
            topBar
            canvasArea
            if model.hasImage {
                controls
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onChange(of: pickerItem) { _, item in loadPicked(item) }
        #if DEBUG
        .task {
            switch ProcessInfo.processInfo.environment["MOSAICTOR_DEMO"] {
            case "1" where !model.hasImage: model.loadDemo()
            case "2" where !model.hasImage: model.runInteractiveDemo()
            case "3" where !model.hasImage: model.startDemoSelection()
            case "4" where !model.hasImage: model.loadLowPolyDemo()
            default: break
            }
        }
        #endif
        .alert(statusMessage ?? "", isPresented: statusBinding) {
            Button("OK", role: .cancel) {}
        }
        #if canImport(UIKit)
        .sheet(isPresented: shareBinding) {
            if let shareItems { ShareSheet(items: shareItems) }
        }
        #endif
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 18) {
            Text(verbatim: "Mosaictor")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
            }
            #if os(macOS)
            Button { paste() } label: { Image(systemName: "doc.on.clipboard") }
                .keyboardShortcut("v", modifiers: .command)
                .help("Paste image")
            #endif
            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!model.canUndo)
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .disabled(!model.canRedo)
            Button { save() } label: { Image(systemName: "square.and.arrow.down") }
                .disabled(!model.hasImage || isExporting)
            Button { share() } label: { Image(systemName: "square.and.arrow.up") }
                .disabled(!model.hasImage || isExporting)
        }
        .font(.system(size: 18))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
    }

    // MARK: Canvas

    private var canvasArea: some View {
        ZStack {
            if model.hasImage {
                CanvasView(image: model.displayImage,
                           imageSize: model.imageSize,
                           selection: model.selectionRect,
                           drawingEnabled: model.activeTool.inputMode != .whole,
                           onBegin: { model.beginStroke(at: $0) },
                           onMove: { model.updateStroke(to: $0) },
                           onEnd: { model.endStroke() })
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if model.isProcessingLowPoly {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Processing…")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        #if os(macOS)
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(6)
            }
        }
        .onDrop(of: [.image, .fileURL], isTargeted: $dropTargeted) { providers in
            handleDrop(providers)
        }
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.5))
            Text("Choose a photo to start censoring")
                .foregroundStyle(.white.opacity(0.7))
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Choose Photo")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            ToolbarView(model: model)
            ParameterControls(model: model)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
    }

    // MARK: Actions

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let cg = ImageImporter.decode(data) {
                model.loadImage(cg)
            } else {
                statusMessage = String(localized: "Could not load that image.")
            }
        }
    }

    #if os(macOS)
    private func paste() {
        if let cg = MacImport.imageFromPasteboard() {
            model.loadImage(cg)
        } else {
            statusMessage = String(localized: "No image on the clipboard.")
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        Task {
            if let cg = await MacImport.loadCGImage(from: provider) {
                model.loadImage(cg)
            } else {
                statusMessage = String(localized: "Could not load that image.")
            }
        }
        return true
    }
    #endif

    private func save() {
        isExporting = true
        Task {
            defer { isExporting = false }
            guard let data = model.exportJPEG() else {
                statusMessage = String(localized: "Export failed.")
                return
            }
            #if os(iOS) || os(visionOS)
            switch await ImageExporter.saveToPhotos(data) {
            case .success: statusMessage = String(localized: "Saved to Photos.")
            case .denied:  statusMessage = String(localized: "Photos access was denied.")
            case .failed:  statusMessage = String(localized: "Could not save to Photos.")
            }
            #elseif os(macOS)
            switch MacExport.saveWithPanel(data) {
            case .success:  statusMessage = String(localized: "Image saved.")
            case .canceled: break
            case .failed:   statusMessage = String(localized: "Could not save the image.")
            }
            #endif
        }
    }

    private func share() {
        guard let data = model.exportJPEG(), let url = ImageExporter.writeTemporaryFile(data) else {
            statusMessage = String(localized: "Export failed.")
            return
        }
        #if canImport(UIKit)
        shareItems = [url]
        #elseif os(macOS)
        MacExport.share(url)
        #endif
    }

    // MARK: Bindings

    private var statusBinding: Binding<Bool> {
        Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })
    }

    #if canImport(UIKit)
    private var shareBinding: Binding<Bool> {
        Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })
    }
    #endif
}

#Preview {
    EditorScreen()
}
