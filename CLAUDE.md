# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Mosaictor is a SwiftUI multiplatform app (iOS-first, also macOS and visionOS).

It is a single-screen photo censoring editor with six tools — rect Mosaic, rect Blur, Brush (finger) Mosaic, Brush Blur, Highlight/spotlight, Low Poly — plus a global Sharpness slider, undo/redo, save, share, and import.

- Bundle ID: `icu.baka.Mosaictor`
- Deployment target: **iOS / macOS / visionOS 26.5** (all three)
- Swift 5.0, Xcode project (no SwiftPM packages; engine is all first-party)

## Build & run

Build for the simulator (the iOS 26.5 runtime is **required** — installing onto an older runtime fails with "需要更高版本的iOS"):

```sh
xcodebuild -project Mosaictor.xcodeproj -scheme Mosaictor \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build
```

macOS: `-destination 'platform=macOS'` (signs with the configured dev team `6BW6RZRJZM`).

Find/create a 26.5 simulator device:
```sh
xcrun simctl list devices | awk '/-- iOS 26.5 --/{f=1;next} /^-- /{f=0} f && /iPhone 1[67]/{print;exit}'
```

### DEBUG demo launch hooks (screenshot without the photo picker)

`EditorScreen` reads `MOSAICTOR_DEMO` (`#if DEBUG`) and seeds the editor on launch. The `SIMCTL_CHILD_` prefix is **required** to pass env through `simctl launch` (a bare `KEY=VAL` arg does not set env):

```sh
SIMCTL_CHILD_MOSAICTOR_DEMO=1 xcrun simctl launch <udid> icu.baka.Mosaictor
```

Values: `1` seeds ops on a synthetic image · `2` drives the interactive begin/update/end + undo drawing path · `3` leaves an active rectangle selection overlay · `4` draws a low-poly rect after the view settles. See the `#if DEBUG` extension at the bottom of `Model/EditorModel.swift`.

### Headless engine verification

`Engine/` + `Model/` are pure Swift with no UIKit/AppKit dependency. To verify rendering without a simulator, compile those files with `swiftc` into a CLI harness, drive `ImagePipeline.render` / `jpegData` inside `MainActor.assumeIsolated { ... }`, and write PNG/JPEG to inspect. (Screen-recording the running macOS app is blocked in this environment, and headless AppKit won't render `NSImage`.)

To time Low Poly specifically: `swiftc -O` (or `-Onone`) the four `Engine/LowPoly/*.swift` files. In Release it's ~35–70 ms (1300–4000 pts); in Debug ~0.2–1.4 s — the O(N²) Bowyer–Watson Delaunay dominates.

## Architecture

The data flow is **normalized operation stack → Core Image filter graph → composited `CGImage`**. The same operations re-render at any resolution, so the live preview and the exported file are pixel-identical.

### Model layer (`Model/`) — non-destructive, resolution-independent

- `Operation.swift` — an `Operation` is `{ tool, geometry, params }`. **All geometry is normalized image space (0...1, origin top-left)**, so it's invariant to zoom/view-size/working-resolution. `EffectParams` stores raw slider readings (not pixels); the pipeline converts to pixels for whatever resolution it renders at. Each committed op captures the sliders at draw time, so two regions of the same tool can differ.
- `ToolType.swift` — the six tools. Key derived properties: `inputMode` (`.rectangle` / `.path` / `.whole`) drives how the canvas collects input; `sliderSpec` defines each tool's parameter range. Low Poly is `.rectangle` input (a selection tool), not whole-image.
- `EditorModel.swift` — `@MainActor @Observable` single source of truth: the ordered `operations` stack, `redoStack`, the in-progress `draft` op, `liveParams`, `activeTool`, and the composited `displayImage`. Owns the `ImagePipeline`. Drawing is `beginStroke`/`updateStroke`/`endStroke` (normalized coords in). Every state change calls `recomposite()`.

### Engine layer (`Engine/`) — Core Image compositing

The compositing model is **effect layer + grayscale mask + `CIBlendWithMask`**, applied per operation in stack order:

- `ImagePipeline.swift` — `@MainActor` orchestrator. One reused `CIContext` renders the same filter graph at preview (capped, `previewMaxDimension` = 1400) and export (full) resolution. `render(operations:targetSize:)` folds the op stack; `exportSize`/`previewSize` derive from the Sharpness slider (lower Sharpness ⇒ smaller output). Each op builds a mask, builds its effect `CIImage`, and blends.
- `EffectLayers.swift` — produces full-image effect images: `pixelate`, `blur` (Gaussian, clamp-then-crop to kill edge bleed), `darken` (semi-transparent black overlay for Highlight). Slider→pixel scaling is proportional to `refDim` so effects look identical at any resolution.
- `MaskBuilder.swift` — renders one geometry to a grayscale mask via `CGContext` (white = effect visible). Single primitive serves rectangles (filled) and brush paths (stroked, round caps, width from `strokeSlider`); brush masks are softly feathered.
- `LowPoly/` — vendored low-poly renderer: `PointSampler` (importance-sampled points) → `Delaunay` (Bowyer–Watson triangulation) → `LowPolyRenderer` (fills triangles with averaged color); `Bitmap` is the CPU pixel buffer.

**Highlight** inverts the usual blend: it darkens everything, then the rect mask keeps the *original bright* pixels inside the selection (a spotlight).

**Low Poly is special** because it's CPU-expensive. The full-image low-poly layer is computed off the main thread (`prepareLowPoly` → `Task.detached`, `LowPoly` compute funcs are `nonisolated`), cached in `ImagePipeline.lowPolyCache` keyed by `(pointCount, renderSize)`, then clipped to the drawn rect like any other effect. `EditorModel.scheduleLowPoly(debounce:)` precomputes the needed point-counts (200 ms slider debounce) so drawing reveals the effect live; `isProcessingLowPoly` drives the spinner. In preview, if the layer isn't ready the region renders unprocessed (never blocks); export always computes synchronously (`computeLowPolySync: true`).

### View / platform layer

- `UI/EditorScreen.swift` — the whole screen (top bar, canvas, tool selector, sliders). Owns `EditorModel` and wires import/save/share per platform with `#if`.
- `Canvas/CanvasView_iOS.swift` / `CanvasView_macOS.swift` — platform `CanvasView` representables sharing the **same name and init signature**, selected by `#if canImport(UIKit)` / `#if os(macOS)`. They convert touch/mouse points to normalized image coords (`normalized(from:)` via aspect-fit `displayRect`) and draw the image + selection overlay. iOS: one-finger draws, two-finger pan + pinch zoom.
- `IO/` — platform-split import/export: `ImageImporter`/`ImageExporter`/`ShareSupport` (shared + iOS), `MacImport`/`MacExport` (macOS pasteboard, save panel, share). `Support/Settings.swift` persists tool/params/sharpness across launches; `Support/DemoImage.swift` is the synthetic image for DEBUG demos.

## Conventions

- **Geometry is always normalized (0...1, top-left)** at the model boundary; pixel conversion happens only inside the engine, scaled by `refDim`. Don't store pixel coords in `Operation`.
- **Preview and export share one filter graph** — fixes must hold at both resolutions. Verify changes affect the exported file, not just the on-screen preview.
- Platform code is split by file with matching type names and gated by `#if canImport(UIKit)` / `#if os(macOS)`; keep the cross-platform surface (e.g. `CanvasView`'s signature) identical.
- **Localization** uses String Catalogs (`Localizable.xcstrings`, `InfoPlist.xcstrings`). Source is `en` with 8 localizations: zh-Hans, ja, fr, ru, ar, id, de, ko (all listed in `knownRegions`). Tool/slider titles are `LocalizedStringResource`; status messages use `String(localized:)`; the app name "Mosaictor" is `Text(verbatim:)` (not localized). RTL (`ar`) mirrors automatically. To test a language, **uninstall first** (the `-AppleLanguages` override caches in simulator state), then `simctl install` + `simctl launch <udid> icu.baka.Mosaictor -AppleLanguages '(ja)'`.
