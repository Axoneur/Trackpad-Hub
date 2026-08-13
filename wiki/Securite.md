# <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/lock-shield.png" width="24" align="center"> Sécurité

## Le principe

**Se connecter au réseau ne donne aucun droit.** Tant qu'un appareil n'a pas
prouvé qu'il connaît le secret, tous ses messages de contrôle sont jetés. Sans
cette étape, n'importe quel appareil du réseau Wi-Fi prendrait la main sur le
Mac.

## L'appairage, pas à pas

| | |
|:-:|---|
| **1** | Le Mac envoie un **défi aléatoire** à chaque connexion |
| **2** | L'iPhone répond `HMAC-SHA256(secret, défi)`. **Le secret ne circule jamais** |
| **3** | Premier appairage : le secret est le code à 6 chiffres affiché sur le Mac |
| **4** | Ensuite : un **jeton permanent**, rangé dans le trousseau des deux côtés |
| **5** | **Cinq échecs bloquent l'appareil** |

Le code est **global au Mac**, pas rattaché à un appareil : il s'affiche à la
demande et vaut cinq minutes pour n'importe quel appareil.

L'iPhone **conserve le code saisi** et le rejoue sur chaque nouveau défi
jusqu'à réussite : sans ça, un défi renouvelé entre le scan et l'envoi ferait
échouer l'appairage sans explication.

## Le chiffrement

Une fois l'appairage réussi, chaque trame est scellée en **AES-GCM**.

| | |
|---|---|
| **Clé** | Dérivée du jeton par HKDF-SHA256, **salée par le défi de la connexion** — elle change donc à chaque fois |
| **Anti-rejeu** | Le nonce porte un compteur strictement croissant, **par direction et par transport** |
| **Avant appairage** | Les messages voyagent en clair : ils ne portent aucun secret, seule une preuve HMAC circule |

> Saler la clé avec le défi n'est pas cosmétique. Sans ce sel, la clé ne
> dépendrait que du jeton, donc serait identique d'une session à l'autre —
> alors que les compteurs anti-rejeu repartent de zéro à chaque connexion. Un
> paquet capté un jour serait rejouable le lendemain.

## Oublier un appareil

Sur le Mac, **« Oublier »** retire un appareil : il devra refaire un appairage
complet. La connexion en cours est coupée immédiatement.

> Sur macOS, un élément du trousseau appartient à la signature de l'app qui l'a
> créé, et une app recompilée peut ne plus pouvoir l'effacer. « Oublier »
> inscrit donc l'appareil dans une liste de révocation séparée, qui fait foi.

## Ce qui reste sur l'appareil

| Donnée | Où | Durée |
|---|---|---|
| Jeton d'appairage | Trousseau, des deux côtés | Jusqu'à « Oublier » |
| Historique du presse-papiers | Mémoire de l'app Mac | Disparaît avec l'app |
| Notes rapides | Mémoire de l'app Mac | Disparaît avec l'app |
| Statistiques d'usage | UserDefaults de l'iPhone | Jusqu'à remise à zéro |

Rien n'est envoyé à un serveur : il n'y en a aucun.

---

Suite : [[Architecture]]
