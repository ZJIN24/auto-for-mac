import Foundation
import AppKit

struct RGBAImage: Hashable {
    let width: Int
    let height: Int
    fileprivate let bytes: [UInt8]

    init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    init?(cgImage: CGImage) {
        let width = cgImage.width
        let height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        self.init(width: width, height: height, bytes: bytes)
    }

    func contains(_ point: PixelPoint) -> Bool {
        point.x >= 0 && point.y >= 0 && point.x < width && point.y < height
    }

    func color(at point: PixelPoint) -> PixelColor? {
        guard contains(point) else {
            return nil
        }

        let index = ((point.y * width) + point.x) * 4
        guard index + 3 < bytes.count else {
            return nil
        }
        return PixelColor(
            red: Int(bytes[index]),
            green: Int(bytes[index + 1]),
            blue: Int(bytes[index + 2]),
            alpha: Int(bytes[index + 3])
        )
    }

    func crop(_ rect: PixelRect) -> RGBAImage? {
        let clipped = rect.clamped(maxWidth: width, maxHeight: height)
        guard clipped.isValid else {
            return nil
        }

        var newBytes = [UInt8](repeating: 0, count: clipped.width * clipped.height * 4)
        for row in 0..<clipped.height {
            let sourceStart = ((clipped.y + row) * width + clipped.x) * 4
            let sourceEnd = sourceStart + clipped.width * 4
            let targetStart = row * clipped.width * 4
            let targetEnd = targetStart + clipped.width * 4
            newBytes.replaceSubrange(targetStart..<targetEnd, with: bytes[sourceStart..<sourceEnd])
        }

        return RGBAImage(width: clipped.width, height: clipped.height, bytes: newBytes)
    }

    func processed(_ mode: TemplateProcessingMode) -> RGBAImage {
        switch mode {
        case .original:
            return self
        case .grayscale:
            return grayscale()
        case .binary:
            return binary()
        }
    }

    func grayscale() -> RGBAImage {
        var newBytes = bytes
        for index in stride(from: 0, to: newBytes.count, by: 4) {
            let red = Double(newBytes[index])
            let green = Double(newBytes[index + 1])
            let blue = Double(newBytes[index + 2])
            let gray = UInt8(max(0, min(255, Int((red * 0.299) + (green * 0.587) + (blue * 0.114)))))
            newBytes[index] = gray
            newBytes[index + 1] = gray
            newBytes[index + 2] = gray
        }
        return RGBAImage(width: width, height: height, bytes: newBytes)
    }

    func binary(threshold: Int = 160) -> RGBAImage {
        var newBytes = bytes
        for index in stride(from: 0, to: newBytes.count, by: 4) {
            let red = Int(newBytes[index])
            let green = Int(newBytes[index + 1])
            let blue = Int(newBytes[index + 2])
            let gray = Int((Double(red) * 0.299) + (Double(green) * 0.587) + (Double(blue) * 0.114))
            let value: UInt8 = gray >= threshold ? 255 : 0
            newBytes[index] = value
            newBytes[index + 1] = value
            newBytes[index + 2] = value
        }
        return RGBAImage(width: width, height: height, bytes: newBytes)
    }

    func firstPoint(
        matching targetColor: PixelColor,
        in searchRect: PixelRect?,
        tolerance: Int
    ) -> PixelPoint? {
        let rect = (searchRect ?? PixelRect(x: 0, y: 0, width: width, height: height))
            .clamped(maxWidth: width, maxHeight: height)
        guard rect.isValid else {
            return nil
        }

        for y in rect.y..<(rect.y + rect.height) {
            for x in rect.x..<(rect.x + rect.width) {
                let point = PixelPoint(x: x, y: y)
                guard let color = color(at: point) else {
                    continue
                }
                if color.matches(targetColor, tolerance: tolerance) {
                    return point
                }
            }
        }
        return nil
    }

    var cgImage: CGImage? {
        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            .union(.byteOrder32Big)

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    var pngData: Data? {
        guard let cgImage else {
            return nil
        }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }
}

struct TemplateMatch {
    var rect: PixelRect
    var score: Double
}

struct TemplateMatcher {
    func find(
        template: RGBAImage,
        in frame: RGBAImage,
        searchRect: PixelRect?,
        minimumSimilarity: Double
    ) -> TemplateMatch? {
        guard frame.width >= template.width, frame.height >= template.height else {
            return nil
        }

        let fullSearchRect = (searchRect ?? PixelRect(x: 0, y: 0, width: frame.width, height: frame.height))
            .clamped(maxWidth: frame.width, maxHeight: frame.height)
        let maxX = fullSearchRect.x + fullSearchRect.width - template.width
        let maxY = fullSearchRect.y + fullSearchRect.height - template.height

        guard maxX >= fullSearchRect.x, maxY >= fullSearchRect.y else {
            return nil
        }

        let quickOffsets = makeQuickOffsets(for: template)
        let detailedOffsets = makeDetailedOffsets(for: template)
        let candidateStep = makeCandidateStep(for: template)
        var bestMatch: TemplateMatch?

        for y in stride(from: fullSearchRect.y, through: maxY, by: candidateStep) {
            for x in stride(from: fullSearchRect.x, through: maxX, by: candidateStep) {
                let quickScore = compare(
                    template: template,
                    frame: frame,
                    originX: x,
                    originY: y,
                    offsets: quickOffsets
                )

                if quickScore + 0.08 < minimumSimilarity {
                    continue
                }

                let detailScore = compare(
                    template: template,
                    frame: frame,
                    originX: x,
                    originY: y,
                    offsets: detailedOffsets
                )

                if detailScore >= minimumSimilarity {
                    let match = TemplateMatch(
                        rect: PixelRect(x: x, y: y, width: template.width, height: template.height),
                        score: detailScore
                    )
                    if bestMatch == nil || detailScore > bestMatch!.score {
                        bestMatch = match
                    }
                }
            }
        }

        return bestMatch
    }

    private func makeCandidateStep(for template: RGBAImage) -> Int {
        let area = template.width * template.height
        switch area {
        case 0..<6_000:
            return 1
        case 6_000..<30_000:
            return 2
        default:
            return 4
        }
    }

    private func makeQuickOffsets(for template: RGBAImage) -> [PixelPoint] {
        let xs = [0, template.width / 4, template.width / 2, (template.width * 3) / 4, max(0, template.width - 1)]
        let ys = [0, template.height / 4, template.height / 2, (template.height * 3) / 4, max(0, template.height - 1)]

        var result = Set<PixelPoint>()
        for x in xs {
            result.insert(PixelPoint(x: x, y: ys[0]))
            result.insert(PixelPoint(x: x, y: ys[2]))
            result.insert(PixelPoint(x: x, y: ys[4]))
        }
        for y in ys {
            result.insert(PixelPoint(x: xs[0], y: y))
            result.insert(PixelPoint(x: xs[2], y: y))
            result.insert(PixelPoint(x: xs[4], y: y))
        }
        return Array(result)
    }

    private func makeDetailedOffsets(for template: RGBAImage) -> [PixelPoint] {
        let stepX: Int
        let stepY: Int

        switch template.width * template.height {
        case 0..<4_000:
            stepX = 1
            stepY = 1
        case 4_000..<20_000:
            stepX = 2
            stepY = 2
        case 20_000..<80_000:
            stepX = 3
            stepY = 3
        default:
            stepX = 5
            stepY = 5
        }

        var offsets: [PixelPoint] = []
        var y = 0
        while y < template.height {
            var x = 0
            while x < template.width {
                offsets.append(PixelPoint(x: x, y: y))
                x += stepX
            }
            y += stepY
        }

        offsets.append(PixelPoint(x: max(0, template.width - 1), y: max(0, template.height - 1)))
        offsets.append(PixelPoint(x: template.width / 2, y: template.height / 2))
        return Array(Set(offsets))
    }

    private func compare(
        template: RGBAImage,
        frame: RGBAImage,
        originX: Int,
        originY: Int,
        offsets: [PixelPoint]
    ) -> Double {
        guard !offsets.isEmpty else {
            return 0
        }

        var totalDifference = 0
        for offset in offsets {
            let templateIndex = ((offset.y * template.width) + offset.x) * 4
            let frameIndex = (((originY + offset.y) * frame.width) + (originX + offset.x)) * 4

            guard templateIndex + 2 < template.bytes.count,
                  frameIndex + 2 < frame.bytes.count else {
                continue
            }

            totalDifference += abs(Int(template.bytes[templateIndex]) - Int(frame.bytes[frameIndex]))
            totalDifference += abs(Int(template.bytes[templateIndex + 1]) - Int(frame.bytes[frameIndex + 1]))
            totalDifference += abs(Int(template.bytes[templateIndex + 2]) - Int(frame.bytes[frameIndex + 2]))
        }

        let maxDifference = Double(offsets.count * 255 * 3)
        guard maxDifference > 0 else {
            return 0
        }
        return max(0, 1 - Double(totalDifference) / maxDifference)
    }
}
