# <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/playpause-fill.png" width="24" align="center"> Média

*Commander la lecture du Mac, et reprendre sur l'iPhone ce qui y joue.*

<div align="center"><img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/captures/iphone-media-reprise.png" width="32%"> <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/captures/iphone-media-presentation.png" width="32%"></div>

## Lecture et volume

| | Fonction | Ce qu'elle fait |
|:-:|---|---|
| <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/playpause-fill.png" width="18" align="center"> | **Lecture, précédent, suivant** | Agit sur l'app qui joue, quelle qu'elle soit |
| <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/speedometer.png" width="18" align="center"> | **Volume** | Par curseur, via le réglage système du Mac |
| ☀️ | **Luminosité** | Moins clair, plus clair, éteindre l'écran |

> Si lecture/pause reste sans effet : certaines versions de macOS bloquent le
> contrôle média des apps tierces. Un repli par touches clavier prend alors le
> relais, ce qui exige l'autorisation **Accessibilité**.

## Mode présentation

1. Lancez le diaporama sur le Mac
2. Touchez **Démarrer**
3. Les flèches changent de diapositive
4. **Écran noir** ou **Écran blanc** masquent temporairement

Fonctionne avec Keynote, PowerPoint, Google Slides et Aperçu.

> Le minuteur **vibre à chaque minute écoulée** : vous suivez votre temps sans
> jamais regarder l'écran.

## <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/iphone-and-arrow-right-outward.png" width="20" align="center"> Reprise de lecture

Une carte apparaît dès qu'il y a quelque chose à reprendre. Elle distingue
**deux niveaux** :

| Affichage | Ce que le Mac a détecté |
|---|---|
| **Page ouverte sur le Mac** | L'onglet actif du navigateur. Toujours disponible |
| **Lecture en cours sur le Mac** | Une vidéo ou un morceau **réellement en train de jouer**, avec position et durée, **Picture in Picture compris** |

Touchez **« Reprendre sur l'iPhone »** : le lien s'ouvre ici et le Mac se met
en pause. La pause se désactive dans la carte si vous voulez garder le son sur
les deux.

### Activer la détection de lecture réelle

Sans ce réglage, l'app voit **quelle page** est ouverte, mais pas ce qui y
joue. C'est une limite de Safari, qu'aucune app ne peut contourner.

1. Safari → Réglages → **Avancé** → cocher « Afficher les fonctionnalités pour développeurs web »
2. Un menu **Développement** apparaît dans la barre des menus
3. Développement → cocher **« Autoriser JavaScript depuis les Apple Events »**

> **Ce que ça implique** : ce réglage autorise toute app disposant de
> l'autorisation Automatisation pour Safari à exécuter du JavaScript dans vos
> onglets. Raisonnable sur une machine personnelle ; à éviter sur une machine
> partagée.

### Ce qui est détecté, dans l'ordre

| Source | Ce qu'on obtient | Reprise |
|---|---|---|
| **Spotify** | URI de piste + position | À la seconde près |
| **Musique** | Titre + artiste | Recherche dans l'app Musique |
| **Navigateur** | URL + titre de l'onglet | Le lien tel quel, `&t=` ajouté sur YouTube |

Un lecteur dédié qui joue l'emporte sur un onglet de navigateur qui traîne.

| Symptôme | Cause |
|---|---|
| Rien n'apparaît | Une app qui n'expose rien à AppleScript ne peut pas être détectée |
| Ça reprend au début | Seuls Spotify et YouTube savent reprendre à la seconde |

---

Suite : [[Onglet Mac|Mac]]
