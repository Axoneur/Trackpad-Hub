# <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/gamecontroller-fill.png" width="24" align="center"> Mode jeu

Une manette plein écran : plus de barre, plus de défilement.

## La disposition

| Zone | Rôle |
|---|---|
| **Manche, à gauche** | Quatre directions, maintenues tant que le pouce reste écarté du centre |
| **Losange, à droite** | Quatre boutons d'action |
| **En haut à gauche** | L1, L2 |
| **En haut à droite** | R1, R2 |
| **Engrenage, au centre** | Règle les touches de votre jeu |

Le vide au milieu est voulu : c'est là que se posent les paumes.

## Ce qui est envoyé

Des **touches maintenues**, pas des frappes. Avancer suppose de garder la
touche enfoncée ; un appui bref ferait faire un pas au personnage.

> Un vrai gamepad exigerait un pilote HID virtuel installé sur le Mac, soit un
> projet séparé, avec son installeur. Les jeux Mac lisent presque tous le
> clavier, ce qui rend cette voie suffisante et sans rien à installer.

Par défaut **ZQSD**, adapté aux claviers AZERTY. Le Mac résout la touche
physique contre sa disposition active : « Z » vise bien la touche que vous avez
sous le doigt.

## Réglages fins

Une **zone morte au tiers de la course** empêche un pouce simplement posé
d'envoyer une direction. Le manche borne son **rayon** et non chaque axe :
les diagonales restent dans le disque.

## Problèmes courants

| Symptôme | Solution |
|---|---|
| Le personnage continue d'avancer | Toutes les touches sont relâchées en quittant l'écran. Revenez-y et ressortez |
| Le jeu ne réagit pas | Il doit avoir le focus. Certains jeux en plein écran ignorent les touches synthétiques |
| Les directions sont décalées | Touchez l'engrenage pour changer les touches |

---

Suite : [[Surface MIDI|Surface-MIDI]]
