<div align="center">

<img src="docs/banniere.svg" alt="TrackPad Hub" width="100%">

**Votre iPhone devient le trackpad de votre Mac.**
Pas une souris émulée : accélération, inertie, gestes à plusieurs doigts, clavier, fenêtres, média.

[![Plateformes](https://img.shields.io/badge/macOS-14%2B-0A84FF?style=flat-square&logo=apple&logoColor=white)](#)
[![iOS](https://img.shields.io/badge/iOS-18%2B-0A84FF?style=flat-square&logo=apple&logoColor=white)](#)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-FA7343?style=flat-square&logo=swift&logoColor=white)](#)
[![Licence](https://img.shields.io/badge/licence-GPL--3.0-3DA639?style=flat-square)](LICENSE)
[![Transports](https://img.shields.io/badge/transports-USB%20%C2%B7%20Wi--Fi%20%C2%B7%20Bluetooth-8B5CF6?style=flat-square)](#trois-transports-le-plus-rapide-gagne)

</div>

---

## Ce que ça fait

<table>
<tr>
<td width="50%" valign="top">

### 🖱️ Un vrai trackpad
Curseur à accélération, défilement à inertie, pincer-zoomer.
Gestes à 2, 3 et 4 doigts : Mission Control, bureaux, App Exposé.
Clic maintenu pour déplacer et redimensionner une fenêtre.

### ⌨️ Clavier complet
Disposition AZERTY, QWERTY, QWERTZ. Touches F1–F12, navigation,
dictée vocale, presse-papiers partagé.
**Un keycode désigne une touche physique, pas une lettre** — le Mac
traduit contre sa disposition active, donc ⌘A ne devient jamais ⌘Q.

### 🪟 Fenêtres et onglets
Moitiés, quarts, tiers, plein écran, réduire, écran suivant.
Onglets Safari et Chrome : naviguer, fermer, rouvrir.

</td>
<td width="50%" valign="top">

### 🎵 Média et reprise de lecture
Lecture, volume, luminosité, mode présentation.
Ce qui joue sur le Mac est **proposé sur l'iPhone** — page ouverte
ou vidéo en cours, Picture in Picture compris.

### 🎛️ Surface MIDI
Le Mac se présente comme un contrôleur MIDI. Serato, Traktor,
Ableton, Logic et les plugins d'égalisation l'apprennent en un clic.

### 🎮 Et aussi
Manette plein écran · Macros enregistrables · Historique du
presse-papiers · Notes rapides · Statistiques d'usage ·
Défilement par inclinaison · Mode poche

</td>
</tr>
</table>

---

## Trois transports, le plus rapide gagne

| | Quand | Latence |
|---|---|---|
| 🔌 **USB** | câble branché | **1–2 ms**, constante |
| 📶 **Wi-Fi** | réseau commun | 2–5 ms |
| 🔵 **Bluetooth** | ni l'un ni l'autre | 15–30 ms |

Le choix est automatique et les trois portent **le même appairage et le même
chiffrement**. Un câble ne donne aucun droit de plus : brancher un iPhone
inconnu ne le rend pas maître du Mac.

<details>
<summary><b>Comment la sécurité fonctionne</b></summary>

<br>

Établir la connexion ne donne **aucun droit**. Tant qu'un appareil n'a pas
prouvé qu'il connaît le secret, ses messages de contrôle sont jetés.

1. Le Mac envoie un défi aléatoire à chaque connexion.
2. L'iPhone répond `HMAC-SHA256(secret, défi)`. **Le secret ne circule jamais.**
3. Premier appairage : le secret est le code à 6 chiffres affiché sur le Mac.
4. Ensuite : un jeton permanent, gardé dans le trousseau des deux côtés.
5. Cinq échecs bloquent l'appareil.

Une fois appairé, chaque trame est scellée en **AES-GCM** avec une clé dérivée
du jeton et salée par le défi de la connexion — elle change donc à chaque fois.
Un compteur croissant par canal interdit le rejeu.

</details>

---

## Aperçu

<div align="center">

<img src="docs/captures/mac-fenetre.png" width="86%" alt="La fenêtre macOS : appairage, autorisations, et le panneau de diagnostic à droite">

<br><br>

<table>
<tr>
<td align="center" width="25%"><img src="docs/captures/iphone-trackpad.png" width="100%" alt="Surface tactile"><br><sub><b>Trackpad</b><br>1 doigt : curseur · 2 : défilement · 3 : gestes</sub></td>
<td align="center" width="25%"><img src="docs/captures/iphone-mac-constantes.png" width="100%" alt="Constantes du Mac et placement des fenêtres"><br><sub><b>Mac</b><br>Constantes, apps, placement des fenêtres</sub></td>
<td align="center" width="25%"><img src="docs/captures/iphone-media-reprise.png" width="100%" alt="Reprise de lecture"><br><sub><b>Reprise de lecture</b><br>Ce qui joue sur le Mac, repris sur l'iPhone</sub></td>
<td align="center" width="25%"><img src="docs/captures/iphone-clavier-texte.png" width="100%" alt="Clavier et presse-papiers partagé"><br><sub><b>Clavier</b><br>Texte, dictée, presse-papiers partagé</sub></td>
</tr>
</table>

<details>
<summary><b>Voir plus d'écrans</b></summary>

<br>

<table>
<tr>
<td align="center" width="25%"><img src="docs/captures/iphone-mac-outils.png" width="100%"><br><sub>Onglets, presse-papiers, MIDI, notes, macros, mode jeu</sub></td>
<td align="center" width="25%"><img src="docs/captures/iphone-mac-fenetres.png" width="100%"><br><sub>Moitiés, quarts, plein écran, réduire</sub></td>
<td align="center" width="25%"><img src="docs/captures/iphone-clavier-touches.png" width="100%"><br><sub>Modificateurs, F1–F12, navigation</sub></td>
<td align="center" width="25%"><img src="docs/captures/iphone-media-presentation.png" width="100%"><br><sub>Volume, luminosité, mode présentation</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/captures/iphone-clavier-azerty.png" width="100%"><br><sub>Disposition AZERTY exacte</sub></td>
<td align="center"><img src="docs/captures/iphone-mac-statistiques.png" width="100%"><br><sub>Statistiques d'usage</sub></td>
<td align="center"><img src="docs/captures/iphone-reglages.png" width="100%"><br><sub>Réglages et appairage</sub></td>
<td align="center"><img src="docs/captures/iphone-mac-suite.png" width="100%"><br><sub>Alimentation et concentration</sub></td>
</tr>
</table>

</details>

</div>

---

## Fonctionnalités

### Ajouté en août 2026

- **Trois transports** — câble USB (1–2 ms), Wi-Fi (2–5 ms), Bluetooth LE en
  secours. Même appairage et même chiffrement sur les trois ; le plus rapide
  disponible est choisi automatiquement.
- **Macros** — enregistrer une séquence d'actions et la rejouer, pauses
  comprises.
- **Gestion des fenêtres** — moitiés, quarts, tiers, plein écran, réduire,
  écran suivant.
- **Maintenir le clic** — bouton dédié, pour déplacer ou redimensionner une
  fenêtre en glissant.
- **Onglets du navigateur** — lister, changer, fermer, rouvrir (Safari et
  famille Chrome).
- **Historique du presse-papiers** — les 30 derniers textes copiés sur le Mac,
  en mémoire seulement.
- **Reprise de lecture** — ce qui joue sur le Mac, proposé sur l'iPhone.
- **Surface MIDI** — le Mac se présente comme un contrôleur ; Serato, Traktor,
  Ableton, Logic et les plugins d'égalisation l'apprennent.
- **Notes rapides** — un texte de l'iPhone arrive en notification sur le Mac.
- **Concentration et sous-titres** — via l'app Raccourcis.
- **Défilement par inclinaison** — le doigt reste libre, zone morte de 7°.
- **Mode poche** — le capteur de proximité coupe les entrées quand l'iPhone
  est rangé.
- **Accessibilité** — fort contraste, mode une main.
- **Animation des touches** — la touche s'enfonce sous le doigt.
- **Macros** — enregistrer une séquence d'actions, la rejouer.
- **Mode jeu** — joystick et boutons tactiles, en touches maintenues.
- **Statistiques d'usage** — temps connecté et gestes les plus utilisés, gardés
  sur l'iPhone.
- **iPad** — l'app s'installe aussi sur iPad.

| Sur l'iPhone | Effet sur le Mac |
|---|---|
| Trackpad multi-touch (1 doigt = curseur, 2 = défilement/zoom, 3 = glisser, appuis = clics) | Curseur, clics, scroll avec phases natives (CGEvent) |
| Souris gyroscopique : inclinaison de l'iPhone | Curseur piloté sans toucher l'écran (CoreMotion) |
| Clavier intégré (texte + raccourcis Cmd/Opt/Ctrl/Maj) | Vraies frappes clavier, adaptées à la disposition du Mac |
| Dictée vocale française, transcrite sur l'appareil | Texte saisi sur le Mac (Speech) |
| Extension de clavier système Full Access | Touches envoyées même en dehors de l'app |
| Lecture/pause, piste suivante/précédente, volume | MediaRemote (avec repli touches HID) + CoreAudio |
| Mode présentation avec minuteur vibrant | Flèches, écran noir/blanc (Keynote, PowerPoint, Slides) |
| Presse-papiers partagé bidirectionnel | Copie sur le Mac remontée automatiquement |
| Applications : lancer, afficher, masquer, suspendre, quitter | NSWorkspace + SIGSTOP/SIGCONT |
| Veille, verrouillage, redémarrage, extinction, déconnexion | System Events (AppleScript) + pmset |
| Bureau, Mission Control, Launchpad, Spotlight | Touches et services système |
| Constantes : batterie, processeur, mémoire, disque | IOKit + CoreAudio + mach |
| Raccourcis personnalisés (app, lien, Raccourci) | NSWorkspace + shortcuts:// |
| Réveil du Mac endormi | Paquet magique Wake on LAN |
| Raccourcis Siri et widgets d'écran d'accueil | Actions exécutées à l'ouverture de l'app |

## Architecture

Le **Mac est l'hôte** : il cherche les appareils (Bonjour `_trackpadhub._tcp`).
L'**iPhone** — et l'extension de clavier, qui tourne dans un processus séparé — annonce sa présence.

```
TrackPadHub/
├── project.yml                    # Définition XcodeGen (3 cibles)
├── generate.sh / notarize.sh      # Génération du projet, signature + notarisation
├── Shared/                        # Code commun aux 3 cibles
│   ├── Message.swift              # Protocole JSON (trackpad, char, media, appairage…)
│   ├── SpecialKey.swift           # Touches nommées → keycodes stables
│   ├── KeyboardStyle.swift        # Disposition AFFICHÉE sur l'iPhone
│   ├── Pairing.swift              # Code à 6 chiffres, défi/réponse HMAC-SHA256
│   ├── PairingStore.swift         # Jetons dans le trousseau (partagé app ↔ extension)
│   └── MessageConnection.swift    # MultipeerConnectivity + filtrage des non-appairés
├── MacHost/                       # App macOS (hôte)
│   ├── ContentView.swift          # Code d'appairage, appareils, autorisations, disposition
│   ├── Router.swift               # Dispatch des messages reçus
│   └── Services/
│       ├── MouseController.swift    # Curseur, clics, scroll à phases, zoom
│       ├── KeyboardLayout.swift     # Caractère → touche physique, via la vraie disposition
│       ├── KeyboardController.swift # Frappes + injection Unicode
│       ├── MediaController.swift    # MediaRemote / touches HID / CoreAudio
│       ├── ShortcutController.swift
│       └── AccessibilityManager.swift
├── iOSApp/                        # App iPhone (contrôleur)
│   └── Views/                     # Trackpad, clavier, média, raccourcis, réglages, appairage
└── KeyboardExt/                   # Extension de clavier système (Full Access)
```

### Pourquoi l'iPhone n'envoie pas de keycodes

Un keycode macOS désigne une **touche physique**, pas une lettre : la touche `0` produit
`a` en QWERTY US et `q` en AZERTY français. Une table figée transformerait donc ⌘A
(tout sélectionner) en ⌘Q (quitter l'app) sur un Mac français.

L'iPhone envoie donc des **caractères**, et le Mac les traduit via `UCKeyTranslate` d'après
la disposition réellement active (ou celle choisie dans l'app macOS). Seules les touches
nommées — entrée, tabulation, flèches… — voyagent sous forme de keycode, car leur position
ne change pas d'une disposition à l'autre.

## Sécurité

Établir la connexion réseau ne donne **aucun droit**. Tant que l'iPhone n'a pas prouvé
qu'il connaît le secret, tous ses messages de contrôle sont jetés côté Mac.

1. Le Mac envoie un défi aléatoire à chaque connexion.
2. L'iPhone répond avec `HMAC-SHA256(secret, défi)` — le secret ne circule jamais.
3. Au premier appairage, le secret est le **code à 6 chiffres affiché sur le Mac**.
4. Ensuite, le Mac délivre un jeton permanent stocké dans le trousseau des deux côtés :
   les connexions suivantes sont silencieuses.
5. 5 échecs bloquent l'appareil ; chaque échec renouvelle le défi (pas de rejeu).

L'app et l'extension de clavier partagent un groupe de trousseau : **l'extension n'a jamais
besoin de code**, elle hérite de l'appairage fait dans l'app.

Vous pouvez retirer un appareil à tout moment depuis l'app macOS (« Oublier »).

## Signature et compte Apple

Le projet contient **quatre cibles** — quatre programmes distincts, chacun devant
être signé séparément dans Xcode (*Signing & Capabilities* → *Automatically
manage signing* + votre équipe) :

| Cible | Rôle |
|---|---|
| `MacHost` | App macOS, l'hôte qui reçoit les commandes |
| `iOSApp` | App iPhone |
| `KeyboardExt` | Clavier système iOS |
| `Widgets` | Widgets d'écran d'accueil |

Un **compte Apple gratuit suffit**, et c'est vérifié : un compte personnel
obtient un groupe de trousseau joker (`TEAMID.*`), qui couvre le groupe
partagé du projet. Les trois cibles iOS sont donc signées avec le même
`keychain-access-groups`, et se partagent réellement l'appairage et les
constantes du Mac.

Le projet n'utilise volontairement **aucun App Group** : cette capacité-là est
bien réservée aux comptes payants, alors que le partage de trousseau ne l'est
pas.

> **Attention au quota d'App IDs.** Un compte gratuit ne peut créer que
> **10 App IDs par période glissante de 7 jours**, et chaque cible en consomme
> un. Les quatre cibles du projet coûtent donc 4 App IDs, une seule fois. Si
> vous voyez « Your maximum App ID limit has been reached », changez de compte
> Apple dans `DEVELOPMENT_TEAM` ou attendez que le quota se libère. Ne
> renommez pas les bundle identifiers pour contourner : cela consomme de
> nouveaux App IDs.

> Limite du compte gratuit : l'app cesse de se lancer au bout de 7 jours. Il
> suffit de la relancer depuis Xcode. Des outils comme AltStore ou SideStore
> réinstallent l'app automatiquement pour contourner cette limite — ils
> utilisent le même compte gratuit et ne débloquent aucune capacité
> supplémentaire.

## Prérequis

- Mac avec **Xcode 26+**, sous **macOS 26+**
- iPhone sous **iOS 26+**
- Les deux appareils sur le **même réseau Wi-Fi**
- Un compte Apple (gratuit ou payant — gratuit = 7 jours entre deux builds)
- **XcodeGen** *(optionnel)* : uniquement si vous modifiez `project.yml`.
  Le `.xcodeproj` versionné suffit sinon.

> **Piège XcodeGen** : si vous le compilez depuis les sources au lieu de passer
> par Homebrew, copiez aussi son dossier `SettingPresets/` à côté du binaire.
> Sans lui, XcodeGen génère un projet sans `PRODUCT_NAME` ni `SDKROOT`, et la
> compilation échoue sur `module name "" is not a valid identifier`.
>
> ```bash
> git clone --depth 1 --branch 2.43.0 https://github.com/yonaskolb/XcodeGen.git
> cd XcodeGen && swift build -c release --product xcodegen
> mkdir -p ~/.local/bin && cp .build/release/xcodegen ~/.local/bin/
> cp -R SettingPresets ~/.local/bin/
> ```

## Générer et lancer

```bash
./generate.sh
```

Ou directement, sans XcodeGen :

```bash
open TrackPadHub.xcodeproj
```

Dans Xcode :

1. Cible **iOSApp** → *Signing & Capabilities* → cochez **Automatically manage signing** et choisissez votre équipe.
2. Faites de même pour **MacHost** et pour l'extension **KeyboardExt**.
3. Lancez d'abord la cible **MacHost** sur votre Mac, puis **iOSApp** sur votre iPhone.

> Le trackpad a besoin d'un vrai écran tactile : testez sur l'appareil, pas sur le simulateur.

## Première configuration

### Sur le Mac (une fois)

1. Ouvrez **TrackPad Hub** (macOS).
2. Cliquez sur **« Accorder l'accès »** et autorisez l'**Accessibilité** :
   Réglages Système → Confidentialité et sécurité → Accessibilité → cochez TrackPad Hub.
   *(Obligatoire : permet de bouger le curseur et d'envoyer les touches. L'app détecte
   l'autorisation dès que vous la cochez, sans redémarrage.)*

### Sur l'iPhone (une fois)

1. Ouvrez **TrackPad Hub**, acceptez la demande d'accès au **réseau local**.
2. Un **code à 6 chiffres** s'affiche sur le Mac : saisissez-le sur l'iPhone.
3. L'écran Trackpad affiche « Connecté au Mac ».

### Clavier complet (extension) — optionnel

1. Réglages → Général → Clavier → **Claviers** → **Ajouter un clavier**.
2. Choisissez **« Clavier TrackPad Hub »**.
3. Touchez son nom, puis activez **« Autoriser l'accès complet »** (nécessaire pour le réseau).
4. Dans n'importe quel champ de saisie, basculez sur ce clavier (icône 🌐).

Aucun code à ressaisir : l'extension réutilise l'appairage de l'app.

## Gestes du trackpad

| Geste | Action |
|---|---|
| 1 doigt, bouger | Déplacer le curseur (avec accélération) |
| 1 doigt, appui bref | Clic gauche |
| 1 doigt, appui puis glisser | Glisser-déposer |
| 2 doigts, bouger | Défiler (avec inertie) |
| 2 doigts, écarter/rapprocher | Zoomer |
| 2 doigts, appui bref | Clic droit |
| 3 doigts, appui bref | Clic milieu |
| 3 doigts, bouger | Glisser-déposer |

Vitesses dans l'onglet **Trackpad** ; accélération, inertie, sens du défilement et
retour haptique dans **Réglages**.

## Dispositions de clavier

- **Sur l'iPhone** (Réglages → Clavier) : la disposition **affichée** sur les touches —
  AZERTY, QWERTY ou QWERTZ.
- **Sur le Mac** : la disposition utilisée pour **traduire** les caractères reçus.
  Par défaut elle suit le clavier actif du Mac ; vous pouvez la figer si besoin.

Les accents (`é`, `è`, `à`, `ç`, `ù`) partent comme de vraies frappes en AZERTY.
Les caractères introuvables sur la disposition sont injectés directement en Unicode —
sans jamais toucher au presse-papiers.

## Distribution hors App Store

L'app macOS ne peut pas être sandboxée (l'Accessibilité l'interdit), elle n'est donc
pas distribuable sur le Mac App Store. Pour la partager :

```bash
./notarize.sh "Developer ID Application: Votre Nom (TEAMID)"
```

Le script compile en Release, signe, vérifie le hardened runtime, notarise et agrafe le
ticket. Il faut un **compte Apple Developer payant**.

## Dépannage

| Problème | Solution |
|---|---|
| « Recherche du Mac… » | Vérifiez que l'app macOS est ouverte et les deux appareils sur le même Wi-Fi. |
| Le code d'appairage ne s'affiche pas | Le Mac ne l'affiche que pour un appareil inconnu. Utilisez « Oublier » pour forcer un nouvel appairage. |
| Le curseur ne bouge pas | Autorisation **Accessibilité** pas accordée (voir plus haut). |
| Le défilement part à l'envers | Réglages → Trackpad → **Défilement naturel**. |
| Mauvaises lettres / ⌘ inattendus | Réglez la disposition dans l'app macOS au lieu de « suivre le clavier actif ». |
| Le clavier n'envoie rien | Activez **Autoriser l'accès complet**, et appairez d'abord dans l'app. |
| Lecture/pause sans effet | MediaRemote est bloqué sur certaines versions de macOS ; le repli par touches HID prend le relais mais exige l'Accessibilité. |
| Message « 7 jours restants » | Compte gratuit : reconstruisez via Xcode pour renouveler. |
