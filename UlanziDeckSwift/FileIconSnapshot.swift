import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

struct FileIconSnapshotData: Sendable {
    let iconPNGData: Data
    let blurredIconPNGData: Data
}

extension FileIconSnapshotData: Equatable {
    nonisolated static func == (lhs: FileIconSnapshotData, rhs: FileIconSnapshotData) -> Bool {
        lhs.iconPNGData == rhs.iconPNGData
            && lhs.blurredIconPNGData == rhs.blurredIconPNGData
    }
}

nonisolated enum FileIconSnapshot {
    static let targetLongEdge = 512
    static let defaultBlurRadius = 14.0
    static let maximumBlurRadius = 30.0
    private static let ciContext = CIContext()

    static func snapshotData(for fileURL: URL) -> FileIconSnapshotData? {
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        return snapshotData(for: icon)
    }

    static func snapshotData(for image: NSImage, targetLongEdge: Int = targetLongEdge) -> FileIconSnapshotData? {
        guard let iconPNGData = pngData(for: image, targetLongEdge: targetLongEdge),
              let blurredIconPNGData = blurredPNGData(for: image, targetLongEdge: targetLongEdge, radius: defaultBlurRadius)
        else {
            return nil
        }

        return FileIconSnapshotData(
            iconPNGData: iconPNGData,
            blurredIconPNGData: blurredIconPNGData
        )
    }

    static func pngData(
        for image: NSImage,
        targetLongEdge: Int = targetLongEdge,
        brightness: Double = 1
    ) -> Data? {
        guard targetLongEdge > 0,
              let imageSize = normalizedImageSize(for: image),
              brightness.isFinite
        else {
            return nil
        }

        let pixelSize = pixelSize(for: imageSize, targetLongEdge: targetLongEdge)
        return renderPNGData(
            for: image,
            pixelSize: pixelSize,
            brightness: min(1, max(0, brightness))
        )
    }

    static func blurredPNGData(for image: NSImage, targetLongEdge: Int = targetLongEdge, radius: Double) -> Data? {
        guard let imageSize = normalizedImageSize(for: image) else {
            return nil
        }

        let pixelSize = pixelSize(for: imageSize, targetLongEdge: targetLongEdge)
        guard let sourceCGImage = renderCGImage(for: image, pixelSize: pixelSize) else {
            return nil
        }

        let sourceImage = CIImage(cgImage: sourceCGImage)
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = sourceImage
        filter.radius = Float(max(0, radius))
        guard let outputImage = filter.outputImage?.cropped(to: sourceImage.extent),
              let blurredCGImage = ciContext.createCGImage(outputImage, from: sourceImage.extent)
        else {
            return nil
        }

        let blurredImage = NSImage(cgImage: blurredCGImage, size: pixelSize)
        return renderPNGData(for: blurredImage, pixelSize: pixelSize)
    }

    private static func renderPNGData(
        for image: NSImage,
        pixelSize: NSSize,
        brightness: Double = 1
    ) -> Data? {
        guard let rep = bitmapImageRep(pixelSize: pixelSize) else {
            return nil
        }

        draw(image, in: rep)
        if brightness < 1 {
            NSGraphicsContext.saveGraphicsState()
            let context = NSGraphicsContext(bitmapImageRep: rep)
            NSGraphicsContext.current = context
            NSColor(calibratedWhite: 0, alpha: 1 - brightness).setFill()
            NSRect(origin: .zero, size: pixelSize).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        return rep.representation(using: .png, properties: [:])
    }

    private static func renderCGImage(for image: NSImage, pixelSize: NSSize) -> CGImage? {
        guard let rep = bitmapImageRep(pixelSize: pixelSize) else {
            return nil
        }

        draw(image, in: rep)
        return rep.cgImage
    }

    private static func bitmapImageRep(pixelSize: NSSize) -> NSBitmapImageRep? {
        let width = Int(pixelSize.width.rounded())
        let height = Int(pixelSize.height.rounded())

        guard width > 0,
              height > 0,
              let rep = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: width,
                  pixelsHigh: height,
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: 0,
                  bitsPerPixel: 0
              )
        else {
            return nil
        }

        rep.size = pixelSize
        return rep
    }

    private static func draw(_ image: NSImage, in rep: NSBitmapImageRep) {
        let canvasSize = rep.size
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        context?.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: canvasSize).fill()
        image.draw(
            in: NSRect(origin: .zero, size: canvasSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func normalizedImageSize(for image: NSImage) -> NSSize? {
        if image.size.width > 0, image.size.height > 0 {
            return image.size
        }

        guard let representation = image.representations.first,
              representation.pixelsWide > 0,
              representation.pixelsHigh > 0
        else {
            return nil
        }

        return NSSize(width: representation.pixelsWide, height: representation.pixelsHigh)
    }

    private static func pixelSize(for imageSize: NSSize, targetLongEdge: Int) -> NSSize {
        let longEdge = max(imageSize.width, imageSize.height)
        guard longEdge > 0 else {
            return .zero
        }

        let targetEdge = min(Double(targetLongEdge), longEdge)
        let scale = targetEdge / longEdge
        return NSSize(
            width: max(1, (imageSize.width * scale).rounded()),
            height: max(1, (imageSize.height * scale).rounded())
        )
    }
}
