# TrackPad Hub

> **Votre iPhone devient le trackpad de votre Mac.**
> Pas une souris émulée : accélération, inertie, gestes à plusieurs doigts,
> clavier complet, contrôle des fenêtres, du média et des applications.

<img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/banniere.svg" width="100%">

## En bref

| | |
|---|---|
| **Ce qu'il faut** | Un Mac (macOS 14 ou plus), un iPhone (iOS 18 ou plus), un identifiant Apple gratuit |
| **Ce qu'on installe** | Xcode et XcodeGen, sur le Mac uniquement |
| **Combien de temps** | 15 à 20 minutes la première fois, 1 minute côté iPhone |
| **Ce que ça coûte** | Rien. Aucun abonnement, aucun compte payant |
| **La contrainte à connaître** | L'app iPhone doit être réinstallée tous les 7 jours. C'est une règle d'Apple, et le Mac s'en charge tout seul quand vous branchez le câble |

## Par où commencer

| Votre situation | La page à ouvrir |
|---|---|
| 🆕 Vous découvrez le projet | [[Installation]], puis [[Premier appairage\|Premier-appairage]] |
| 🖱️ Vous voulez tout savoir des gestes | [[Trackpad]] |
| ⏳ L'app iPhone ne s'ouvre plus | [[Signature et renouvellement\|Signature-et-renouvellement]] |
| 🔧 Quelque chose ne marche pas | [[Dépannage\|Depannage]] |
| ❓ Vous avez une question courte | [[FAQ]] |
| 🧑‍💻 Vous voulez lire ou modifier le code | [[Architecture]] |

## Les cinq écrans de l'app iPhone

| Écran | Ce qu'on y fait |
|---|---|
| [[Trackpad]] | Curseur, gestes, clics, souris en l'air |
| [[Clavier]] | Texte, raccourcis, dictée, presse-papiers |
| [[Média\|Media]] | Lecture, volume, présentation, reprise sur l'iPhone |
| [[Onglet Mac\|Mac]] | Constantes, apps, fenêtres, onglets, outils |
| [[Réglages\|Reglages]] | Appairage, capteurs, accessibilité, rappels |

Et trois écrans qu'on ouvre plus rarement : [[Macros]],
[[Mode jeu\|Mode-jeu]], [[Surface MIDI\|Surface-MIDI]].

## Ce qui distingue ce projet

**Trois transports, choisis automatiquement.** Câble USB (1 à 2 ms), Wi-Fi
(2 à 5 ms), Bluetooth en secours. Vous ne choisissez rien, la plus rapide
disponible gagne. Voir [[Transports]].

**Le clavier respecte votre disposition.** ⌘A reste « tout sélectionner »
même sur un Mac AZERTY, là où une table de touches figée enverrait ⌘Q et
quitterait l'application. Voir [[Clavier]].

**Rien ne passe sans appairage.** Se connecter au réseau ne donne aucun droit :
il faut un code affiché sur le Mac, et tout ce qui circule ensuite est chiffré.
Voir [[Sécurité\|Securite]].

**La maintenance se fait toute seule.** Branchez l'iPhone quand l'échéance
approche : le Mac réinstalle sans qu'on lui demande. Et si vous ne branchez
rien, les deux apps préviennent trois jours avant. Voir
[[Signature et renouvellement\|Signature-et-renouvellement]].
