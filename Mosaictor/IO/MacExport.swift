//
//  MacExport.swift
//  Mosaictor
//
//  macOS save (NSSavePanel, which grants write access under the sandbox) and
//  share (NSSharingServicePicker).
//

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

@MainActor
enum MacExport {

    enum SaveResult { case success, canceled, failed }

    static func saveWithPanel(_ data: Data, suggestedName: String = "Mosaic.jpg") -> SaveResult {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.jpeg]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return .canceled }
        do {
            try data.write(to: url)
            return .success
        } catch {
            return .failed
        }
    }

    static func share(_ url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        if let view = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
    }
}
#endif
