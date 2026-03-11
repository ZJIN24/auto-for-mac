import Foundation
import Vision

struct OCRService {
    func recognizeText(in snapshot: DisplaySnapshot, rect: PixelRect?) throws -> String {
        let targetRect = (rect ?? PixelRect(x: 0, y: 0, width: snapshot.rgba.width, height: snapshot.rgba.height))
            .clamped(maxWidth: snapshot.rgba.width, maxHeight: snapshot.rgba.height)

        guard let cropped = snapshot.rgba.crop(targetRect), let cgImage = cropped.cgImage else {
            throw StudioError.ocrFailed("OCR 失败：无效的识别区域。")
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let strings = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
            return strings.joined(separator: "\n")
        } catch {
            throw StudioError.ocrFailed(error.localizedDescription)
        }
    }
}
