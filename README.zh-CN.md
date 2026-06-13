# Mosaictor

> 一款面向 iOS / macOS / visionOS 的 SwiftUI 多平台照片打码 / 遮挡编辑器。

[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20visionOS-blue)](#平台支持)
[![License](https://img.shields.io/badge/license-AGPL--3.0-green)](LICENSE)

[English](README.md) · **中文**

Mosaictor 是一个**单屏照片打码编辑器**：导入图片，用六种工具在敏感区域涂抹遮挡，再保存或分享。所有编辑都是**非破坏性**的——预览所见即导出所得。

## 功能特性

六种遮挡工具：

| 工具 | 操作方式 | 效果 |
| --- | --- | --- |
| **马赛克** | 框选矩形 | 区域像素化 |
| **模糊** | 框选矩形 | 区域高斯模糊 |
| **笔刷马赛克** | 手指涂抹 | 沿笔迹像素化 |
| **笔刷模糊** | 手指涂抹 | 沿笔迹高斯模糊 |
| **高亮 / 聚光** | 框选矩形 | 选区保持明亮、其余压暗，形成聚光灯效果 |
| **低多边形** | 框选矩形 | 选区三角形化（Low Poly 风格） |

外加：

- **全局清晰度滑块** —— 降低输出分辨率以进一步模糊化
- **撤销 / 重做** —— 完整的操作历史栈
- **导入** —— 系统照片选择器；macOS 额外支持粘贴（⌘V）与拖拽
- **保存 / 分享** —— iOS 存入「照片」，macOS 通过保存面板 / 系统分享
- **多语言** —— 源语言英文，另含 8 种本地化（含阿拉伯语 RTL 自动镜像）

## 平台支持

| 平台 | 最低版本 |
| --- | --- |
| iOS | 26.5 |
| macOS | 26.5 |
| visionOS | 26.5 |

Bundle ID：`icu.baka.Mosaictor`

## 技术架构

数据流为 **归一化操作栈 → Core Image 滤镜图 → 合成 `CGImage`**。同一组操作能在任意分辨率下重新渲染，因此实时预览与导出文件像素一致。

- **非破坏性、分辨率无关的模型** —— 每个 `Operation` 记录 `{工具, 几何, 参数}`，几何坐标归一化（0…1，左上为原点），参数存储滑块原始值（而非像素），由引擎按当前渲染分辨率换算成像素。
- **Core Image 合成引擎** —— 采用「效果图层 + 灰度遮罩 + `CIBlendWithMask`」模型，按栈顺序逐个操作合成。一个复用的 `CIContext` 同时驱动预览（限制最大边）与导出（全分辨率）。
- **低多边形渲染器** —— 自带 Bowyer–Watson Delaunay 三角剖分。因其 O(N²) 开销，整图低多边形图层在后台线程计算并缓存，再裁剪到选区；预览时若尚未就绪则保持原样（绝不阻塞 UI），导出时强制同步计算。
- **跨平台视图层** —— 编辑画布以平台原生的 `CanvasView`（iOS `UIViewRepresentable` / macOS `NSViewRepresentable`）实现，对外接口一致，按 `#if` 选择。

代码结构概览：

```
Mosaictor/
├── Model/       # Operation / ToolType / EditorModel（@Observable 状态源）
├── Engine/      # ImagePipeline、EffectLayers、MaskBuilder
│   └── LowPoly/ # PointSampler → Delaunay → LowPolyRenderer
├── Canvas/      # CanvasView 的 iOS / macOS 平台实现
├── UI/          # EditorScreen、ToolbarView、ParameterSlider
├── IO/          # 导入 / 导出 / 分享（平台拆分）
└── Support/     # Settings 持久化、DemoImage
```

## 构建与运行

需要 Xcode 与 **iOS / macOS 26.5** SDK。模拟器必须使用 26.5 运行时，否则安装会失败。

```sh
# iOS 模拟器
xcodebuild -project Mosaictor.xcodeproj -scheme Mosaictor \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build

# macOS
xcodebuild -project Mosaictor.xcodeproj -scheme Mosaictor \
  -destination 'platform=macOS' build
```

或直接用 Xcode 打开 `Mosaictor.xcodeproj`，选择目标设备后运行。更多构建细节与调试技巧见 [CLAUDE.md](CLAUDE.md)。

## 许可证

[GNU AGPL-3.0](LICENSE) © 2026 StarHeartHunt
