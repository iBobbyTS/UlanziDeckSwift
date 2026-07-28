import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

nonisolated enum H200ButtonColorTemperatureFilter {
    private static let context = CIContext(options: [
        .cacheIntermediates: false,
    ])

    static func pngData(
        from bitmap: NSBitmapImageRep,
        colorTemperatureKelvin: Double?
    ) throws -> Data {
        guard let colorTemperatureKelvin,
              colorTemperatureKelvin.isFinite,
              colorTemperatureKelvin < NightShiftColorTemperatureMapping.neutralKelvin
        else {
            return try encodePNG(bitmap)
        }

        guard let inputCGImage = bitmap.cgImage else {
            throw H200ButtonIconRenderError.cannotApplyColorTemperature
        }

        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = CIImage(cgImage: inputCGImage)
        filter.neutral = CIVector(
            x: NightShiftColorTemperatureMapping.neutralKelvin,
            y: 0
        )
        filter.targetNeutral = CIVector(
            x: max(
                NightShiftColorTemperatureMapping.warmestKelvin,
                colorTemperatureKelvin
            ),
            y: 0
        )

        guard let outputImage = filter.outputImage,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let outputCGImage = context.createCGImage(
                  outputImage,
                  from: outputImage.extent,
                  format: .RGBA8,
                  colorSpace: colorSpace
              )
        else {
            throw H200ButtonIconRenderError.cannotApplyColorTemperature
        }

        return try encodePNG(NSBitmapImageRep(cgImage: outputCGImage))
    }

    private static func encodePNG(_ bitmap: NSBitmapImageRep) throws -> Data {
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw H200ButtonIconRenderError.cannotEncodePNG
        }

        return png
    }
}
