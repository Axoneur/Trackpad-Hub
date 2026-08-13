# TrackPad Hub — état du projet

Document de reprise. À lire en entier avant de toucher au code : il contient
surtout les **pièges déjà rencontrés**, dont plusieurs ont coûté des heures.

Dernière mise à jour : 12 août 2026.

---

## 1. Ce que c'est

Une app qui transforme un iPhone en trackpad pour un Mac, pensée comme un
vrai trackpad et non comme une souris émulée. Projet Xcode généré par
XcodeGen, ~60 fichiers Swift, entièrement en français (code, commentaires,
interface).

**Quatre cibles :**

| Cible | Rôle | Plateforme |
|---|---|---|
| `MacHost` | Hôte : reçoit les ordres, les rejoue en `CGEvent` | macOS 14+ |
| `iOSApp` | Contrôleur : trackpad, clavier, média, apps | iOS 18+ |
| `KeyboardExt` | Clavier système iOS, processus séparé | iOS 18+ |
| `Widgets` | Widgets d'écran d'accueil | iOS 18+ |

**Dossiers de code partagé :**

- `Shared/` — compilé dans les **quatre** cibles. Rien de spécifique à une
  plateforme ici : pas d'`AppIntents`, pas d'`UIKit`.
- `SharediOS/` — compilé dans `iOSApp` et `Widgets` seulement.

---

## 2. Environnement de cette machine

> Les valeurs propres à un compte — équipe de signature, préfixe d'identifiant
> — vivent dans `trackpadhub.conf`, qui n'est pas versionné. Elles ne
> figurent volontairement pas ici : ce document est publiable.

| | Valeur |
|---|---|
| Mac | MacBook Air, macOS 26.6, disposition clavier **French (AZERTY)** |
| Xcode | 26.x, SDK iOS 26.5 / macOS 26.5 |
| Équipe de signature | dans `trackpadhub.conf` (compte Apple gratuit) |
| Second compte Apple | présent sur ce Mac, **quota d'App IDs épuisé** — ne pas l'utiliser |
| Homebrew | **absent** |
| XcodeGen | compilé depuis les sources → `~/.local/bin/xcodegen` |
| iPhone de test | identifiant lu par `xcrun devicectl list devices` |

### Piège XcodeGen

XcodeGen a besoin de son dossier `SettingPresets/` **à côté du binaire**.
Sans lui il génère un projet sans `PRODUCT_NAME` ni `SDKROOT`, et la
compilation échoue sur `module name "" is not a valid identifier`.
Il est installé dans `~/.local/bin/SettingPresets/`.

**Après toute modification de `project.yml` ou ajout de fichier :**
`~/.local/bin/xcodegen generate`

### Piège : un clic a une durée

L'enfoncement et le relâchement partaient dans la même milliseconde. Le
WindowServer fusionne les événements arrivés ensemble — **le même piège que
les 12 ms entre frappes clavier**, déjà payé une fois dans ce projet.

Le clic gauche y survivait, le clic droit non : le menu contextuel s'ouvre sur
l'enfoncement et se referme aussitôt sur un relâchement jugé simultané. D'où
60 ms entre les deux, côté iPhone (`TrackpadView.click`).

**Non vérifié en exécution** : poster un `CGEvent` exige l'Accessibilité, que
le shell d'un agent n'a pas. Diagnostic fondé sur le précédent mesuré du
clavier, pas sur une reproduction.

### Piège : une réponse sans destinataire se perd

`router.reply` envoyait **sans préciser le pair**. Avec plusieurs transports,
la réponse part alors sur le premier de la liste de priorité — pas forcément
celui d'où venait la demande. Câble branché, les réponses tombaient dans un
tunnel USB dont plus personne n'écoutait l'autre bout : **liste des apps,
presse-papiers et carte média disparaissaient tous les trois**.

Même famille que le bug du routage de l'appairage : dès qu'il y a plusieurs
tuyaux, **un message adressé doit partir sur le tuyau de son destinataire**.
La priorité ne vaut que pour les messages sans destinataire.

### Piège : un crochet sur le chemin critique coûte cher

L'enregistrement des macros créait une `Task { @MainActor }` par message
envoyé — déplacements du curseur compris, jusqu'à 120 par seconde. L'acteur
principal de l'iPhone saturait, l'app se figeait, la liaison tombait.

Tout crochet branché sur `MessageConnection.onSend` doit **sortir en deux
tests** quand il n'a rien à faire, sans rien allouer.

### Piège majeur : `NSLog` n'atteint pas le journal

**Mesuré le 13 août 2026** : sur 653 lignes émises par l'app en une minute,
**aucune** ne provenait de nos `NSLog`. Le message est écrit, mais `log show`
ne le restitue pas depuis une app groupée.

Ce silence a coûté plusieurs conclusions fausses : « l'iPhone n'envoie rien »
alors que la trace censée le prouver n'existait pas, et une fonctionnalité
crue morte alors qu'elle tournait.

**Utiliser `MacHost/Trace.swift`** (`os.Logger`, sous-système
`com.trackpadhub.machost`), jamais `NSLog` :

```
/usr/bin/log stream --predicate 'subsystem == "com.trackpadhub.machost"' --info
```

### Piège : un processus court échappe à `ps`

Échantillonner `ps` une fois par seconde pour vérifier qu'un sous-processus est
lancé ne prouve rien : un `osascript` vit quelques millisecondes et sera raté
neuf fois sur dix. Conclure « il n'est jamais lancé » sur cette base est une
erreur — commise le 13 août. Tracer, ne pas échantillonner.

### Diagnostic à distance : une seule commande

Depuis le 12 août, **chaque message reçu est tracé dans le journal système**,
pas seulement dans le panneau de diagnostic — celui-ci exige d'être devant le
Mac.

```
/usr/bin/log stream --predicate 'subsystem == "com.trackpadhub.machost"' --info
```

Elle tranche en dix secondes entre « l'iPhone n'envoie rien » et « le Mac ne
sait pas l'exécuter ». Plusieurs allers-retours sur le clic auraient été
évités en l'ayant plus tôt : la trace n'existait que pour `MouseController`,
donc le clic fort — qui passe par `SystemController` — ne laissait aucune
trace, et son silence a été pris pour une absence d'envoi.

### Piège : chercher les *nouvelles* connexions ne dit rien de l'état

`grep "Handling inbound connection"` ne montre que les connexions qui
**s'établissent** pendant la fenêtre d'observation. Une liaison déjà en place
n'apparaît nulle part — et l'absence de lignes a été prise pour une panne
d'appairage alors que l'app affichait « Connecté ».

Pour l'état réel : `lsof -nP -p <pid>` sur l'app Mac, ou simplement regarder
l'iPhone. Le journal sert à voir ce qui **change**, pas ce qui **est**.

### Piège : lancer l'app iPhone à distance ne prouve rien

`xcrun devicectl device process launch` répond « Launched application » même
quand l'app ne démarre pas vraiment — et `devicectl device info processes` ne
liste pas les apps signées en développement, **même quand elles tournent et
communiquent**. Les deux commandes réunies donnent donc une image fausse.

Une heure a été perdue à chercher un plantage de lancement inexistant. Le seul
signal fiable est ce que le Mac reçoit :

```
/usr/bin/log stream --predicate 'process == "MacHost"' --info | grep "inbound connection"
```

Deux lignes — une `tcp`, une `udp` — signifient que tout marche.

**Et l'iPhone verrouillé refuse tout net** :
`FBSOpenApplicationServiceErrorDomain error 1`. C'est la cause des lancements
qui « aboutissent » sans rien produire. Pour tester à distance : réinstaller
puis lancer dans la foulée, sinon prendre le téléphone en main.

### Piège : les `Info.plist` sont générés

`xcodegen generate` **réécrit** `MacHost/Info.plist`, `iOSApp/Info.plist` et
les autres à partir des blocs `info: properties:` de `project.yml`. Toute clé
ajoutée directement dans un `Info.plist` disparaît à la génération suivante,
silencieusement. Modifier `project.yml`, jamais le plist.

---

## 3. Installation

`./reinstall.sh` fait tout. Ne pas compiler à la main.

| Commande | Effet |
|---|---|
| `./reinstall.sh --mac` | app macOS seule, dans `/Applications`, relancée |
| `./reinstall.sh` | app iPhone seule |
| `./reinstall.sh --all` | les deux |
| `./reinstall.sh --lite` | iPhone sans clavier ni widgets |
| `./reinstall.sh --install` | planifie une réinstallation tous les 6 jours |

### Piège majeur : vérifier que l'app a vraiment redémarré

Le script affiche `App macOS installée et relancée (PID X, l'ancien était Y)`.
**Si les deux PID sont identiques, l'ancienne version tourne encore.**

Ce bug a fait tester du code périmé pendant plusieurs sessions : le `pkill`
cherchait `MacHost.app` alors que le chemin réel est
`TrackPad Hub.app/Contents/MacOS/MacHost`. Corrigé, mais rester vigilant.

Corollaire : **toujours vérifier la date de compilation** dans le panneau de
diagnostic avant de conclure qu'un correctif ne marche pas.

### Autre piège du script

`set -e` + `pgrep` qui ne trouve rien = script mort sans message. Tout appel
à `pgrep` doit être suivi de `|| true`.

---

## 4. Architecture

### Trois transports, une priorité

| Transport | Quand | Latence | État |
|---|---|---|---|
| **USB** (`USBLink`) | câble branché, app iPhone au premier plan | 1–2 ms, constante | tunnel vérifié |
| **Wi-Fi** (`DirectLink`) | réseau commun | 2–5 ms, variable | validé de bout en bout |
| **Bluetooth** (`BluetoothLink`) | ni câble ni Wi-Fi | 15–30 ms | validé par l'utilisateur |

L'ordre d'envoi est fixé dans `MessageConnection.transmit` : câble, puis
Wi-Fi, puis Bluetooth. Les trois portent **le même protocole, le même
appairage et le même chiffrement** — seul le tuyau change. Un câble ne donne
aucun droit de plus : brancher un iPhone inconnu ne le rend pas maître du Mac.

### Liaison filaire — `Shared/USBLink.swift` (13 août 2026)

Aucune API publique ne permet de parler en USB à un iPhone depuis une app Mac.
Mais macOS fait tourner **`usbmuxd`**, le démon qu'utilise Xcode : on lui parle
par sa socket Unix `/var/run/usbmuxd`, et il tunnelise une connexion TCP vers
un port ouvert sur l'iPhone.

D'où des rôles **inverses de tous les autres transports** : l'iPhone écoute
(port 24680), le Mac se connecte à travers `usbmuxd`.

**Trois pièges, tous rencontrés :**

1. **`PortNumber` se donne en gros-boutiste**, seul champ du protocole à faire
   exception — tout le reste est en petit-boutiste. En petit-boutiste on vise
   un port inexistant et `usbmuxd` répond « refusé » sans expliquer pourquoi.
2. **Accès chevauchant sur `sockaddr_un.sun_path`** : lire
   `MemoryLayout.size(ofValue: address.sun_path)` pendant qu'on écrit dedans
   est refusé par Swift. Le typecheck ne le voit pas, seule la compilation
   complète le signale.
3. **iOS suspend les apps en arrière-plan** : l'écouteur ne répond que si
   TrackPad Hub est au premier plan. La liaison filaire ne survit pas au
   verrouillage de l'écran.

**Vérifié sur ce Mac, à chaque étape** : `ListDevices` voit l'iPhone branché
(DeviceID 46, `ConnectionType: USB`) ; `Connect` sur un port fermé répond 3
(refusé) ; une fois l'app iPhone lancée, `Connect` sur 24680 répond **0** —
le tunnel s'ouvre et l'écouteur iOS accepte.

Une seule connexion à la fois : une nouvelle remplace la précédente.

### Chiffrement — `Shared/SessionCipher.swift`

Sorti de `DirectLink` le 12 août 2026 pour que le Bluetooth s'en serve aussi :
sans ce partage, brancher un second transport aurait fait circuler les frappes
clavier **en clair sur les ondes**.

Porte la dérivation de clé (HKDF, salée par le défi), le scellement AES-GCM et
les compteurs anti-rejeu par canal. Six canaux : TCP, UDP et BLE, dans les deux
sens. Les séparer n'est pas cosmétique — deux compteurs indépendants
repartant de zéro produiraient deux fois le même nonce avec la même clé, ce qui
casse GCM.

**Remaniement validé par le banc** : 10 essais sur 10 après extraction, comme
avant. C'est précisément ce pour quoi le banc avait été écrit.

### Transport — `Shared/DirectLink.swift` (12 août 2026)

**MultipeerConnectivity a été retiré.** Liaison directe en Network.framework,
sur deux canaux entre les mêmes pairs :

| Canal | Sert à | Pourquoi |
|---|---|---|
| **UDP** | déplacement, défilement, zoom | ce sont des deltas : un paquet perdu est remplacé par le suivant 2 ms plus tard, attendre une retransmission coûterait plus cher |
| **TCP** | clics, touches, appairage, apps, presse-papiers, fichiers | un clic perdu ne se devine pas |

L'iPhone décidait déjà `reliable: message.kind == .click` — la sémantique
existante s'est branchée telle quelle sur les deux canaux.

**Le Mac annonce, l'iPhone cherche** — l'inverse d'avant. Service Bonjour
`_trackpadhub._tcp` ; le port UDP voyage sur le canal TCP après appairage,
inutile de l'annoncer à la cantonade. `includePeerToPeer = true` conserve la
capacité « à proximité » qu'offrait MPC via AWDL.

**Chiffrement.** MPC chiffrait la session ; ne rien mettre à la place aurait
fait circuler les frappes clavier et le presse-papiers en clair sur le Wi-Fi.
Une fois l'appairage réussi, les deux bouts dérivent une clé du **jeton** déjà
partagé (HKDF-SHA256) et scellent chaque trame en AES-GCM. Les messages
d'appairage restent en clair : sûrs par construction, seule une preuve HMAC
circule. Le nonce porte un **compteur croissant par direction et par canal**,
ce qui interdit le rejeu — et impose que l'accord d'appairage parte *avant*
que la clé ne prenne effet, sinon l'iPhone ne pourrait pas l'ouvrir.

**Vérifié sur banc** (`DirectLink` + un `main.swift`) : découverte, aller-retour
en clair, passage au chiffré, canal rapide UDP, réassemblage d'un message de
150 Ko, transfert d'un fichier de 200 Ko avec progression, reconnexion après
coupure. 10 essais, 0 échec.

**Vérifié avec l'iPhone réel** le 12 août 2026, deux fois (21:41 et 21:56) :

```
21:56:31.728  connexion entrante tcp   [C4]
21:56:31.925  connexion entrante udp   [C5]
```

196 ms entre les deux. Le canal UDP n'est ouvert que par `announceFastPath`,
appelée uniquement depuis `secure()`, elle-même appelée uniquement depuis
`grant()` après vérification de la preuve HMAC. **Son existence prouve donc
toute la chaîne** : découverte Bonjour, connexion TCP sur Wi-Fi réel,
appairage silencieux au jeton conservé, dérivation de la clé de session,
ouverture du chemin rapide et acceptation du ticket.

Ce qui reste à éprouver demande un doigt sur l'écran : curseur, clavier,
fenêtres, onglets, transfert de fichier.

**Trois bugs trouvés à la relecture et corrigés** (12 août 2026) :

1. **L'iPhone ne se reconnectait jamais** après une coupure.
   `browseResultsChangedHandler` ne se déclenche qu'au *changement* de la
   liste Bonjour. Si la liaison tombe pendant que le Mac continue d'annoncer,
   la liste ne bouge pas, aucun rappel n'arrive. Il fallait quitter l'app.
   Corrigé par une boucle de reconnexion (`scheduleReconnect`).
   **Attention au faux négatif** : un essai qui fait `stop()` puis `start()`
   passe même sans le correctif, parce qu'il recrée le navigateur. Il faut
   couper la liaison **en laissant le navigateur vivant** — d'où
   `severForTesting()`. Vérifié dans les deux sens : l'essai échoue sans le
   correctif, passe avec.
2. **Rejeu possible d'une session à l'autre.** La clé ne dépendait que du
   jeton, donc identique à chaque connexion, alors que les compteurs
   anti-rejeu repartent de zéro. La clé est désormais salée par le **défi
   d'appairage**, différent à chaque fois.
3. **Longueur de trame non bornée.** Une trame corrompue ou forgée annonçant
   4 Go faisait grossir le tampon sans fin. Plafond à 8 Mo, liaison coupée
   au-delà.

Deux pièges rencontrés en chemin :

- un banc d'essai sur le même Mac tombe sur **l'app réelle**, qui annonce le
  même service. D'où le paramètre `serviceType` de `DirectLink`, à surcharger
  dans les essais ;
- `sendFile` occupait la file du transport pendant tout le transfert, ce qui
  aurait figé le curseur. Les tranches repassent par elle juste le temps
  d'être scellées et émises.

### Protocole

`Shared/Message.swift` — une struct plate `Codable` avec un `kind: String` et
des champs optionnels. Dispatch par `switch` dans `MacHost/Router.swift`.

`Shared/FastPacket.swift` — **encodage binaire de 11 octets** pour les
messages fréquents (déplacement, défilement, zoom, clic). Le reste reste en
JSON. Un JSON commence par `{` (0x7B), la marque binaire vaut 0x01 : aucune
confusion possible. Mesuré : 3× plus petit, 33× plus rapide à encoder.

### Sécurité

Établir la connexion réseau ne donne **aucun droit**. Tant qu'un pair n'a pas
prouvé qu'il connaît le secret, ses messages de contrôle sont jetés.

1. Le Mac envoie un défi aléatoire à chaque connexion.
2. L'iPhone répond `HMAC-SHA256(secret, défi)`. Le secret ne circule jamais.
3. Premier appairage : le secret est le code à 6 chiffres affiché sur le Mac.
4. Ensuite : jeton permanent dans le trousseau des deux côtés.
5. 5 échecs bloquent l'appareil.

**Le code est global au Mac**, pas rattaché à un pair : il est affiché à la
demande (bouton « Ajouter un appareil ») et valable 5 minutes pour n'importe
quel appareil. Un code par pair ne s'affichait qu'après une tentative de
connexion, ce qui le rendait imprévisible.

**L'iPhone conserve le code saisi** et le rejoue sur chaque nouveau défi
jusqu'à réussite. Sans ça, un défi renouvelé entre le scan et l'envoi faisait
échouer l'appairage sans explication.

### Stockage

`Shared/KeychainBox.swift` → trousseau, service `com.trackpadhub.shared`.

**Pas d'App Group** : cette capacité exige un compte Apple payant. Le partage
app ↔ clavier ↔ widgets passe par un groupe de trousseau, disponible sur
compte gratuit — vérifié, le profil accorde `TEAMID.*`.

**Liste de révocation** dans `UserDefaults` : sur macOS, un élément du
trousseau appartient à la signature de l'app qui l'a créé, et une app
recompilée peut ne plus pouvoir l'effacer. « Oublier » inscrit donc
l'appareil dans une liste séparée, qui fait foi.

---

## 5. Le piège central : keycodes et disposition clavier

**Un keycode macOS désigne une touche physique, pas une lettre.** La touche 0
produit `a` en QWERTY US et `q` en AZERTY français.

Conséquence : une table figée transformait ⌘A (tout sélectionner) en ⌘Q
(quitter l'app). Mesuré sur ce Mac :

```
table ANSI figée : « a » → touche 0, qui produit « q »   ⚠
disposition réelle : « a » → touche 12                    ok
```

**L'iPhone envoie donc des caractères**, jamais des keycodes. Le Mac les
traduit via `UCKeyTranslate` (`MacHost/Services/KeyboardLayout.swift`) contre
la disposition **active**. Seules les touches nommées — entrée, tabulation,
flèches — voyagent en keycode, leur position ne changeant pas.

Corollaire : un raccourci est **toujours** résolu contre la disposition
active, jamais contre celle forcée dans les réglages. Sinon le keycode est
réinterprété différemment et le raccourci part ailleurs.

---

## 6. Frappes clavier synthétiques

`MacHost/Services/KeyboardController.swift`

- Les modificateurs sont postés comme de **vrais événements `flagsChanged`**,
  pas seulement en drapeau sur l'événement.
- **12 ms de pause** entre chaque événement, sur une file dédiée. Sans elles,
  les raccourcis système ne se déclenchent pas.
- Les caractères introuvables sont injectés en Unicode via
  `keyboardSetUnicodeString` — plus de détour par le presse-papiers.

### Piège : Carbon exige la file principale (corrigé le 12 août 2026)

Les API de source de saisie — `TISCopyCurrentKeyboardLayoutInputSource`,
`TISCreateInputSourceList`, `TISGetInputSourceProperty` — passent par
`islGetInputSourceListWithAdditions`, qui appelle `dispatch_assert_queue`.
Depuis une file secondaire, elles ne renvoient pas d'erreur : **elles tuent le
processus** sur `EXC_BREAKPOINT`. Deux rapports identiques :

```
_dispatch_assert_queue_fail
HIToolbox  TSMGetInputSourceProperty
KeyboardLayout.currentSourceID()
KeyboardController.postTap(keycode:flags:)   ← sur keyQueue
```

`postTap` tourne sur `keyQueue` et y résolvait la disposition à chaque frappe.
Même famille que le piège `NSAppleScript` (section 7) : une API système qui
exige la file principale, appelée depuis une file d'arrière-plan.

**Correctif** : `KeyboardController` garde un **instantané** des dispositions
(active + figée), construit sur la file principale au démarrage et rafraîchi
en observant `kTISNotifySelectedKeyboardInputSourceChanged`
(= `com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged`, en
`DistributedNotificationCenter`). Le chemin critique ne fait plus qu'une
lecture sous `NSLock` — donc **plus rapide** qu'avant, où chaque frappe
interrogeait Carbon.

Ne **pas** corriger par un `DispatchQueue.main.sync` depuis `keyQueue` :
latence sur le chemin le plus critique, et risque d'interblocage.

**Attention, l'assertion est intermittente** : elle ne se déclenche que quand
HIToolbox doit revalider sa liste de sources. Deux sondes (binaire simple, puis
vraie `NSApplication`) ont lu la disposition depuis une file secondaire **sans
planter**. Ne pas en conclure que le code est sain — se fier à la règle, pas à
un essai isolé.

### Ce qui passe et ce qui ne passe pas

| Action | Voie | Autorisation |
|---|---|---|
| Curseur, clics, défilement, frappes | CGEvent | Accessibilité |
| Spotlight ⌘Espace | CGEvent | Accessibilité |
| Mission Control | ouverture de `/System/Applications/Mission Control.app` | **aucune** |
| Bureaux ⌃← ⌃→, App Exposé ⌃↓, Bureau F11 | **System Events** | Automatisation |
| Veille | `pmset sleepnow` | aucune |
| Redémarrer, éteindre, déconnexion | System Events | Automatisation |

**Fait vérifié** : le WindowServer filtre les raccourcis de bureaux quand ils
viennent d'une app tierce, alors qu'il laisse passer ⌘Espace. Testé avec
6 bureaux configurés et raccourcis actifs : la frappe part, rien ne se passe.
Ne pas retenter CGEvent pour ces quatre-là.

`Mission Control.app` est dans `/System/Applications/`, **pas** dans
`/System/Library/CoreServices/`. Une erreur de recherche a fait croire
qu'Apple l'avait supprimée dans macOS 26.

---

## 7. Autorisations macOS

Deux autorisations distinctes, souvent confondues :

**Accessibilité** — indispensable, tout en dépend. Demandée automatiquement
au lancement. Liée à l'**emplacement du bundle** : déplacer l'app de Xcode
vers `/Applications` remet l'autorisation à zéro.

**Automatisation** — seulement pour bureaux, App Exposé, redémarrage,
extinction. Demandée au lancement de l'app.

### Piège n°1 : hardened runtime bloque la demande elle-même

**Mesuré le 12 août 2026, journal de `tccd` :**

```
Prompting policy for hardened runtime; service: kTCCServiceAppleEvents
requires entitlement com.apple.security.automation.apple-events
but it is missing
```

`ENABLE_HARDENED_RUNTIME: YES` (project.yml, nécessaire à la notarisation)
impose `com.apple.security.automation.apple-events` dans les entitlements.
Sans lui, TCC ne refuse pas l'événement Apple : **il refuse de poser la
question**. Aucune fenêtre, aucun effet, et l'app jamais listée dans les
Réglages Système — les trois symptômes en même temps.

Le code AppleScript était correct depuis le début. Chercher du côté de
`NSAppleScript` et de la file principale a coûté plusieurs sessions.

**Méthode qui a tranché** — dix secondes de journal, plutôt qu'une hypothèse :

```
/usr/bin/log stream --predicate 'process == "tccd"' --info > t.log &
open -n "/Applications/TrackPad Hub.app"
grep -i trackpadhub t.log
```

Après correction, la même mesure montre la ligne attendue :
`Publishing <TCCDEvent: type=Create, service=kTCCServiceAppleEvents,
identifier=com.trackpadhub.machost>`.

Note : `log` est masqué par une fonction du profil zsh de cette machine —
appeler `/usr/bin/log` en chemin absolu.

### Autres pièges

- Une app **n'apparaît dans ces listes qu'après avoir demandé** l'autorisation
  au moins une fois. La liste Automatisation n'a **pas de bouton +**.
- `NSAppleScript` **exige la file principale**. Lancé en arrière-plan, il
  échoue sans erreur, sans effet, et sans jamais déclencher de demande.
  C'est ce qui a rendu l'app invisible dans les Réglages Système.
- Un refus enregistré empêche toute nouvelle demande. Pour l'effacer :
  `tccutil reset AppleEvents com.trackpadhub.machost`

---

## 8. Compte Apple gratuit

| Limite | Valeur |
|---|---|
| App IDs | 10 par période glissante de 7 jours — 4 cibles = 4 App IDs, coût unique |
| Validité de signature | 7 jours, d'où `./reinstall.sh --install` |
| App Groups | **indisponibles** |
| Keychain Sharing | **disponible** (vérifié : le profil accorde `TEAMID.*`) |

Ne jamais renommer les bundle identifiers : ce sont de nouveaux App IDs.

---

## 9. Fonctionnalités en place

**Trackpad** — curseur avec accélération quadratique (jusqu'à 6×, mémorisée
0,25 s entre deux gestes), clics, défilement à phases natives avec inertie,
pincer-zoomer, glisser-déposer, appui-glisser. Gestes 3 doigts (Mission
Control, App Exposé, bureaux) et 4 doigts (bureau, recherche). Rotation à
2 doigts → ⌘L/⌘R, double appui 2 doigts → ⌘0.

**Clavier** — disposition iPhone exacte (azertyuiop / qsdfghjklm / ⇧wxcvbn⌫ /
123 ⇥ espace ↵), AZERTY/QWERTY/QWERTZ, touches F1-F12, navigation, dictée
vocale française sur l'appareil, presse-papiers partagé.

**Notes rapides** (12 août 2026) — un texte tapé sur l'iPhone arrive sur le
Mac en notification, **et** dans son presse-papiers : on envoie presque
toujours une note pour la coller quelque part.

Remplace le « chat intégré » demandé, qui supposait un serveur et des comptes.
Le besoin réel derrière — s'envoyer à soi-même une adresse, un code, une idée —
n'a besoin de rien de tout ça : la liaison existe déjà. En mémoire seulement,
comme l'historique du presse-papiers.

**Concentration et sous-titres en direct** (12 août 2026) — même mécanique
pour les deux, parce qu'ils butent sur le même mur : **aucune API publique**.
Pas d'AppleScript, pas de domaine `defaults` — vérifié,
`com.apple.LiveTranscriptionAgent` n'existe même pas.

`shortcuts run` est la seule voie supportée, avec un raccourci créé par
l'utilisateur :

| Action | Raccourci attendu | Action Raccourcis |
|---|---|---|
| Concentration | `TrackPad Hub Focus` | « Régler le mode de concentration » |
| Sous-titres | `TrackPad Hub Sous-titres` | activer les sous-titres en direct |

Quand le raccourci manque, l'app ne reste pas muette : elle ouvre le volet des
Réglages concerné quand il en existe un (Accessibilité pour les sous-titres) et
explique quoi créer.

Les sous-titres passent donc par **ceux de macOS** plutôt que par une capture
du son maison, qui aurait exigé un pilote audio virtuel.

**Surface MIDI** (12 août 2026) — le Mac se présente comme un appareil MIDI
nommé « TrackPad Hub ». Quatre curseurs et huit pads sur l'iPhone.

**C'est l'alternative à trois fonctionnalités qu'on croyait bloquées** : mode
DJ, égaliseur audio, palettes et roulettes. Toutes butaient sur le même mur —
capter ou traiter le son du système exige un pilote audio virtuel, donc un
projet séparé avec son installeur. Le MIDI contourne le mur : Serato, Traktor,
Ableton, Logic, Final Cut et la plupart des plugins d'égalisation savent
**apprendre** un contrôleur. Aucun son ne transite, donc aucun pilote.

`MIDISourceCreateWithProtocol` est publique et n'exige aucune autorisation.
Vérifié par une boucle source→port d'écoute : les deux mots UMP émis
(`0x20b00764` = CC 7 valeur 100, `0x20903c7f` = note 60 vélocité 127)
arrivent intacts. Vérifié aussi sur l'app installée : la source apparaît dans
la liste des appareils MIDI du système.

**Maintenir le clic** (13 août 2026) — troisième bouton sous le trackpad. Le
bouton gauche reste enfoncé jusqu'au prochain appui.

**C'est ce qui manquait pour déplacer une fenêtre ou la redimensionner.** Ces
deux gestes exigent de garder le bouton enfoncé pendant qu'on déplace le
curseur ; aucun appui bref ne le permet, et ni l'appui-glisser ni le glisser à
trois doigts n'y suffisent puisqu'ils relâchent dès que le doigt se lève.

Le bouton s'entoure de couleur tant que le clic est maintenu — sans ce repère,
on oublie que le bouton est enfoncé et tout ce qu'on touche devient un
glissement. Relâché automatiquement en quittant l'écran ou à la perte de
liaison : le Mac ne reste jamais bloqué.

### Le détour par le « clic fort », et pourquoi il n'a rien donné

Quatre tours ont été perdus à traiter « le clic ne fonctionne pas » comme un
problème de **pression**, alors que c'était un problème de **maintien**.

Au passage, un fait mesuré et définitif : un vrai clic fort n'est pas
synthétisable. Le champ `mouseEventPressure` d'un `CGEvent` est réglable, mais
`NSEvent.otherEvent(with: .pressure, …)` lève une exception — AppKit refuse de
*fabriquer* l'événement. Ne pas y revenir.

`GestureAction.forceClick` a été retiré ; `.lookUp` (⌃⌘D) couvre déjà l'effet
visible du clic fort, sur l'appui long à un doigt.

**Leçon** : « ça ne marche pas » décrit un symptôme, pas une cause. Demander
ce que l'utilisateur *voulait faire* — ici déplacer une fenêtre — aurait mené
au maintien du clic dès le premier tour.

**Historique du presse-papiers** (12 août 2026) — les 30 derniers textes
copiés sur le Mac, consultables depuis l'iPhone, avec deux destinations
distinctes : « Sur le Mac » remet l'entrée dans le presse-papiers du Mac,
« Copier » la met dans celui de l'iPhone.

**En mémoire seulement, volontairement** : un presse-papiers contient
régulièrement des mots de passe et des jetons. Les écrire sur disque leur
donnerait une durée de vie que personne n'a demandée. L'historique disparaît
avec l'app Mac.

**Mode Focus** (12 août 2026) — dans la grille Navigation.

macOS n'expose **aucune API publique** pour changer de mode de concentration :
ni AppleScript, ni `defaults`, qui ne fonctionne plus depuis des années. La
seule voie supportée est `shortcuts run`, donc un raccourci que l'utilisateur
doit créer lui-même :

> App Raccourcis → nouveau raccourci nommé exactement
> **`TrackPad Hub Focus`** → action « Régler le mode de concentration ».

Sans lui, `shortcuts run` sort en code 1 avec « Raccourci introuvable »
(vérifié) et l'app affiche la marche à suivre au lieu de rester muette.

**Onglets du navigateur** (12 août 2026) — liste des onglets du navigateur au
premier plan, aller à un onglet, le fermer, onglet suivant/précédent, nouvel
onglet, rouvrir le dernier fermé. Safari et la famille Chrome (Chrome, Brave,
Edge), qui ne parlent pas le même dialecte AppleScript. Firefox est exclu : il
n'expose pas ses onglets.

Exige l'autorisation **Automatisation**, accordée séparément pour chaque
application ciblée — macOS redemandera pour Safari, puis pour Chrome.

Piège : AppleScript renvoie les listes séparées par des virgules, or un titre
de page en contient presque toujours. On impose le séparateur d'unité ASCII
(0x1F). Scripts validés à l'`osascript` avant d'être figés dans le code.

**Fenêtres** (12 août 2026) — placement de la fenêtre active à la manière de
Magnet : moitiés, quarts, tiers, deux tiers, plein écran, centrer, **réduire**,
rétablir, plein écran natif, écran suivant.

« Réduire » et « plein écran natif » passent par les attributs
d'accessibilité `AXMinimized` et `AXFullScreen`, et non par ⌘M : un raccourci
clavier frappe la fenêtre active de l'app active, alors qu'on vise celle qu'on
vient de désigner. `AXFullScreen` n'a **pas de constante publique** dans le
SDK — chaîne littérale isolée dans une constante nommée. Via l'API Accessibilité, déjà autorisée : aucune autorisation
supplémentaire. Grille dans l'onglet « Mac » de l'iPhone, repliée par défaut
sur les huit emplacements courants.

Deux pièges :

- **Les repères sont inversés.** AppKit place l'origine en bas à gauche, Y
  vers le haut ; l'API Accessibilité en haut à gauche, Y vers le bas. La
  confusion ne lève aucune erreur — la fenêtre part simplement dans le mauvais
  sens, d'autant plus loin qu'elle était basse. Conversion isolée dans
  `axRect(fromAppKit:)` / `appKitRect(fromAX:)`, aller-retour vérifié.
- **`WindowPlacement` est déjà pris par SwiftUI** (macOS seulement). Notre
  énumération s'appelle donc `WindowSlot` : sous l'ancien nom, la compilation
  iOS échouait sur un « unavailable in iOS » incompréhensible.

Le calcul du cadre est une **fonction pure** (`WindowController.frame`),
éprouvée par un banc de 16 essais — pavage exact des moitiés et des quarts,
bornage d'une fenêtre plus grande que l'écran, neutralité de la conversion de
repère. Le déplacement réel n'a pas pu être testé sans l'iPhone.

**Mac** — apps ouvertes et installées (100 détectées ici, via balayage +
LaunchServices), lancer/masquer/suspendre (SIGSTOP)/quitter, constantes
système (batterie, CPU, mémoire, disque), alimentation, transfert de fichiers
iPhone → Mac, raccourcis personnalisés.

**Média** — lecture, volume par curseur (CoreAudio), luminosité, mode
présentation avec minuteur vibrant.

**Mode jeu, statistiques, iPad** (13 août 2026).

Le mode jeu est un **écran plein**, sans barre de navigation ni défilement :
manche à gauche, losange de quatre boutons à droite, L1/L2 et R1/R2 en haut,
engrenage au centre pour les touches. Une manette se tient à deux mains sans
regarder ; des boutons posés dans une page qui défile obligent à viser, et un
glissement du pouce fait défiler la page au lieu de déplacer le personnage.

Le manche borne son **rayon**, pas chaque axe — borner les axes séparément
laisserait les diagonales sortir du disque. Zone morte au tiers de la course.
Les boutons utilisent `DragGesture(minimumDistance: 0)` et non `Button` :
un bouton n'agit qu'au relâchement, ce qui interdit de maintenir une direction.

Le mode jeu envoie des **touches maintenues** (`Message.Kind.keyHold` →
`KeyboardController.hold`), et non des frappes : avancer suppose de garder la
touche enfoncée. Un vrai gamepad exigerait un pilote HID virtuel installé sur
le Mac — projet séparé. Les jeux Mac lisent presque tous le clavier, ce qui
rend cette voie suffisante et sans installation.

Les statistiques comptent sur `MessageConnection.onSend`, **le chemin
critique**. D'où `OSAllocatedUnfairLock` et de simples incréments d'entiers :
aucune allocation, aucun saut de file. Le crochet des macros est **chaîné**, pas
écrasé — deux consommateurs sur le même point.

`TARGETED_DEVICE_FAMILY: "1,2"` suffit pour l'iPad : l'interface est déjà
adaptative, elle s'élargit en paysage.

**Détection média à deux niveaux** (13 août 2026) — la page ouverte, **et** ce
qui est réellement lu, Picture in Picture compris.

Le second niveau balaie **toutes les fenêtres et tous les onglets** à la
recherche d'une balise `video`/`audio` non en pause, et en tire titre, URL,
position et durée. Balayer tous les onglets plutôt que le seul premier plan
est exactement ce qui rattrape le Picture in Picture : la vidéo continue
d'appartenir à son onglet même quand on regarde ailleurs. Un seul `osascript`
fait toute la boucle.

**Condition** : Safari refuse `do JavaScript` tant que « Autoriser JavaScript
depuis les Apple Events » n'est pas coché (Réglages > Avancé > fonctionnalités
pour développeurs web, puis menu Développement). Mesuré. Sans ce réglage seul
le niveau 1 fonctionne, et la carte de l'iPhone explique quoi cocher.

**Capteurs et accessibilité** (13 août 2026) — défilement par inclinaison
(`TiltScroll`), mode poche (`PocketMode`), fort contraste, mode une main.

L'inclinaison prend sa **position de repos à l'activation**, pas une verticale
absolue : un téléphone se tient rarement droit. Zone morte d'environ 7° pour
absorber le tremblement de la main, progression au carré au-delà.

Le mode poche filtre **dans `TrackpadView.send`**, le seul chemin qu'empruntent
les gestes de la surface — pas geste par geste. Il relâche aussi un clic
maintenu : sinon le Mac resterait bloqué en glissement pendant que l'iPhone est
dans la poche.

Piège : `colorSchemeContrast` est **en lecture seule**, on ne peut pas
l'imposer. Le fort contraste passe donc par `legibilityWeight`, qui est
réglable.

**Macros** (13 août 2026) — enregistrer une séquence d'actions et la rejouer
d'un appui, pauses d'origine comprises.

**L'enregistrement n'instrumente pas l'interface.** Il capte
`MessageConnection.onSend`, le seul point par lequel passent toutes les
actions envoyées au Mac. Une fonctionnalité ajoutée demain devient donc
enregistrable sans qu'on y pense — c'est ce qui évite d'avoir à toucher trente
boutons.

Ce qui est exclu : déplacement, défilement, zoom. Ces trois-là dépendent de
l'endroit exact où se trouvait le curseur ; les rejouer produirait un
gribouillage, pas une automatisation. Restent les actions discrètes : touches,
clics, raccourcis, commandes système, fenêtres, onglets.

Les délais sont conservés — ouvrir Spotlight puis taper aussitôt perd les
premières lettres — mais **plafonnés à cinq secondes** : une interruption
pendant l'enregistrement ne doit pas figer la macro.

**Reprise de lecture** (13 août 2026, corrigée le même jour) — ce qui joue sur
le Mac est proposé sur l'iPhone : une carte « Continuer sur l'iPhone » apparaît dans l'onglet Média
dès qu'il y a quelque chose à reprendre, et disparaît sinon.

**MediaRemote ne sert pas ici, et c'est mesuré.**
`MRMediaRemoteGetNowPlayingInfo` existe toujours mais **ne rappelle plus** les
apps tierces — Apple l'a restreint aux siennes. Et même s'il répondait, il ne
donnerait que des métadonnées : reprendre une lecture demande un **lien**, pas
un titre.

Trois sources, dans cet ordre — un lecteur qui joue l'emporte sur un onglet
qui traîne :

| Source | Ce qu'on obtient | Reprise |
|---|---|---|
| Spotify | URI de piste + position | à la seconde près |
| Music | titre + artiste + position | recherche dans Musique |
| Navigateur | URL + titre de l'onglet actif | le lien tel quel, `&t=` ajouté sur YouTube |

Option « mettre le Mac en pause » activée par défaut : sans elle le son
sortirait des deux appareils à la fois.

**Bug corrigé le 13 août** : la proposition n'arrivait jamais. Le Mac ne
poussait qu'aux *changements* — un média déjà en cours depuis dix minutes ne
produit aucun événement — et l'iPhone ne demandait jamais l'état. Les deux
bouts s'attendaient. Désormais le Mac envoie l'état dès qu'un appareil est
autorisé, et l'iPhone le redemande en ouvrant l'écran Média.

**Piège évité de justesse** : `NSAppleScript` exige la file principale *et*
bloque en attendant la réponse de l'app interrogée. Un sondage périodique y
aurait figé, à chaque tour, la file qui traite aussi l'appairage. Le sondage
passe donc par `osascript` dans un **processus séparé**, sur une file de
service. Ne pas revenir à `NSAppleScript` ici.

**Divers** — appairage QR + code, Wake on LAN, raccourcis Siri, widgets,
barre des menus macOS, centre d'aide (12 tutoriels), thèmes clair/sombre.

**Icône** — bundle Icon Composer `AppIcon.icon` fourni par l'utilisateur,
avec variantes carrées (iPhone/iPad/Mac) et rondes (watchOS).

**Apparence macOS — Liquid Glass** (12 août 2026). Compiler avec le SDK 26 ne
suffit pas : macOS n'habille automatiquement que le **chrome standard** —
barre d'outils, barre latérale, inspecteur, feuilles, contrôles. L'interface
était une pile de `VStack` séparés par des `Divider`, donc sans chrome : il
n'y avait rien à habiller, d'où l'impression d'app restée en macOS 14.

Ce qui a été fait, dans `MacHost/GlassStyle.swift` et ses deux appelants :

- contenu regroupé en **cartes de verre** (`.glassCard()`) dans un
  `GlassEffectContainer` — c'est lui qui fait fusionner les reflets des cartes
  voisines ; sans conteneur le rendu reste plat ;
- **fond de fenêtre translucide** (`.containerBackground(.thinMaterial, for:
  .window)`) — sans lui le verre ne réfracte rien et vire au gris ;
- boutons en `.buttonStyle(.glass)` / `.glassProminent`, un seul proéminent
  par écran ;
- diagnostic passé du pied de fenêtre à la **barre d'outils**, et du `HStack`
  à un **`.inspector`** : le conteneur prévu par macOS, verre compris ;
- les `Divider` ont disparu — entre deux panneaux translucides, un trait
  ajoute du bruit sans rien délimiter.

La cible de déploiement reste **macOS 14** : chaque effet est encadré par un
`if #available`, avec repli en matériau classique. Deux pièges de version
vérifiés au compilateur, pas de mémoire :
`ContainerBackgroundPlacement.window` est **macOS 15+** (et non 14 comme
`containerBackground` lui-même) ; `.glassEffect` et `GlassEffectContainer`
sont **macOS 26+**.


### Maintenance : expiration et mises à jour (13 août 2026)

Trois fichiers, un seul but : que l'utilisateur n'ait pas à surveiller une date.

| Fichier | Rôle |
|---|---|
| `Shared/SigningExpiry.swift` | Lit l'expiration dans le profil **embarqué** (iPhone) |
| `MacHost/Services/SigningWatch.swift` | Lit les profils du dossier d'Xcode (Mac), relance horaire |
| `Shared/ReleaseChecker.swift` | Consulte les publications GitHub, une fois par jour |
| `MacHost/Services/MaintenanceNotifier.swift` | Notifie sur le Mac, par paliers |
| `iOSApp/ExpiryNotice.swift` | Programme les notifications iPhone **à l'avance** |

**Paliers plutôt que rappel quotidien.** `[3, 1, 0]` jours, chacun annoncé une
seule fois (mémorisé dans les préférences). Une notification répétée chaque
jour est coupée par l'utilisateur au bout de trois jours, et l'avertissement
utile qui suit n'est alors jamais lu.

**Pourquoi l'iPhone programme à l'avance.** Expirée, l'app ne s'ouvre plus :
au moment où l'avertissement compte, elle n'est plus là pour l'émettre. Les
trois notifications sont donc déposées dès le lancement, et reprogrammées à
chaque fois — une réinstallation repousse la date, les anciennes deviendraient
fausses.

#### Piège : `first(where:)` bloquait l'escalade

`paliers.first(where: { jours <= $0 })` renvoie **3** pour toute valeur
inférieure à 3. Une fois le palier 3 mémorisé, « expire demain » et « expiré »
n'auraient **jamais** été émis. Vérifié sur banc :

```
jours | first(where:) | last(where:)
  3   |      3        |      3
  1   |      3        |      1        ← le bon palier
  0   |      3        |      0
```

`last` sur une liste décroissante donne l'escalade attendue.

#### Piège : rien n'était branché

`SigningWatch.actualiser()` et `ReleaseChecker.verifier()` n'étaient appelés
**nulle part**. `grep` sur tout le projet : un seul résultat, la déclaration
elle-même. Ni la bannière d'expiration, ni celle de mise à jour ne pouvaient
donc apparaître — la fonctionnalité entière était inatteignable alors que le
code semblait complet. Branchés dans `ContentView.onAppear`.

Rappel de méthode : un `@StateObject` créé ne prouve rien ; seul un appel
prouve qu'il tourne.

#### Piège : les notifications étaient refusées, en silence

Mesuré depuis l'app :

```
UNErrorDomain Code=1 "Notifications are not allowed for this application"
autorisation notifications · refusé par l'utilisateur
```

Après un refus, `requestAuthorization` **ne redemande jamais** : elle échoue
immédiatement, sans alerte. Le seul recours est Réglages Système. L'app
affiche donc une carte « Notifications désactivées » avec un bouton vers les
Réglages — sans elle, l'app restait muette et l'utilisateur découvrait
l'expiration en constatant que rien ne s'ouvre.

Ce diagnostic n'a été possible qu'après avoir **journalisé l'erreur** au lieu
de la jeter : « refusé » seul ne distingue pas un refus utilisateur d'un
bundle mal enregistré, et les deux se corrigent différemment.

#### Piège : `reinstall.sh` annonçait 7 jours à tort

Le script disait « profils renouvelés pour 7 jours » quelle que soit la
réalité. Mesuré : après réinstallation, le profil expirait toujours le même
jour — Apple ne délivre un profil neuf que lorsque l'ancien approche de sa
fin, sinon Xcode réutilise l'existant. Le script lit maintenant la date réelle
dans le profil embarqué et l'affiche, en heure locale (`date -j -u` à la
lecture : la date du profil est en UTC, sans `-u` elle était décalée de deux
heures).

#### Ce qui n'a pas pu être vérifié

Le dépôt effectif des notifications **sur l'iPhone** n'est pas mesuré :
`log collect --device` exige root et `log stream --device` n'existe plus sur
macOS 26. Sont vérifiés en revanche la compilation, la lecture du profil
embarqué du bundle installé, et les trois dates calculées — toutes futures et
correctement espacées. `iOSApp/TraceiOS.swift` journalise le dépôt pour qui
peut lire le journal de l'appareil.

---

## 10. Ce qui reste ouvert

**Réglé le 12 août 2026** : l'autorisation Automatisation ne pouvait pas être
demandée — entitlement `com.apple.security.automation.apple-events` manquant
sous hardened runtime. Voir section 7. Reste à confirmer que cocher
« System Events » débloque bien les gestes de bureaux et App Exposé.

**À confirmer avec l'iPhone, en priorité** : la liaison directe TCP + UDP
(section 4) remplace MultipeerConnectivity depuis le 12 août 2026. Elle est
vérifiée de bout en bout entre deux instances sur le Mac, mais **jamais avec
un vrai iPhone** : appairage, curseur, clavier et transfert de fichier sont à
reprendre une fois l'app iPhone réinstallée.

**À confirmer avec l'iPhone** : le plantage clavier corrigé le 12 août 2026
(section 6) ne se reproduit plus. Le correctif n'a **pas** pu être vérifié de
bout en bout — l'assertion HIToolbox est intermittente et ne se reproduit pas
à la demande. Envoyer des frappes depuis l'iPhone est le seul vrai test.

**Non fait, demandé** :

- Choix Wi-Fi / Bluetooth : toujours pas d'API publique pour l'imposer.
  `includePeerToPeer` laisse le système décider. Le Bluetooth serait de toute
  façon plus lent.
- Choix du Mac quand plusieurs annoncent le service : `DirectLink` prend le
  premier trouvé. Sans importance avec un seul Mac, à traiter le jour où il y
  en aura deux.
- Cible watchOS (l'icône la couvre déjà).
- Compatibilité iPad.
- Le lot « Productivité Mac » est **terminé** : fenêtres, onglets, mode Focus,
  historique du presse-papiers.
- Reste de la liste fournie par l'utilisateur : macros, palettes, timeline,
  mode DJ, notifications macOS, tilt-to-scroll, mode poche, USB filaire,
  statistiques, mode gaming, accessibilité (une main, fort contraste),
  recherche globale, mode précision, gestes personnalisés, clavier
  contextuel, pavé numérique, compatibilité iPad, Bluetooth LE.

**Alternatives trouvées aux fonctionnalités bloquées** (12 août 2026) :

| Bloqué | Alternative | État |
|---|---|---|
| Égaliseur audio, mode DJ, palettes, roulettes | **MIDI virtuel** — les logiciels apprennent le contrôleur, aucun son ne transite | **fait** |
| Tablette graphique (le Pencil n'existe pas sur iPhone) | **Mode tablette absolu** : l'écran iPhone mappé sur l'écran Mac, pression déduite du rayon du toucher (`UITouch.majorRadius`, disponible sur tous les iPhone) | à faire |
| Sous-titres en temps réel | Activer les **sous-titres en direct de macOS** au lieu de recapturer le son | **fait** |
| Chat intégré (exigeait un serveur) | Notes rapides iPhone → Mac par la liaison existante, sans serveur | **fait** |
| Bluetooth LE | CoreBluetooth en secours : l'iPhone annonce, le Mac cherche, découpage en morceaux de 180 o | **fait, validé par l'utilisateur** |
| USB filaire | `usbmuxd`, la technique de Xcode | **fait** | à faire |

**Reste abandonné** : trackpad en AR (démonstration plus qu'outil), et la
pression Apple Pencil telle quelle, qui suppose la cible iPad.

**Déconseillé** : chat intégré (exige un serveur), trackpad en AR
(démonstration plus qu'outil).

---

## 11. Diagnostic intégré

Fenêtre macOS → bouton **« Diagnostic clavier »** dans la **barre d'outils**
(il était en bas à gauche avant le passage à Liquid Glass). Le panneau s'ouvre
en **inspecteur**, à droite, dans la même fenêtre. Il affiche :

- la **date de compilation du binaire en cours** — à vérifier en premier ;
- la disposition active et celle utilisée pour traduire ;
- l'état de l'automatisation, avec l'erreur exacte ;
- les **messages reçus de l'iPhone** — permet de trancher entre « l'iPhone
  n'envoie rien » et « le Mac ne sait pas exécuter » ;
- les **dernières frappes émises**, avec le caractère réellement produit.

Ce panneau a résolu plusieurs impasses. L'utiliser avant toute hypothèse.

---

## 12. Méthode

Les erreurs de cette session ont presque toutes la même origine : **conclure
sans mesurer**. Les correctifs qui ont tenu sont ceux appuyés sur une
vérification réelle sur cette machine — disposition clavier lue par Carbon,
raccourcis système lus dans les préférences, nombre de bureaux, contenu du
trousseau, PID avant/après installation.

Écrire un petit binaire Swift de test dans le scratchpad et le lancer coûte
deux minutes et évite des tours entiers de fausses pistes.
