# <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/square-stack.png" width="24" align="center"> Onglet Mac

<div align="center"><img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/captures/iphone-mac-constantes.png" width="32%"> <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/captures/iphone-mac-outils.png" width="32%"></div>

## Constantes

Batterie, processeur, mémoire, disque, temps d'allumage. Rafraîchies à
l'ouverture de l'onglet et avec le bouton en haut à droite.

## Applications

Les apps ouvertes défilent en haut, l'app active en premier. **« Tout voir »**
ouvre la liste complète avec recherche, et un onglet **Installées** pour lancer
ce qui ne tourne pas encore.

| Action | Effet |
|---|---|
| Afficher / Masquer | Amène l'app au premier plan, ou la cache |
| **Suspendre** | **Gèle l'app** : plus de processeur consommé, tout son état gardé |
| Reprendre | La réveille |
| Quitter | Fermeture propre |
| Forcer à quitter | **À réserver aux apps qui ne répondent plus** : le travail non enregistré est perdu |

> « Suspendre » est utile pour une app qui fait tourner le ventilateur sans
> qu'on veuille la fermer.

## <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/macwindow-on-rectangle.png" width="20" align="center"> Fenêtres

<div align="center"><img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/captures/iphone-mac-fenetres.png" width="32%"></div>

| Rangée | Emplacements |
|---|---|
| **Courants** | Gauche, Droite, Haut, Bas, Plein écran, Centrer, **Réduire**, Rétablir |
| **Quarts** | Haut gauche, haut droit, bas gauche, bas droit |
| **Tiers** | Tiers gauche, central, droit · Deux tiers gauche, droite |
| **États** | Plein écran natif, Écran suivant |

> **Agit sur la fenêtre active du Mac.** Activez-la d'abord : si TrackPad Hub
> est au premier plan, il n'y a rien à déplacer.

« Rétablir » annule le dernier placement. « Écran suivant » conserve les
proportions, donc une fenêtre en moitié gauche reste en moitié gauche même si
le second écran n'a pas la même taille.

## Les outils

| | Outil | Détail |
|:-:|---|---|
| <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/square-on-square.png" width="18" align="center"> | **Onglets du navigateur** | Lister, aller à, fermer, rouvrir, suivant/précédent. Safari et la famille Chrome. Firefox n'expose pas ses onglets |
| <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/doc-on-clipboard.png" width="18" align="center"> | **Historique du presse-papiers** | Les 30 derniers textes copiés sur le Mac |
| <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/pianokeys.png" width="18" align="center"> | **Surface MIDI** | Voir [[Surface MIDI\|Surface-MIDI]] |
| <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/note-text.png" width="18" align="center"> | **Notes rapides** | Un texte tapé ici arrive sur le Mac en notification **et** dans son presse-papiers |
| <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/wand-and-rays.png" width="18" align="center"> | **Macros** | Voir [[Macros]] |
| <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/gamecontroller-fill.png" width="18" align="center"> | **Mode jeu** | Voir [[Mode jeu\|Mode-jeu]] |
| <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/chart-bar-fill.png" width="18" align="center"> | **Statistiques** | Temps connecté et gestes les plus utilisés |

### Historique du presse-papiers

Deux destinations, à ne pas confondre :

| Bouton | Où va le texte |
|---|---|
| **Sur le Mac** | Dans le presse-papiers **du Mac**, pour le coller là-bas |
| **Copier** | Dans le presse-papiers **de l'iPhone** |

> **En mémoire seulement, volontairement.** Un presse-papiers contient
> régulièrement des mots de passe et des jetons : les écrire sur disque leur
> donnerait une durée de vie que personne n'a demandée. L'historique disparaît
> avec l'app Mac.

### Statistiques

<div align="center"><img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/captures/iphone-mac-statistiques.png" width="32%"></div>

Temps connecté, et actions classées **par fréquence** — la plus utilisée en
tête. L'icône en haut à droite remet tout à zéro.

> Ces chiffres **restent sur l'iPhone**. Ils ne sont ni envoyés au Mac, ni
> transmis ailleurs.

## Navigation et alimentation

Bureau, Mission Control, fenêtre suivante, Spotlight,
<img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/moon-circle-fill.png" width="16" align="center"> Concentration, <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/captions-bubble-fill.png" width="16" align="center"> Sous-titres —
puis veille, verrouillage, écran de veille, déconnexion, redémarrage, extinction.

> Redémarrer, Éteindre et Déconnexion demandent confirmation.

### Concentration et sous-titres : un réglage préalable

macOS n'expose **aucune API publique** pour ces deux-là. La seule voie
supportée passe par l'app Raccourcis :

| Bouton | Raccourci à créer | Action à y mettre |
|---|---|---|
| Concentration | `TrackPad Hub Focus` | « Régler le mode de concentration » |
| Sous-titres | `TrackPad Hub Sous-titres` | Activer les sous-titres en direct |

Sans eux, l'app ouvre le volet des Réglages concerné et explique quoi créer.

## <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/bolt-fill.png" width="20" align="center"> Raccourcis

Lancer une app, ouvrir un lien, ou exécuter un raccourci de l'app Raccourcis du
Mac. Appui long sur une vignette pour la supprimer.

---

Suite : [[Réglages|Reglages]]
