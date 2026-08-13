<div align="center">

<img src="docs/banniere.svg" alt="TrackPad Hub" width="100%">

**Votre iPhone devient le trackpad de votre Mac.**

Pas une souris émulée : accélération, inertie, gestes à plusieurs doigts,
clavier complet, contrôle des fenêtres, du média et des applications.

[![macOS](https://img.shields.io/badge/macOS-14%2B-0A84FF?style=for-the-badge&logo=apple&logoColor=white)](#)
[![iOS](https://img.shields.io/badge/iOS-18%2B-0A84FF?style=for-the-badge&logo=apple&logoColor=white)](#)
[![Swift](https://img.shields.io/badge/SwiftUI-FA7343?style=for-the-badge&logo=swift&logoColor=white)](#)
[![GPL-3.0](https://img.shields.io/badge/GPL--3.0-3DA639?style=for-the-badge)](LICENSE)

</div>

---

## Aperçu

<div align="center">

<img src="docs/captures/mac-fenetre.png" width="88%" alt="La fenêtre macOS">

<sub>**Sur le Mac** — appairage, autorisations, et le panneau de diagnostic qui montre en direct ce que l'iPhone envoie.</sub>

<br><br>

<table>
<tr>
<td align="center" width="20%"><img src="docs/captures/iphone-trackpad.png" width="100%"></td>
<td align="center" width="20%"><img src="docs/captures/iphone-clavier-azerty.png" width="100%"></td>
<td align="center" width="20%"><img src="docs/captures/iphone-media-reprise.png" width="100%"></td>
<td align="center" width="20%"><img src="docs/captures/iphone-mac-constantes.png" width="100%"></td>
<td align="center" width="20%"><img src="docs/captures/iphone-reglages.png" width="100%"></td>
</tr>
<tr>
<td align="center"><b>Trackpad</b><br><sub>Curseur, gestes, clics</sub></td>
<td align="center"><b>Clavier</b><br><sub>Texte, raccourcis, dictée</sub></td>
<td align="center"><b>Média</b><br><sub>Lecture, volume, reprise</sub></td>
<td align="center"><b>Mac</b><br><sub>Fenêtres, apps, outils</sub></td>
<td align="center"><b>Réglages</b><br><sub>Appairage, capteurs</sub></td>
</tr>
</table>

<details>
<summary><b>Huit autres écrans</b></summary>

<br>

<table>
<tr>
<td align="center" width="25%"><img src="docs/captures/iphone-clavier-texte.png" width="100%"><br><sub>Champ de texte, dictée, presse-papiers</sub></td>
<td align="center" width="25%"><img src="docs/captures/iphone-clavier-touches.png" width="100%"><br><sub>Modificateurs, F1–F12, navigation</sub></td>
<td align="center" width="25%"><img src="docs/captures/iphone-media-presentation.png" width="100%"><br><sub>Volume, luminosité, présentation</sub></td>
<td align="center" width="25%"><img src="docs/captures/iphone-mac-fenetres.png" width="100%"><br><sub>Placement des fenêtres</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/captures/iphone-mac-outils.png" width="100%"><br><sub>Onglets, MIDI, macros, mode jeu</sub></td>
<td align="center"><img src="docs/captures/iphone-mac-statistiques.png" width="100%"><br><sub>Statistiques d'usage</sub></td>
<td align="center"><img src="docs/captures/iphone-mac-suite.png" width="100%"><br><sub>Navigation et alimentation</sub></td>
<td align="center"><img src="docs/captures/iphone-media-presentation.png" width="100%"><br><sub>Minuteur de présentation</sub></td>
</tr>
</table>

</details>

</div>

---

## Installation

> Il n'y a **aucun binaire à télécharger**. Chacun compile et signe avec son
> propre identifiant Apple — un identifiant **gratuit** suffit.

### 1. Ce qu'il vous faut

| | Détail |
|---|---|
| **Mac** | macOS 14 ou plus récent, avec **Xcode** installé (App Store, gratuit, ~15 Go) |
| **iPhone** | iOS 18 ou plus récent, et un câble pour la première installation |
| **Identifiant Apple** | gratuit. Ajoutez-le dans Xcode → Settings → Accounts |
| **XcodeGen** | le projet Xcode est **généré**, pas versionné |

<details>
<summary><b>Installer XcodeGen sans Homebrew</b></summary>

<br>

```bash
git clone https://github.com/yonaskolb/XcodeGen
cd XcodeGen
make install PREFIX=$HOME/.local
```

⚠️ **Piège** : XcodeGen a besoin de son dossier `SettingPresets/` **à côté du
binaire**. S'il manque, il produit un projet sans `PRODUCT_NAME` et la
compilation échoue sur un message trompeur :
`module name "" is not a valid identifier`.

Vérifiez : `ls ~/.local/bin/SettingPresets` doit lister des fichiers.

</details>

### 2. Cloner et configurer

```bash
git clone https://github.com/Axoneur/Trackpad-Hub.git
cd Trackpad-Hub
./setup.sh
```

`setup.sh` pose **deux questions**, une seule fois :

<table>
<tr><td width="30%"><b>Équipe de signature</b></td><td>

Dix caractères, propres à votre identifiant Apple.
**Où la trouver** : Xcode → Settings → Accounts → sélectionnez votre
identifiant : l'identifiant d'équipe est affiché à droite.

</td></tr>
<tr><td><b>Préfixe d'identifiant</b></td><td>

Par exemple `com.votrenom`.
**Pourquoi c'est obligatoire** : un App ID explicite est **unique dans tout le
système d'Apple**. `com.trackpadhub` appartient déjà au dépôt d'origine et sera
refusé. Le script propose un défaut à partir de votre nom d'utilisateur.

</td></tr>
</table>

Les réponses vont dans `trackpadhub.conf`, qui n'est **pas** versionné.

### 3. Installer

```bash
./reinstall.sh --all      # les deux apps, iPhone branché
```

| Commande | Effet |
|---|---|
| `./reinstall.sh --mac` | l'app macOS seule |
| `./reinstall.sh` | l'app iPhone seule |
| `./reinstall.sh --all` | les deux |
| `./reinstall.sh --lite` | iPhone sans le clavier système ni les widgets |
| `./reinstall.sh --install` | **réinstallation automatique tous les 6 jours** |

Le script affiche `App macOS installée et relancée (PID X, l'ancien était Y)`.
**Si les deux PID sont identiques, l'ancienne version tourne encore** — le
correctif que vous venez de compiler n'est pas celui qui s'exécute.

### 4. Faire confiance à l'app sur l'iPhone

À la première installation, l'iPhone refuse d'ouvrir l'app :

> Réglages → Général → VPN et gestion de l'appareil → votre compte développeur → **Se fier**

### ⏳ La limite des 7 jours

Avec un compte Apple **gratuit**, une signature vaut **7 jours**. Passé ce
délai l'app cesse de s'ouvrir : ce n'est pas une panne, c'est la règle d'Apple.

```bash
./reinstall.sh --install
```

pose un agent `launchd` qui réinstalle tout seul tous les 6 jours. L'iPhone
doit être branché à ce moment-là ; sinon la tentative échoue sans dégât et
recommence au cycle suivant.

---

## Premier appairage

<table>
<tr><td width="6%" align="center">1</td><td>Sur le <b>Mac</b>, ouvrez TrackPad Hub et laissez la fenêtre ouverte.</td></tr>
<tr><td align="center">2</td><td>Cliquez sur <b>« Accorder l'accès »</b>, puis cochez TrackPad Hub dans<br>Réglages Système → Confidentialité et sécurité → <b>Accessibilité</b>.</td></tr>
<tr><td align="center">3</td><td>Sur l'<b>iPhone</b>, ouvrez l'app et acceptez l'accès au <b>réseau local</b>.</td></tr>
<tr><td align="center">4</td><td>Sur le Mac : <b>« Ajouter un appareil » → « Afficher le code d'appairage »</b>.<br>Un QR code et six chiffres apparaissent, valables cinq minutes.</td></tr>
<tr><td align="center">5</td><td>Sur l'iPhone : <b>Réglages → Scanner un QR code</b>, ou saisissez le code.</td></tr>
<tr><td align="center">6</td><td>La pastille passe au <b>vert</b>. C'est fait — et ce ne sera plus jamais demandé.</td></tr>
</table>

| Symptôme | Cause |
|---|---|
| « Recherche du Mac… » ne s'arrête pas | Les deux appareils doivent être sur le même réseau Wi-Fi, et l'app macOS ouverte |
| Le curseur ne bouge pas | L'autorisation **Accessibilité** n'est pas accordée sur le Mac |
| Aucun code ne s'affiche | Le Mac n'en demande un que pour un appareil inconnu. Utilisez « Oublier » pour recommencer |

---

## Guide complet

### <img src="docs/icones/rectangle-and-hand-point-up-left.png" width="22" align="center"> Trackpad

**Les gestes**

| Geste | Effet |
|---|---|
| 1 doigt qui glisse | Déplace le curseur |
| 1 doigt, appui bref | Clic gauche |
| 2 doigts qui glissent | Défilement, avec inertie |
| 2 doigts qu'on écarte ou rapproche | Zoom |
| 2 doigts, appui bref | Clic droit |
| 3 doigts, appui bref | Clic milieu |
| 3 doigts vers le haut / bas | Mission Control / App Exposé |
| 3 doigts sur les côtés | Bureau précédent ou suivant |
| 4 doigts qu'on écarte / rapproche | Afficher le bureau / recherche |
| Appui bref **puis** glisser | Glisser-déposer |

**Les boutons, sous la surface**

| | Bouton | Ce qu'il fait |
|:-:|---|---|
| <img src="docs/icones/cursorarrow-click.png" width="18" align="center"> | **Clic gauche** | Comme un appui bref, mais **sans bouger le curseur** |
| <img src="docs/icones/cursorarrow-click-2.png" width="18" align="center"> | **Clic droit** | Ouvre le menu contextuel |
| <img src="docs/icones/hand-raised-fill.png" width="18" align="center"> | **Maintenir le clic** | Le bouton gauche **reste enfoncé** jusqu'au prochain appui. C'est ce qui permet de **déplacer une fenêtre** ou de la **redimensionner** en faisant glisser un doigt. Le bouton s'entoure de couleur tant qu'il est actif |
| <img src="docs/icones/dot-circle-and-hand-point-up-left-fill.png" width="18" align="center"> | **Souris en l'air** | Le curseur suit l'inclinaison de l'iPhone |
| <img src="docs/icones/scope.png" width="18" align="center"> | **Recentrer** | Remet la souris en l'air au centre, comme quand on soulève une souris pour la reposer au milieu du tapis |
| <img src="docs/icones/arrow-up-and-down-circle.png" width="18" align="center"> | **Défilement par inclinaison** | La position du téléphone à cet instant devient le repos |
| <img src="docs/icones/speedometer.png" width="18" align="center"> | **Vitesses** | Sensibilité du curseur et du défilement |
| <img src="docs/icones/keyboard.png" width="18" align="center"> | **Clavier** | Ouvre le clavier par-dessus, sans quitter l'écran |

<details>
<summary><b>Problèmes courants</b></summary>

<br>

| Symptôme | Solution |
|---|---|
| Tout ce que je touche se met à glisser | Le clic est resté maintenu : retouchez <img src="docs/icones/hand-raised-fill.png" width="14" align="center">. Il est entouré de couleur quand il est actif |
| Je n'arrive pas à déplacer une fenêtre | Placez d'abord le curseur sur sa barre de titre, touchez **Maintenir le clic**, faites glisser, puis retouchez pour relâcher |
| Le défilement part à l'envers | Réglages → Trackpad → **Défilement naturel** |
| Le curseur est trop lent ou trop nerveux | Touchez <img src="docs/icones/speedometer.png" width="14" align="center"> sous la surface |
| Le clic droit envoie deux clics gauches | Posez les deux doigts **en même temps**, sans les faire glisser |
| <img src="docs/icones/dot-circle-and-hand-point-up-left-fill.png" width="14" align="center"> est grisé | Les capteurs ne répondent pas. Fermez et rouvrez l'app |

**Bon à savoir** — le clic maintenu se relâche tout seul si vous quittez
l'écran ou si la liaison tombe : le Mac ne reste jamais bloqué en glissement.
Une zone morte d'environ 7° empêche le tremblement de la main de déclencher le
défilement par inclinaison.

</details>

---

### <img src="docs/icones/keyboard.png" width="22" align="center"> Clavier

<table>
<tr><td width="6%" align="center">1</td><td>Écrivez dans le champ du haut, puis touchez l'avion en papier pour <b>tout envoyer d'un coup</b>.</td></tr>
<tr><td align="center">2</td><td>Ou touchez les lettres une à une sur le clavier du bas.</td></tr>
<tr><td align="center">3</td><td>Pour un raccourci : touchez les modificateurs <b>⌘ ⌥ ⌃ ⇧</b>, puis la lettre.</td></tr>
<tr><td align="center">4</td><td>Les modificateurs se relâchent seuls après la frappe, comme sur un vrai clavier.</td></tr>
</table>

> **⌘A ne devient jamais ⌘Q, même sur un Mac AZERTY.**
> L'iPhone envoie des **caractères**, pas des positions de touches — voir
> [pourquoi](#pourquoi-liphone-nenvoie-pas-de-keycodes).

| | Aussi disponible |
|:-:|---|
| <img src="docs/icones/mic-fill.png" width="18" align="center"> | **Dictée vocale** — la reconnaissance se fait **sur l'iPhone** quand le modèle français est installé : l'audio ne part pas chez Apple. Placez le curseur dans le bon champ du Mac avant de commencer |
| <img src="docs/icones/doc-on-clipboard.png" width="18" align="center"> | **Presse-papiers partagé** — une copie faite sur le Mac remonte toute seule. « Copier ici » la met dans l'iPhone, « Envoyer » pousse celui de l'iPhone vers le Mac. Texte uniquement |
| <img src="docs/icones/globe.png" width="18" align="center"> | **Clavier système** — voir [l'extension](#clavier-système-optionnel) |

---

### <img src="docs/icones/playpause-fill.png" width="22" align="center"> Média

| | Fonction |
|:-:|---|
| <img src="docs/icones/playpause-fill.png" width="18" align="center"> | **Lecture** — agit sur l'app qui joue, quelle qu'elle soit |
| <img src="docs/icones/speedometer.png" width="18" align="center"> | **Volume et luminosité** — par curseur, via le réglage système du Mac |
| <img src="docs/icones/iphone-and-arrow-right-outward.png" width="18" align="center"> | **Reprise de lecture** — ce qui joue sur le Mac est proposé ici |

**Présentation** — lancez le diaporama sur le Mac, touchez **Démarrer**. Les
flèches changent de diapositive, « Écran noir » masque temporairement. Le
minuteur **vibre à chaque minute** : vous suivez votre temps sans regarder.

<details>
<summary><b>La reprise de lecture en détail</b></summary>

<br>

Une carte apparaît dans l'onglet Média dès qu'il y a quelque chose à reprendre.
Elle distingue **deux niveaux** :

| Affichage | Ce que le Mac a détecté |
|---|---|
| **Page ouverte sur le Mac** | L'onglet actif du navigateur. Toujours disponible |
| **Lecture en cours sur le Mac** | Une vidéo ou un morceau **réellement en train de jouer**, avec sa position et sa durée — **Picture in Picture compris** |

Le second niveau exige un réglage Safari, expliqué [plus bas](#détecter-ce-qui-est-réellement-lu).
Sans lui, la carte vous le dit en orange.

Le Mac se met en pause quand vous reprenez — désactivable dans la carte si vous
voulez garder le son sur les deux.

</details>

---

### <img src="docs/icones/square-stack.png" width="22" align="center"> Mac

**Constantes** — batterie, processeur, mémoire, disque, temps d'allumage.

**Applications** — les apps ouvertes défilent en haut, l'app active en premier.
« Tout voir » ouvre la liste complète avec recherche.

| Action | Effet |
|---|---|
| Afficher / Masquer | Amène l'app au premier plan, ou la cache |
| **Suspendre** | **Gèle l'app** : plus de processeur consommé, mais tout son état est gardé. Pratique pour une app qui fait tourner le ventilateur |
| Reprendre | La réveille |
| Quitter | Fermeture propre |
| Forcer à quitter | **À réserver aux apps qui ne répondent plus** : le travail non enregistré est perdu |

**Fenêtres** <img src="docs/icones/macwindow-on-rectangle.png" width="16" align="center"> — moitiés, quarts, tiers, plein
écran, centrer, **réduire**, rétablir, écran suivant.

> Agit sur la fenêtre active du Mac. Activez-la d'abord : si TrackPad Hub est
> au premier plan, il n'y a rien à déplacer.

| | Outil | Détail |
|:-:|---|---|
| <img src="docs/icones/square-on-square.png" width="18" align="center"> | **Onglets du navigateur** | Lister, aller à, fermer, rouvrir, suivant/précédent. Safari et la famille Chrome |
| <img src="docs/icones/doc-on-clipboard.png" width="18" align="center"> | **Historique du presse-papiers** | Les 30 derniers textes copiés sur le Mac. **En mémoire seulement** : un presse-papiers contient souvent des mots de passe |
| <img src="docs/icones/pianokeys.png" width="18" align="center"> | **Surface MIDI** | Le Mac devient un **contrôleur MIDI**. Serato, Traktor, Ableton, Logic et les plugins d'égalisation l'apprennent en un clic — aucun pilote à installer |
| <img src="docs/icones/note-text.png" width="18" align="center"> | **Notes rapides** | Un texte tapé ici arrive sur le Mac en notification **et** dans son presse-papiers |
| <img src="docs/icones/wand-and-rays.png" width="18" align="center"> | **Macros** | Voir ci-dessous |
| <img src="docs/icones/gamecontroller-fill.png" width="18" align="center"> | **Mode jeu** | Voir ci-dessous |
| <img src="docs/icones/chart-bar-fill.png" width="18" align="center"> | **Statistiques** | Temps connecté et gestes les plus utilisés. Ces chiffres **restent sur l'iPhone** |

<details>
<summary><b><img src="docs/icones/wand-and-rays.png" width="16" align="center"> Macros — enregistrer une séquence et la rejouer</b></summary>

<br>

1. Onglet Mac → Macros → **« Enregistrer une macro »**
2. Faites ce que vous voulez automatiser : touches, clics, raccourcis, fenêtres, onglets
3. **« Terminer »**, donnez un nom
4. Le bouton lecture rejoue la séquence, **avec les mêmes pauses que vous avez faites**

**Ce qui n'est pas enregistré** : déplacements du curseur, défilement, zoom.
Ils dépendent de l'endroit exact où se trouvait le curseur ; les rejouer
produirait un gribouillage. Utilisez plutôt les fenêtres et les raccourcis, qui
visent une cible et non une position.

| Symptôme | Solution |
|---|---|
| La macro va trop vite pour l'app visée | Marquez une pause plus longue pendant l'enregistrement : les délais sont conservés tels quels |
| Le bouton d'enregistrement est grisé | L'iPhone n'est pas encore appairé |
| Le compteur reste à zéro | L'écran affiche le nombre de **mouvements ignorés** : faites une touche ou un clic |

Les pauses sont plafonnées à cinq secondes — une interruption ne fige pas la macro.

</details>

<details>
<summary><b><img src="docs/icones/gamecontroller-fill.png" width="16" align="center"> Mode jeu — une manette plein écran</b></summary>

<br>

L'écran passe en manette : plus de barre, plus de défilement.

| Zone | Rôle |
|---|---|
| **Manche, à gauche** | Quatre directions, maintenues tant que le pouce reste écarté du centre |
| **Losange, à droite** | Quatre boutons d'action |
| **En haut** | L1, L2 à gauche · R1, R2 à droite |
| **Engrenage** | Règle les touches de votre jeu |

Les commandes envoient des **touches maintenues**, pas des frappes : avancer
suppose de garder la touche enfoncée. Un vrai gamepad exigerait un pilote HID
virtuel installé sur le Mac ; les jeux Mac lisent presque tous le clavier.

Par défaut **ZQSD**, pour clavier AZERTY. Le Mac résout la touche physique
contre sa disposition active : « Z » vise bien la touche que vous avez sous le
doigt.

| Symptôme | Solution |
|---|---|
| Le personnage continue d'avancer | Toutes les touches sont relâchées en quittant l'écran. Revenez-y et ressortez |
| Le jeu ne réagit pas | Il doit avoir le focus. Certains jeux en plein écran ignorent les touches synthétiques |

</details>

**Navigation et alimentation** — Bureau, Mission Control, fenêtre suivante,
Spotlight, <img src="docs/icones/moon-circle-fill.png" width="16" align="center"> Concentration, <img src="docs/icones/captions-bubble-fill.png" width="16" align="center"> Sous-titres,
puis veille, verrouillage, écran de veille, déconnexion, redémarrage, extinction.

> Redémarrer, Éteindre et Déconnexion demandent confirmation.
> À la première utilisation, macOS demande l'autorisation **Automatisation**.

**Raccourcis** <img src="docs/icones/bolt-fill.png" width="16" align="center"> — lancer une app, ouvrir un lien, ou exécuter
un raccourci de l'app Raccourcis du Mac. Appui long sur une vignette pour la
supprimer.

---

### ⚙️ Réglages

| Section | Ce qu'on y règle |
|---|---|
| **Apparence** | Thème clair, sombre ou système |
| **Clavier** | Disposition **affichée** sur l'iPhone : AZERTY, QWERTY, QWERTZ |
| **Gestes** | Gestes système à 3 doigts, ou glisser-déposer à la place |
| **Trackpad** | Accélération, inertie, défilement naturel, retour haptique |
| **Capteurs** | Mode poche, vitesse d'inclinaison |
| **Accessibilité** | Fort contraste, mode une main |

| | Réglage | Détail |
|:-:|---|---|
| <img src="docs/icones/hand-raised-slash-fill.png" width="18" align="center"> | **Mode poche** | Le capteur de proximité coupe **toutes** les entrées quand l'écran est couvert — poche, table retournée. Un clic maintenu est relâché au passage : le Mac ne reste jamais bloqué |
| <img src="docs/icones/figure-wave.png" width="18" align="center"> | **Accessibilité** | « Fort contraste » renforce la graisse des textes. « Mode une main » agrandit les boutons et les remonte à portée du pouce |

---

## Réglages avancés, optionnels

### Détecter ce qui est réellement lu

Sans ce réglage, l'app voit **quelle page** est ouverte, mais pas ce qui y joue.
C'est une limite de Safari, qu'aucune app ne peut contourner.

1. Safari → Réglages → **Avancé** → cocher « Afficher les fonctionnalités pour développeurs web »
2. Un menu **Développement** apparaît
3. Développement → cocher **« Autoriser JavaScript depuis les Apple Events »**

La carte de reprise affiche alors le titre réel, une barre d'avancement, et
retrouve une vidéo même en **Picture in Picture**.

### <img src="docs/icones/moon-circle-fill.png" width="18" align="center"> Concentration et <img src="docs/icones/captions-bubble-fill.png" width="18" align="center"> sous-titres

macOS n'expose **aucune API publique** pour ces deux réglages. La seule voie
supportée passe par l'app Raccourcis :

| Bouton | Raccourci à créer | Action à y mettre |
|---|---|---|
| Concentration | `TrackPad Hub Focus` | « Régler le mode de concentration » |
| Sous-titres | `TrackPad Hub Sous-titres` | Activer les sous-titres en direct |

Sans eux, l'app ouvre le volet des Réglages concerné et explique quoi créer.

### Clavier système, optionnel

Taper vers le Mac depuis **n'importe quelle app** de l'iPhone.

1. Réglages iOS → Général → Clavier → Claviers → **Ajouter un clavier**
2. Choisissez **« Clavier TrackPad Hub »**
3. Touchez son nom, activez **« Autoriser l'accès complet »** — nécessaire pour accéder au réseau
4. Dans un champ de saisie, basculez avec 🌐

L'extension **réutilise l'appairage** de l'app : aucun code à ressaisir.

---

## Trois transports, le plus rapide gagne

| | Quand | Latence |
|---|---|---|
| 🔌 **USB** | câble branché, app au premier plan | **1–2 ms**, constante |
| 📶 **Wi-Fi** | réseau commun | 2–5 ms |
| 🔵 **Bluetooth** | ni l'un ni l'autre | 15–30 ms |

Le choix est automatique. Les trois portent le **même appairage et le même
chiffrement** : un câble ne donne aucun droit de plus.

---

## <img src="docs/icones/lock-shield.png" width="22" align="center"> Sécurité

Se connecter au réseau **ne donne aucun droit**. Sans appairage, toutes les
commandes sont rejetées.

1. Le Mac envoie un **défi aléatoire** à chaque connexion
2. L'iPhone répond `HMAC-SHA256(secret, défi)` — **le code lui-même ne circule jamais**
3. Après réussite, un **jeton permanent** est rangé dans le trousseau des deux côtés
4. **Cinq codes erronés bloquent l'appareil**
5. « Oublier » sur le Mac retire un appareil : il devra refaire un appairage

Une fois appairé, chaque trame est scellée en **AES-GCM**, avec une clé dérivée
du jeton et **salée par le défi de la connexion** — elle change donc à chaque
fois. Un compteur croissant par canal interdit le rejeu.

---

## Architecture

Le **Mac est l'hôte** : il annonce le service Bonjour `_trackpadhub._tcp`
et écoute. L'**iPhone** le cherche et s'y connecte — de même que l'extension
de clavier, qui tourne dans un processus séparé.

```
TrackPadHub/
├── project.yml                    # Définition XcodeGen (4 cibles)
├── generate.sh / notarize.sh      # Génération du projet, signature + notarisation
├── Shared/                        # Code commun aux 4 cibles
│   ├── Message.swift              # Protocole JSON (trackpad, char, media, appairage…)
│   ├── SpecialKey.swift           # Touches nommées → keycodes stables
│   ├── KeyboardStyle.swift        # Disposition AFFICHÉE sur l'iPhone
│   ├── Pairing.swift              # Code à 6 chiffres, défi/réponse HMAC-SHA256
│   ├── PairingStore.swift         # Jetons dans le trousseau (partagé app ↔ extension)
│   ├── MessageConnection.swift    # Appairage, filtrage des non-appairés, choix du transport
│   ├── DirectLink.swift           # Wi-Fi : TCP (fiable) + UDP (chemin chaud)
│   ├── BluetoothLink.swift        # Secours BLE
│   ├── USBLink.swift              # Liaison filaire, via usbmuxd
│   └── SessionCipher.swift        # AES-GCM, clé dérivée du jeton, anti-rejeu
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

## Dépannage

| Symptôme | Cause la plus probable |
|---|---|
| L'app ne s'ouvre plus après une semaine | Signature expirée. `./reinstall.sh --all`, ou `--install` pour automatiser |
| `module name "" is not a valid identifier` | `SettingPresets/` manque à côté du binaire XcodeGen |
| Le curseur ne bouge pas | Autorisation **Accessibilité** non accordée sur le Mac |
| Les bureaux et App Exposé ne font rien | Autorisation **Automatisation** refusée |
| Configuration absente au lancement d'un script | `./setup.sh` n'a pas encore été exécuté |

**Voir en direct ce que le Mac reçoit** — la commande qui tranche entre
« l'iPhone n'envoie rien » et « le Mac ne sait pas l'exécuter » :

```bash
/usr/bin/log stream --predicate 'subsystem == "com.trackpadhub.machost"' --info
```

Le Mac dispose aussi d'un **panneau de diagnostic** intégré : bouton
stéthoscope en haut à droite de sa fenêtre. Il affiche la date de compilation
du binaire en cours, la disposition clavier active, les messages reçus et les
frappes réellement émises.

---

## Licence

**GNU GPL v3** — voir [LICENSE](LICENSE).

Vous pouvez utiliser, modifier et redistribuer ce code, à condition que les
versions modifiées que vous distribuez restent elles aussi sous GPL, sources
comprises.
