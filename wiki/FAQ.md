# <img src="https://raw.githubusercontent.com/Axoneur/Trackpad-Hub/main/docs/icones/sections/questionmark-circle-fill.png" width="26" align="center"> FAQ

*Les questions qui reviennent, avec des réponses courtes.*

### Faut-il un compte Apple payant ?

Non. Un identifiant Apple **gratuit** suffit, avec une contrainte : la
signature vaut **7 jours**. `./reinstall.sh --install` automatise la
réinstallation tous les 6 jours. Le compte payant ne devient utile que pour
**distribuer** l'app à d'autres.

### Pourquoi aucun binaire à télécharger ?

Distribuer une app macOS prête à l'emploi exige un certificat Developer ID et
une notarisation, donc un compte payant. Chacun compile et signe avec son
propre identifiant : c'est le mode de distribution normal pour ce genre
d'utilitaire.

### Ça marche sans Wi-Fi ?

Oui. Le câble USB donne la meilleure latence, et le Bluetooth prend le relais
quand il n'y a ni câble ni réseau commun. Voir [[Transports]].

### Ça marche sur iPad ?

L'app s'installe sur iPad. L'interface est adaptative et s'élargit en paysage.

### Mes frappes circulent-elles en clair ?

Non. Une fois l'appairage fait, chaque trame est chiffrée en AES-GCM avec une
clé dérivée du jeton. Voir [[Sécurité|Securite]].

### Y a-t-il un serveur ? Mes données partent-elles quelque part ?

Il n'y a **aucun serveur**. L'iPhone parle directement au Mac. Les
statistiques restent sur l'iPhone, l'historique du presse-papiers en mémoire du
Mac.

### Pourquoi le clic droit et le clic gauche ont-ils des boutons dédiés ?

Pour cliquer **sans bouger le curseur**. Les gestes équivalents, appui à un ou
deux doigts, restent disponibles.

### Peut-on simuler un vrai clic fort ?

Non, et c'est définitif. Le clic fort naît dans le pilote du trackpad ; AppKit
refuse même de **fabriquer** l'événement de pression. Ce qui manquait pour
déplacer et redimensionner une fenêtre n'était d'ailleurs pas la pression mais
le **maintien** du bouton. Voir [[Trackpad]].

### Pourquoi mes macros n'enregistrent pas les mouvements du curseur ?

C'est voulu : un déplacement dépend de l'endroit exact où était le curseur.
Voir [[Macros]].

### Le mode jeu remplace-t-il une manette ?

Il envoie des **touches maintenues**, ce que la plupart des jeux Mac
comprennent. Un vrai gamepad exigerait un pilote HID virtuel installé sur le
Mac. Voir [[Mode jeu|Mode-jeu]].

### Comment signaler un problème ?

Ouvrez une issue sur le [dépôt](https://github.com/Axoneur/Trackpad-Hub/issues),
en joignant la sortie de la commande de diagnostic ([[Dépannage|Depannage]]).
