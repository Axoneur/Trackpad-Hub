# <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/keyboard.png" width="24" align="center"> Clavier

<div align="center"><img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/captures/iphone-clavier-azerty.png" width="32%"> <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/captures/iphone-clavier-touches.png" width="32%"></div>

## Envoyer du texte

| | |
|:-:|---|
| **1** | Écrivez dans le champ du haut, puis touchez l'avion en papier pour **tout envoyer d'un coup** |
| **2** | Ou touchez les lettres une à une sur le clavier du bas |
| **3** | Pour un raccourci : touchez les modificateurs **⌘ ⌥ ⌃ ⇧**, puis la lettre |
| **4** | Les modificateurs se relâchent seuls après la frappe, comme sur un vrai clavier |

Sont aussi disponibles : **F1 à F12**, les flèches, Début, Fin, Page précédente
et suivante, Échap, Tab, Espace, Entrée, Suppression.

## Pourquoi ⌘A ne devient jamais ⌘Q

Un keycode macOS désigne une **touche physique**, pas une lettre. La touche `0`
produit `a` en QWERTY US et `q` en AZERTY français.

Une table figée transformerait donc ⌘A — tout sélectionner — en ⌘Q — quitter
l'app. Sur ce Mac, mesuré :

```
table ANSI figée   : « a » → touche 0, qui produit « q »   ⚠
disposition réelle : « a » → touche 12                      ok
```

**L'iPhone envoie donc des caractères, jamais des keycodes.** Le Mac les traduit
contre sa disposition **active**. Seules les touches nommées — entrée,
tabulation, flèches — voyagent en keycode : leur position ne change pas d'une
disposition à l'autre.

> Un raccourci est **toujours** résolu contre la disposition active, jamais
> contre celle forcée dans les réglages : sinon macOS réinterpréterait le
> keycode différemment et le raccourci partirait ailleurs.

## <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/mic-fill.png" width="20" align="center"> Dictée vocale

1. Onglet Clavier → **« Dictée vocale »**
2. Autorisez le micro et la reconnaissance vocale à la première utilisation
3. Parlez : la transcription s'affiche au fur et à mesure
4. **« Arrêter la dictée »** : le texte part sur le Mac

> La reconnaissance se fait **sur l'iPhone** quand le modèle français est
> installé : l'audio ne part pas chez Apple.
> Placez le curseur dans le bon champ du Mac **avant** de commencer.

## <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/doc-on-clipboard.png" width="20" align="center"> Presse-papiers partagé

| Action | Effet |
|---|---|
| Copie sur le Mac | Le texte remonte tout seul sur l'iPhone |
| **Copier ici** | Place ce texte dans le presse-papiers de l'iPhone |
| **Envoyer** | Pousse le presse-papiers de l'iPhone vers le Mac |
| **Récupérer** | Redemande au Mac son contenu actuel |

Texte uniquement — ni images, ni fichiers. Pour l'historique complet, voir
[[Onglet Mac|Mac]].

## <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/globe.png" width="20" align="center"> Clavier système, optionnel

Taper vers le Mac depuis **n'importe quelle app** de l'iPhone.

1. Réglages iOS → Général → Clavier → Claviers → **Ajouter un clavier**
2. Choisissez **« Clavier TrackPad Hub »**
3. Touchez son nom, activez **« Autoriser l'accès complet »** — nécessaire pour accéder au réseau
4. Dans un champ de saisie, basculez avec 🌐

L'extension **réutilise l'appairage** de l'app : aucun code à ressaisir.

| Symptôme | Solution |
|---|---|
| Le clavier n'envoie rien | Vérifiez « Autoriser l'accès complet », et appairez d'abord dans l'app principale |
| Il redemande un code | Les deux cibles doivent être signées avec la **même équipe** Apple |

## Problèmes courants

| Symptôme | Solution |
|---|---|
| Les mauvaises lettres arrivent | Dans l'app macOS, choisissez la bonne disposition au lieu de « Suivre le clavier actif » |
| Le clavier affiché n'est pas dans le bon ordre | [[Réglages|Reglages]] → Clavier → Disposition affichée |

---

Suite : [[Média|Media]]
