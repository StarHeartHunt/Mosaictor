//
//  MacImport.swift
//  Mosaictor
//
//  macOS image import via drag-and-drop and clipboard paste.
//

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

@MainActor
enum MacImport {

    /// Reads an image from the general pasteboard (⌘V).
    static func imageFromPasteboard() -> CGImage? {
        let pb = NSPasteboard.general
        if let image = NSImage(pasteboard: pb) {
            return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        if let data = pb.data(forType: .tiff) ?? pb.data(forType: .png) {
            return ImageImporter.decode(data)
        }
        return nil
    }

    /// Loads a dropped item (image data or a file URL) into a CGImage.
    static func loadCGImage(from provider: NSItemProvider) async -> CGImage? {
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let data = try? await provider.loadImageData() {
            return ImageImporter.decode(data)
        }
        if let url = try? await provider.loadFileURL(),
           let data = try? Data(contentsOf: url) {
            return ImageImporter.decode(data)
        }
        return nil
    }
}

private extension NSItemProvider {
    /// Async wrapper to load the dropped item's image data.
    func loadImageData() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: data) }
            }
        }
    }

    /// Async wrapper to resolve a dropped file URL.
    func loadFileURL() async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            _ = loadObject(ofClass: URL.self) { url, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: url) }
            }
        }
    }
}
#endif
