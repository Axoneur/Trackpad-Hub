import Foundation
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Génère le QR code d'appairage affiché par l'app macOS.
enum QRCodeRenderer {

    static func image(for text: String, size: CGFloat = 190) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        // Correction d'erreur élevée : le QR reste lisible même mal cadré ou
        // photographié de biais.
        filter.correctionLevel = "H"

        guard let output = filter.outputImage else { return nil }

        // Le QR natif fait quelques dizaines de pixels : on l'agrandit sans
        // interpolation, sinon les modules deviennent flous et illisibles.
        let scale = size / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
