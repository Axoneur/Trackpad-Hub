# <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/pianokeys.png" width="24" align="center"> Surface MIDI

Le Mac se présente comme un **appareil MIDI** nommé « TrackPad Hub ».

## Pourquoi cette voie

Trois fonctionnalités butaient sur le même mur : mode DJ, égaliseur audio,
palettes et roulettes pour les apps créatives. Toutes supposaient de capter ou
de traiter le son du système, ce qui exige un **pilote audio virtuel** installé
sur le Mac — un projet séparé, avec son propre installeur.

Le MIDI contourne le mur entièrement : **aucun son ne transite**.

## S'en servir

| | |
|:-:|---|
| **1** | Ouvrez votre logiciel : Serato, Traktor, Ableton, Logic, Final Cut, ou un plugin d'égalisation |
| **2** | Activez son mode **« MIDI learn »** |
| **3** | Bougez un curseur ou touchez un pad dans l'app |
| **4** | C'est associé |

Quatre curseurs — contrôleurs 1 à 4 sur le canal 1 — et huit pads, sensibles à
l'appui **et** au relâchement, comme de vrais pads.

## Ce qu'il faut savoir

- Aucun pilote à installer : `MIDISourceCreateWithProtocol` est une API publique
- Aucune autorisation demandée
- L'appareil apparaît dans la liste MIDI du système, visible par tout logiciel

---

Suite : [[Transports]]
