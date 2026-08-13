import Foundation
import AppKit

/// Rend des symboles SF en PNG, pour illustrer la documentation.
///
/// Les mêmes glyphes que l'app affiche : un tutoriel qui montre l'icône
/// exacte du bouton évite au lecteur de deviner lequel on lui décrit. Redessiner
/// des approximations aurait produit des illustrations fausses le jour où un
/// bouton change.
///
/// Usage : icones dossier taille couleurHexa symbole [symbole …]

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 4 else {
    print("Usage : icones dossier taille #RRGGBB symbole […]")
    exit(1)
}

let dossier = URL(fileURLWithPath: arguments[0])
let taille = Double(arguments[1]) ?? 48
let hexa = arguments[2].trimmingCharacters(in: CharacterSet(charactersIn: "#"))
let symboles = Array(arguments.dropFirst(3))

func couleur(_ hexa: String) -> NSColor {
    var valeur: UInt64 = 0
    Scanner(string: hexa).scanHexInt64(&valeur)
    return NSColor(srgbRed: CGFloat((valeur >> 16) & 0xFF) / 255,
                   green: CGFloat((valeur >> 8) & 0xFF) / 255,
                   blue: CGFloat(valeur & 0xFF) / 255,
                   alpha: 1)
}

try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

var manquants: [String] = []
for nom in symboles {
    guard let symbole = NSImage(systemSymbolName: nom, accessibilityDescription: nil) else {
        manquants.append(nom)
        continue
    }
    let configure = symbole.withSymbolConfiguration(
        .init(pointSize: taille * 0.72, weight: .medium))
        ?? symbole

    // Fond transparent : le README s'affiche en clair comme en sombre, et une
    // icône sur fond blanc trouerait le thème sombre.
    let cible = NSSize(width: taille, height: taille)
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                  pixelsWide: Int(taille * 2), pixelsHigh: Int(taille * 2),
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB,
                                  bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = cible

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let dessin = configure.size
    let echelle = min(cible.width / dessin.width, cible.height / dessin.height) * 0.9
    let taillefinale = NSSize(width: dessin.width * echelle, height: dessin.height * echelle)
    let cadre = NSRect(x: (cible.width - taillefinale.width) / 2,
                       y: (cible.height - taillefinale.height) / 2,
                       width: taillefinale.width, height: taillefinale.height)
    configure.draw(in: cadre)
    couleur(hexa).set()
    cadre.fill(using: .sourceAtop)
    NSGraphicsContext.restoreGraphicsState()

    let fichier = dossier.appendingPathComponent(nom.replacingOccurrences(of: ".", with: "-") + ".png")
    try? bitmap.representation(using: .png, properties: [:])?.write(to: fichier)
}

print("Rendus : \(symboles.count - manquants.count)/\(symboles.count)")
if !manquants.isEmpty { print("Introuvables : \(manquants.joined(separator: ", "))") }
