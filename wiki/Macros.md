# <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/wand-and-rays.png" width="24" align="center"> Macros

Enregistrer une séquence d'actions et la rejouer d'un appui.

## Enregistrer

| | |
|:-:|---|
| **1** | Onglet Mac → Macros → **« Enregistrer une macro »** |
| **2** | Faites ce que vous voulez automatiser : touches, clics, raccourcis, fenêtres, onglets |
| **3** | **« Terminer »**, puis donnez un nom |
| **4** | Le bouton lecture rejoue la séquence, **avec les mêmes pauses que vous avez faites** |

## Ce qui est enregistré, et ce qui ne l'est pas

| Enregistré | Ignoré |
|---|---|
| Touches, texte, raccourcis | Déplacements du curseur |
| Clics | Défilement |
| Commandes système, gestes | Zoom |
| Placement des fenêtres, onglets | |

**Pourquoi cette exclusion** : un déplacement dépend de l'endroit exact où se
trouvait le curseur. Le rejouer ailleurs produirait un gribouillage, pas une
automatisation. Préférez les fenêtres et les raccourcis, qui visent une
**cible** et non une position.

> Pendant l'enregistrement, l'écran affiche la dernière action captée **et le
> nombre de mouvements ignorés**. Si le compteur reste à zéro, faites une
> touche ou un clic.

## Les pauses

Les délais entre actions sont conservés tels quels : ouvrir Spotlight puis
taper immédiatement perdrait les premières lettres, le temps que la fenêtre
apparaisse.

Ils sont **plafonnés à cinq secondes**, pour qu'une interruption pendant
l'enregistrement ne fige pas la macro.

## Problèmes courants

| Symptôme | Solution |
|---|---|
| Ma macro ne rejoue pas les mouvements du curseur | C'est voulu, voir ci-dessus |
| La macro va trop vite pour l'app visée | Marquez une pause plus longue pendant l'enregistrement |
| Le bouton d'enregistrement est grisé | L'iPhone n'est pas encore appairé |

> Lancer une macro pendant un enregistrement ne la recopie pas dedans.

---

Suite : [[Mode jeu|Mode-jeu]]
