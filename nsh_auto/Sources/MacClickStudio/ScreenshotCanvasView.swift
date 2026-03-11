import SwiftUI
import AppKit

private struct CanvasMapper {
    let imageSize: CGSize
    let viewportSize: CGSize
    let contentSize: CGSize
    let zoomScale: CGFloat
    let padding: CGFloat = 24

    private var fittedSize: CGSize {
        guard imageSize.width > 0, imageSize.height > 0, viewportSize.width > 0, viewportSize.height > 0 else {
            return .zero
        }

        let scale = min(
            max((viewportSize.width - padding) / imageSize.width, 0.01),
            max((viewportSize.height - padding) / imageSize.height, 0.01)
        )
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    var imageRect: CGRect {
        let width = fittedSize.width * zoomScale
        let height = fittedSize.height * zoomScale
        return CGRect(
            x: (contentSize.width - width) / 2,
            y: (contentSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    static func contentSize(imageSize: CGSize, viewportSize: CGSize, zoomScale: CGFloat, padding: CGFloat = 24) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0, viewportSize.width > 0, viewportSize.height > 0 else {
            return viewportSize
        }

        let scale = min(
            max((viewportSize.width - padding) / imageSize.width, 0.01),
            max((viewportSize.height - padding) / imageSize.height, 0.01)
        )
        let fittedWidth = imageSize.width * scale * zoomScale
        let fittedHeight = imageSize.height * scale * zoomScale

        return CGSize(
            width: max(viewportSize.width, fittedWidth + padding),
            height: max(viewportSize.height, fittedHeight + padding)
        )
    }

    func pixelPoint(from location: CGPoint) -> PixelPoint? {
        guard imageRect.contains(location), imageRect.width > 0, imageRect.height > 0 else {
            return nil
        }

        let normalizedX = (location.x - imageRect.minX) / imageRect.width
        let normalizedY = (location.y - imageRect.minY) / imageRect.height
        let pixelX = min(Int(normalizedX * imageSize.width), max(Int(imageSize.width) - 1, 0))
        let pixelY = min(Int(normalizedY * imageSize.height), max(Int(imageSize.height) - 1, 0))
        return PixelPoint(x: pixelX, y: pixelY)
    }

    func clampedPixelPoint(from location: CGPoint) -> PixelPoint? {
        guard imageRect.width > 0, imageRect.height > 0 else {
            return nil
        }

        let clamped = CGPoint(
            x: min(max(location.x, imageRect.minX), imageRect.maxX - 0.001),
            y: min(max(location.y, imageRect.minY), imageRect.maxY - 0.001)
        )
        return pixelPoint(from: clamped)
    }

    func viewPoint(from point: PixelPoint) -> CGPoint {
        CGPoint(
            x: imageRect.minX + (CGFloat(point.x) + 0.5) / imageSize.width * imageRect.width,
            y: imageRect.minY + (CGFloat(point.y) + 0.5) / imageSize.height * imageRect.height
        )
    }

    func viewRect(from rect: PixelRect) -> CGRect {
        let minX = imageRect.minX + CGFloat(rect.x) / imageSize.width * imageRect.width
        let minY = imageRect.minY + CGFloat(rect.y) / imageSize.height * imageRect.height
        let width = CGFloat(rect.width) / imageSize.width * imageRect.width
        let height = CGFloat(rect.height) / imageSize.height * imageRect.height
        return CGRect(x: minX, y: minY, width: width, height: height)
    }
}

struct ScreenshotCanvasView: View {
    @EnvironmentObject private var store: StudioStore
    let image: NSImage
    @Binding private var zoomScale: CGFloat
    @State private var isCanvasHovered = false
    @State private var scrollMonitor: Any?

    private let zoomRange: ClosedRange<CGFloat> = 0.4...4.0

    init(image: NSImage, zoomScale: Binding<CGFloat>) {
        self.image = image
        self._zoomScale = zoomScale
    }

    init(image: NSImage, zoomScale: CGFloat = 1) {
        self.image = image
        self._zoomScale = .constant(zoomScale)
    }

    var body: some View {
        GeometryReader { proxy in
            let contentSize = CanvasMapper.contentSize(
                imageSize: image.size,
                viewportSize: proxy.size,
                zoomScale: max(zoomScale, zoomRange.lowerBound)
            )
            let mapper = CanvasMapper(
                imageSize: image.size,
                viewportSize: proxy.size,
                contentSize: contentSize,
                zoomScale: max(zoomScale, zoomRange.lowerBound)
            )

            ScrollView([.horizontal, .vertical]) {
                canvasContent(mapper: mapper)
                    .frame(width: contentSize.width, height: contentSize.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { installScrollMonitor() }
            .onDisappear { removeScrollMonitor() }
        }
    }

    private func canvasContent(mapper: CanvasMapper) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.92))

            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: mapper.imageRect.width, height: mapper.imageRect.height)
                .position(x: mapper.imageRect.midX, y: mapper.imageRect.midY)

            Path { path in
                path.addRect(mapper.imageRect)
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 1)

            if let windowRect = store.selectedWindowPixelRect {
                Path { path in
                    path.addRect(mapper.viewRect(from: windowRect))
                }
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 2, dash: [10, 4]))
            }

            if let selectedRect = store.selectedRect {
                Path { path in
                    path.addRect(mapper.viewRect(from: selectedRect))
                }
                .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
            }

            if let selectedPoint = store.selectedPoint {
                let point = mapper.viewPoint(from: selectedPoint)
                crosshair(at: point, color: .green)
            }

            if let selectedSamplePoint = store.selectedSamplePoint, selectedSamplePoint != store.selectedPoint {
                let point = mapper.viewPoint(from: selectedSamplePoint)
                sampleTarget(at: point, color: .cyan)
            }

            if let hover = store.hover {
                let point = mapper.viewPoint(from: hover.rawPoint)
                crosshair(at: point, color: .orange.opacity(0.8))
            }

            if let hover = store.hover, hover.rawPoint != hover.sampledPoint {
                let point = mapper.viewPoint(from: hover.sampledPoint)
                sampleTarget(at: point, color: .pink.opacity(0.9))
            }

            ForEach(store.samples) { sample in
                let point = mapper.viewPoint(from: sample.point)
                sampleMarker(sample, at: point)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("使用悬停点作为当前点") {
                store.promoteHoverToSelection()
            }
            .disabled(!store.hasContextPoint)

            Divider()

            Button("复制点击坐标") {
                store.promoteHoverToSelection()
                store.copySelectedCoordinate()
            }
            .disabled(!store.hasContextPoint)

            Button("复制取色坐标") {
                store.promoteHoverToSelection()
                store.copySelectedSampleCoordinate()
            }
            .disabled(!store.hasContextPoint)

            Button("复制颜色") {
                store.promoteHoverToSelection()
                store.copySelectedColor()
            }
            .disabled(!store.hasContextPoint)

            Divider()

            Button("加入比色点") {
                store.promoteHoverToSelection()
                store.addSampleFromSelectedPoint()
            }
            .disabled(!store.hasContextPoint)

            Button("添加点击步骤") {
                store.promoteHoverToSelection()
                store.addClickStep()
            }
            .disabled(!store.hasContextPoint)

            Button("添加长按步骤") {
                store.promoteHoverToSelection()
                store.addLongPressStep()
            }
            .disabled(!store.hasContextPoint)

            Button("添加拖动步骤（当前点→悬停点）") {
                store.addDragStep()
            }
            .disabled(store.selectedPoint == nil || store.hover == nil || store.hover?.rawPoint == store.selectedPoint)

            Button("按当前点位锁定窗口") {
                store.promoteHoverToSelection()
                store.lockWindowFromSelectedPoint()
            }
            .disabled(!store.hasContextPoint)
        }
        .gesture(dragGesture(mapper: mapper))
        .onHover { hovering in
            isCanvasHovered = hovering
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                isCanvasHovered = true
                store.updateHover(mapper.pixelPoint(from: location))
            case .ended:
                isCanvasHovered = false
                store.updateHover(nil)
            }
        }
    }

    private func installScrollMonitor() {
        guard scrollMonitor == nil else {
            return
        }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard isCanvasHovered else {
                return event
            }

            let rawDelta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 8
            guard abs(rawDelta) > 0.01 else {
                return event
            }

            let nextZoom = min(max(zoomScale + (rawDelta * 0.01), zoomRange.lowerBound), zoomRange.upperBound)
            guard abs(nextZoom - zoomScale) > 0.0001 else {
                return nil
            }

            zoomScale = nextZoom
            return nil
        }
    }

    private func removeScrollMonitor() {
        guard let scrollMonitor else {
            return
        }
        NSEvent.removeMonitor(scrollMonitor)
        self.scrollMonitor = nil
    }

    private func dragGesture(mapper: CanvasMapper) -> some Gesture {
        DragGesture(minimumDistance: store.interactionMode == .point ? 0 : 2)
            .onChanged { value in
                switch store.interactionMode {
                case .point:
                    store.updateHover(mapper.pixelPoint(from: value.location))
                case .region:
                    guard let start = mapper.clampedPixelPoint(from: value.startLocation),
                          let end = mapper.clampedPixelPoint(from: value.location) else {
                        return
                    }
                    store.updateSelection(PixelRect.between(start, end))
                }
            }
            .onEnded { value in
                switch store.interactionMode {
                case .point:
                    guard let point = mapper.pixelPoint(from: value.location) else {
                        return
                    }
                    store.selectPoint(point)
                case .region:
                    guard let start = mapper.clampedPixelPoint(from: value.startLocation),
                          let end = mapper.clampedPixelPoint(from: value.location) else {
                        store.clearSelection()
                        return
                    }
                    let rect = PixelRect.between(start, end)
                    if rect.width <= 2 || rect.height <= 2 {
                        store.clearSelection()
                    } else {
                        store.updateSelection(rect)
                    }
                }
            }
    }

    private func crosshair(at point: CGPoint, color: Color) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: point.x - 10, y: point.y))
                path.addLine(to: CGPoint(x: point.x + 10, y: point.y))
                path.move(to: CGPoint(x: point.x, y: point.y - 10))
                path.addLine(to: CGPoint(x: point.x, y: point.y + 10))
            }
            .stroke(color, lineWidth: 1.5)

            Circle()
                .stroke(color, lineWidth: 1.5)
                .frame(width: 14, height: 14)
                .position(point)
        }
    }

    private func sampleTarget(at point: CGPoint, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.9))
                .frame(width: 8, height: 8)
                .position(point)
            Circle()
                .stroke(color, lineWidth: 1.5)
                .frame(width: 18, height: 18)
                .position(point)
        }
    }

    private func sampleMarker(_ sample: ColorSample, at point: CGPoint) -> some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(Color(pixelColor: sample.color))
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                .position(point)

            Text(sample.name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.black.opacity(0.72), in: Capsule())
                .foregroundStyle(.white)
                .position(x: point.x + 24, y: point.y - 12)
        }
    }
}
