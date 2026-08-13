import Foundation

/// Contenu du QR code affiché par le Mac pendant un appairage.
///
/// Le QR ne fait que transporter le même code à 6 chiffres que celui affiché
/// à l'écran : il évite la saisie, il ne remplace pas la vérification. Le
/// secret ne circule toujours pas sur le réseau — l'iPhone s'en sert
/// uniquement pour calculer sa preuve HMAC.
struct PairingPayload: Codable {

    /// Version du format, pour rester compatible si le contenu évolue.
    var version = 1
    /// Nom du Mac, affiché à l'utilisateur après le scan.
    var host: String
    /// Code d'appairage à 6 chiffres.
    var pin: String

    private static let scheme = "trackpadhub"

    /// Encodé en URL plutôt qu'en JSON brut : un QR contenant une URL reste
    /// lisible par l'appareil photo du système, qui proposera d'ouvrir l'app.
    var url: String {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = "pair"
        components.queryItems = [
            URLQueryItem(name: "v", value: String(version)),
            URLQueryItem(name: "host", value: host),
            URLQueryItem(name: "pin", value: pin)
        ]
        return components.url?.absoluteString ?? ""
    }

    init(host: String, pin: String) {
        self.host = host
        self.pin = pin
    }

    /// Relit un QR scanné. Renvoie nil si ce n'est pas un QR TrackPad Hub.
    init?(scanned text: String) {
        guard let components = URLComponents(string: text),
              components.scheme == Self.scheme,
              components.host == "pair",
              let items = components.queryItems else { return nil }

        let values = Dictionary(items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        }, uniquingKeysWith: { first, _ in first })

        guard let pin = values["pin"],
              pin.count == 6,
              pin.allSatisfy(\.isNumber) else { return nil }

        self.version = Int(values["v"] ?? "1") ?? 1
        self.host = values["host"] ?? "Mac"
        self.pin = pin
    }
}
