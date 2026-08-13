# Transports

Trois liaisons possibles entre l'iPhone et le Mac. Le choix est **automatique** :
la plus rapide disponible gagne.

| | Quand | Latence | Rôle |
|---|---|---|---|
| 🔌 **USB** | câble branché, app au premier plan | **1 à 2 ms**, constante | Le meilleur, pour dessiner ou jouer |
| 📶 **Wi-Fi** | réseau commun | 2 à 5 ms, variable | L'usage courant |
| 🔵 **Bluetooth** | ni câble ni Wi-Fi | 15 à 30 ms | Secours : hôtel, avion, réseau invité |

Les trois portent **le même protocole, le même appairage et le même
chiffrement**. Seul le tuyau change. Un câble ne donne aucun droit de plus :
brancher un iPhone inconnu ne le rend pas maître du Mac.

## Wi-Fi : deux canaux, pas un

| Canal | Ce qu'il porte | Pourquoi |
|---|---|---|
| **UDP** | déplacement, défilement, zoom | Ce sont des deltas : un paquet perdu est remplacé par le suivant 2 ms plus tard. Attendre une retransmission coûterait plus cher que la perte |
| **TCP** | clics, touches, appairage, apps, presse-papiers, fichiers | Un clic perdu ne se devine pas |

Le Mac annonce le service Bonjour `_trackpadhub._tcp`, l'iPhone le cherche. Le
port UDP voyage sur le canal TCP une fois l'appairage fait, inutile donc de
l'annoncer à la cantonade.

## USB : comment ça marche

Il n'existe **aucune API publique** pour parler en USB à un iPhone depuis une
app Mac. Mais macOS fait tourner `usbmuxd`, le démon qu'utilise Xcode pour
joindre les appareils branchés. On lui parle par sa socket Unix, et il
tunnelise une connexion TCP vers un port ouvert sur l'iPhone.

D'où des rôles **inverses des autres transports** : l'iPhone écoute, le Mac se
connecte à travers `usbmuxd`.

> **Limite** : iOS suspend les apps en arrière-plan. La liaison filaire ne
> répond que lorsque TrackPad Hub est au premier plan sur l'iPhone, et ne
> survit pas au verrouillage de l'écran.

## Bluetooth : ce qu'il vaut

Le débit suffit largement pour le curseur : un déplacement pèse 11 octets, à
120 par seconde cela fait 1,3 ko/s. La latence, elle, est moins bonne :
l'intervalle de connexion BLE va de 15 à 30 ms. D'où le rôle de secours.

Le transfert de fichiers y reste possible mais lent : à prévoir en Wi-Fi.

## Pourquoi pas MultipeerConnectivity

Le projet l'utilisait au départ. MPC empile sa propre session chiffrée, son
routage multi-pairs et sa couche de fiabilité au-dessus du réseau. Cette
surcouche est incompressible et se paie en latence sur le seul chemin qui
compte : le déplacement du curseur, envoyé jusqu'à 120 fois par seconde.

---

Suite : [[Sécurité|Securite]]
