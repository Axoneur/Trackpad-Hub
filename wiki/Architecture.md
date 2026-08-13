# Architecture

Pour qui veut lire ou modifier le code.

## Les quatre cibles

| Cible | Rôle | Plateforme |
|---|---|---|
| `MacHost` | Hôte : reçoit les ordres, les rejoue en `CGEvent` | macOS 14+ |
| `iOSApp` | Contrôleur : trackpad, clavier, média, apps | iOS 18+ |
| `KeyboardExt` | Clavier système iOS, processus séparé | iOS 18+ |
| `Widgets` | Widgets d'écran d'accueil | iOS 18+ |

**Dossiers partagés.** `Shared/` est compilé dans les **quatre** cibles : rien
de spécifique à une plateforme n'y est admis, ni `AppIntents`, ni `UIKit`.
`SharediOS/` ne sert qu'à `iOSApp` et `Widgets`.

## Le transport

```
Shared/
├── MessageConnection.swift   Appairage, filtrage, choix du transport
├── DirectLink.swift          Wi-Fi : TCP (fiable) + UDP (chemin chaud)
├── BluetoothLink.swift       Secours BLE
├── USBLink.swift             Liaison filaire, via usbmuxd
└── SessionCipher.swift       AES-GCM, clé dérivée du jeton, anti-rejeu
```

**Un message adressé part sur le transport de son destinataire.** L'ordre de
priorité (câble, Wi-Fi, Bluetooth) ne vaut que pour les messages sans
destinataire. Envoyer un défi d'appairage destiné à un pair Wi-Fi sur le câble,
au motif qu'il est plus rapide, laisse la poignée de main sans réponse.

## Le protocole

`Shared/Message.swift` : une struct plate `Codable` avec un `kind: String` et
des champs optionnels. Dispatch par `switch` dans `MacHost/Router.swift`.

`Shared/FastPacket.swift` : **encodage binaire de 11 octets** pour les messages
fréquents : déplacement, défilement, zoom, clic. Le reste reste en JSON. Un
JSON commence par `{` (0x7B), la marque binaire vaut 0x01 : aucune confusion
possible. Mesuré 3× plus petit et 33× plus rapide à encoder.

## Le projet Xcode est généré

`project.yml` est la source de vérité ; le `.xcodeproj` n'est **pas** versionné.

```bash
~/.local/bin/xcodegen generate     # après tout ajout de fichier
```

L'équipe de signature et le préfixe d'identifiant viennent de
`trackpadhub.conf`, écrit par `./setup.sh`. XcodeGen substitue les variables
d'environnement.

> Les `Info.plist` sont **générés** depuis les blocs `info: properties:` de
> `project.yml`. Une clé ajoutée directement dans un plist disparaît à la
> génération suivante, silencieusement.

## Diagnostic

Chaque message reçu est tracé dans le journal système :

```bash
/usr/bin/log stream --predicate 'subsystem == "com.trackpadhub.machost"' --info
```

> `NSLog` **n'atteint pas** le journal unifié depuis une app groupée : sur 653
> lignes émises en une minute, aucune n'en provenait. Utiliser `MacHost/Trace.swift`,
> qui passe par `os.Logger` avec un sous-système explicite.

L'app macOS a aussi un **panneau de diagnostic** intégré, bouton stéthoscope
en haut à droite. Il affiche la date de compilation du binaire en cours, la
disposition clavier active, les messages reçus et les frappes réellement émises.

## Contribuer

Le dépôt est sous **GPL-3.0** : les versions modifiées que vous distribuez
doivent rester ouvertes, sources comprises.

Avant d'ouvrir une contribution, lisez `ETAT-DU-PROJET.md` à la racine : il
recense les pièges déjà rencontrés, dont plusieurs ont coûté des heures.
