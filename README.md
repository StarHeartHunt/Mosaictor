# Mosaictor

> A SwiftUI multiplatform photo censoring / masking editor for iOS, macOS, and visionOS.

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20visionOS-blue)](#platform-support)
[![License](https://img.shields.io/badge/license-AGPL--3.0-green)](LICENSE)

**English** · [中文](README.zh-CN.md)

Mosaictor is a **single-screen photo censoring editor**: import an image, mask sensitive regions with six tools, then save or share. All edits are **non-destructive** — what you preview is exactly what you export.

## Features

Six masking tools:

| Tool | Input | Effect |
| --- | --- | --- |
| **Mosaic** | drag a rectangle | pixelate the region |
| **Blur** | drag a rectangle | Gaussian-blur the region |
| **Brush Mosaic** | finger paint | pixelate along the stroke |
| **Brush Blur** | finger paint | Gaussian-blur along the stroke |
| **Highlight / Spotlight** | drag a rectangle | keep the selection bright, darken everything else |
| **Low Poly** | drag a rectangle | triangulate the region (low-poly style) |

Plus:

- **Global sharpness slider** — lowers output resolution to obscure further
- **Undo / redo** — full operation-history stack
- **Import** — system photo picker; macOS also supports paste (⌘V) and drag-and-drop
- **Save / share** — iOS saves to Photos; macOS uses a save panel / system share
- **Localized** — English source plus 8 localizations (including Arabic with automatic RTL mirroring)

## Platform support

| Platform | Minimum version |
| --- | --- |
| iOS | 26.5 |
| macOS | 26.5 |
| visionOS | 26.5 |

Bundle ID: `icu.baka.Mosaictor`

## Architecture

The data flow is **normalized operation stack → Core Image filter graph → composited `CGImage`**. The same operations re-render at any resolution, so the live preview and the exported file are pixel-identical.

- **Non-destructive, resolution-independent model** — each `Operation` records `{ tool, geometry, params }`. Geometry is stored in normalized space (0…1, top-left origin); params store raw slider values (not pixels) and the engine converts them to pixels for the current render resolution.
- **Core Image compositing engine** — an "effect layer + grayscale mask + `CIBlendWithMask`" model, applied per operation in stack order. One reused `CIContext` drives both the preview (capped dimension) and the export (full resolution).
- **Low-poly renderer** — a vendored Bowyer–Watson Delaunay triangulation. Because it is O(N²), the full-image low-poly layer is computed off the main thread and cached, then clipped to the selection; in preview it renders unprocessed until ready (never blocks the UI), and export always computes it synchronously.
- **Cross-platform view layer** — the editing canvas is a platform-native `CanvasView` (iOS `UIViewRepresentable` / macOS `NSViewRepresentable`) sharing one interface, selected with `#if`.

Source layout:

```
Mosaictor/
├── Model/       # Operation / ToolType / EditorModel (@Observable state source)
├── Engine/      # ImagePipeline, EffectLayers, MaskBuilder
│   └── LowPoly/ # PointSampler → Delaunay → LowPolyRenderer
├── Canvas/      # CanvasView, per-platform (iOS / macOS)
├── UI/          # EditorScreen, ToolbarView, ParameterSlider
├── IO/          # import / export / share (platform-split)
└── Support/     # Settings persistence, DemoImage
```

## Build & run

Requires Xcode with the **iOS / macOS 26.5** SDK. The simulator must use the 26.5 runtime or installation fails.

```sh
# iOS simulator
xcodebuild -project Mosaictor.xcodeproj -scheme Mosaictor \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build

# macOS
xcodebuild -project Mosaictor.xcodeproj -scheme Mosaictor \
  -destination 'platform=macOS' build
```

Or just open `Mosaictor.xcodeproj` in Xcode, pick a target device, and run. See [CLAUDE.md](CLAUDE.md) for more build and debugging details.

## License

[GNU AGPL-3.0](LICENSE) © 2026 StarHeartHunt
