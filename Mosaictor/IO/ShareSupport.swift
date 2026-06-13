//
//  ShareSupport.swift
//  Mosaictor
//
//  A UIActivityViewController wrapper for sharing the exported image on iOS.
//  (macOS sharing is added during the macOS bring-up phase.)
//

#if canImport(UIKit)
import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
