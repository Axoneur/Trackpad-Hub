# Premier appairage

*Relier l'iPhone au Mac la première fois. Six étapes, cinq minutes, une seule fois.*

<div align="center"><img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/captures/mac-fenetre.png" width="90%"></div>

## Les six étapes

| | |
|:-:|---|
| **1** | Sur le **Mac**, ouvrez TrackPad Hub et laissez la fenêtre ouverte. |
| **2** | Cliquez sur **« Accorder l'accès »**, puis cochez TrackPad Hub dans Réglages Système → Confidentialité et sécurité → **Accessibilité**. |
| **3** | Sur l'**iPhone**, ouvrez l'app et acceptez l'accès au **réseau local**. |
| **4** | Sur le Mac : **« Ajouter un appareil » → « Afficher le code d'appairage »**. Un QR code et six chiffres apparaissent, valables cinq minutes. |
| **5** | Sur l'iPhone : **Réglages → Scanner un QR code**, ou saisissez le code à la main. |
| **6** | La pastille passe au **vert**. C'est fait, et ce ne sera plus jamais demandé. |

## Si ça bloque

| Symptôme | Cause |
|---|---|
| « Recherche du Mac… » ne s'arrête pas | Les deux appareils doivent être sur le même réseau Wi-Fi, et l'app macOS ouverte |
| Le curseur ne bouge pas | L'autorisation **Accessibilité** n'est pas accordée sur le Mac |
| Aucun code ne s'affiche | Le Mac n'en demande un que pour un appareil **inconnu**. Utilisez « Oublier » sur le Mac pour repartir de zéro |
| Le code est refusé | Il expire au bout de cinq minutes. Affichez-en un nouveau |
| « Appareil bloqué » | Cinq codes erronés bloquent l'appareil. « Oublier » sur le Mac débloque |

## Ce qui se passe réellement

Le code ne circule **jamais** sur le réseau. Le Mac envoie un défi aléatoire,
l'iPhone répond par une signature de ce défi. Le détail est dans [[Sécurité|Securite]].

Une fois l'appairage réussi, un jeton permanent est rangé dans le trousseau des
deux côtés : les connexions suivantes sont silencieuses.

---

Suite : [[Trackpad]]
