import Foundation
import Vision
import AppKit

/// Repère un texte dans une image et renvoie sa zone, au format attendu par
/// `flouter` : `x,y,largeur,hauteur` en pixels, origine en haut à gauche.
///
/// Écrit pour masquer un nom d'appareil sur des captures avant publication.
/// Repérer à l'œil sur treize images, c'est treize occasions d'en oublier une
/// ou de se tromper de dix pixels ; Vision le fait sans se lasser.
///
/// Usage : reperer image.png "texte à trouver" [marge]

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else {
    print("Usage : reperer image.png \"texte\" [marge]")
    exit(1)
}

let url = URL(fileURLWithPath: arguments[0])
let recherche = arguments[1].lowercased()
let marge = arguments.count > 2 ? (Double(arguments[2]) ?? 8) : 8

guard let image = NSImage(contentsOf: url),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Image illisible")
    exit(1)
}

let largeur = Double(cg.width), hauteur = Double(cg.height)

let requete = VNRecognizeTextRequest()
requete.recognitionLevel = .accurate
// Les captures sont en français ; l'indiquer améliore nettement la
// reconnaissance des accents et des mots collés.
requete.recognitionLanguages = ["fr-FR", "en-US"]
requete.usesLanguageCorrection = false

let handler = VNImageRequestHandler(cgImage: cg, options: [:])
do { try handler.perform([requete]) } catch {
    print("Reconnaissance impossible : \(error.localizedDescription)")
    exit(1)
}

var zones: [String] = []
for observation in requete.results ?? [] {
    guard let candidat = observation.topCandidates(1).first else { continue }
    guard candidat.string.lowercased().contains(recherche) else { continue }

    // Vision renvoie des coordonnées normalisées, origine en bas à gauche.
    let b = observation.boundingBox
    let x = b.minX * largeur - marge
    let y = (1 - b.maxY) * hauteur - marge
    let l = b.width * largeur + marge * 2
    let h = b.height * hauteur + marge * 2
    zones.append(String(format: "%.0f,%.0f,%.0f,%.0f",
                        max(0, x), max(0, y), l, h))
}

if zones.isEmpty {
    print("ABSENT")
} else {
    print(zones.joined(separator: " "))
}
