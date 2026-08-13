import Foundation
import CoreImage
import AppKit

/// Floute une ou plusieurs zones rectangulaires d'une image.
///
/// Sert à masquer un nom d'appareil ou un code d'appairage sur une capture
/// avant publication. Écrit sur place, ou vers un fichier de sortie.
///
/// Usage :
///   flouter entrée.png [sortie.png] x,y,l,h [x,y,l,h …]
///
/// Les coordonnées sont en **pixels de l'image**, origine en haut à gauche —
/// la convention de tous les outils de capture. CoreImage travaille avec
/// l'origine en bas à gauche : la conversion est faite ici, une fois, plutôt
/// que dans la tête de celui qui note les coordonnées.
///
/// Le flou est appliqué à l'image entière puis **recomposé** uniquement sur
/// les zones voulues. Flouter une zone découpée ferait apparaître un liseré
/// net sur ses bords, parce que le flou n'aurait rien à lire au-delà.

struct Zone {
    let x: Double, y: Double, width: Double, height: Double

    init?(_ texte: String) {
        let parts = texte.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        x = parts[0]; y = parts[1]; width = parts[2]; height = parts[3]
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else {
    print("Usage : flouter entrée.png [sortie.png] x,y,l,h [x,y,l,h …]")
    exit(1)
}

let entree = URL(fileURLWithPath: arguments[0])
// Le second argument est une sortie s'il ne ressemble pas à une zone.
let aUneSortie = Zone(arguments[1]) == nil
let sortie = aUneSortie ? URL(fileURLWithPath: arguments[1]) : entree
let zones = arguments.dropFirst(aUneSortie ? 2 : 1).compactMap(Zone.init)

guard !zones.isEmpty else {
    print("Aucune zone valide. Format attendu : x,y,largeur,hauteur")
    exit(1)
}

guard let source = CIImage(contentsOf: entree) else {
    print("Image illisible : \(entree.path)")
    exit(1)
}

let cadre = source.extent

// Rayon proportionnel à la taille de l'image : un flou de 20 px suffit sur une
// capture d'iPhone et laisse le texte lisible sur une capture de Mac en 2×.
let rayon = max(cadre.width, cadre.height) / 45

let flou = source
    .clampedToExtent()
    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: rayon])
    .cropped(to: cadre)

var resultat = source
for zone in zones {
    // Origine en haut à gauche → origine en bas à gauche.
    let rect = CGRect(x: zone.x,
                      y: cadre.height - zone.y - zone.height,
                      width: zone.width,
                      height: zone.height)
    let morceau = flou.cropped(to: rect)
    resultat = morceau.composited(over: resultat)
}

let contexte = CIContext()
guard let espace = CGColorSpace(name: CGColorSpace.sRGB),
      let donnees = contexte.pngRepresentation(of: resultat,
                                               format: .RGBA8,
                                               colorSpace: espace) else {
    print("Encodage PNG impossible")
    exit(1)
}

do {
    try donnees.write(to: sortie)
    print("Flouté : \(sortie.lastPathComponent) — \(zones.count) zone(s), rayon \(Int(rayon)) px")
} catch {
    print("Écriture impossible : \(error.localizedDescription)")
    exit(1)
}
