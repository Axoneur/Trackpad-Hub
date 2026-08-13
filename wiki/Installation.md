# Installation

> Il n'y a **aucun binaire à télécharger**. Chacun compile et signe avec son
> propre identifiant Apple. Un identifiant **gratuit** suffit.

## 1. Prérequis

| | Détail |
|---|---|
| **Mac** | macOS 14 ou plus récent, avec **Xcode** (App Store, gratuit, ~15 Go) |
| **iPhone** | iOS 18 ou plus récent, et un câble pour la première installation |
| **Identifiant Apple** | gratuit. À ajouter dans Xcode → Settings → Accounts |
| **XcodeGen** | le projet Xcode est **généré**, pas versionné |

### Installer XcodeGen sans Homebrew

```bash
git clone https://github.com/yonaskolb/XcodeGen
cd XcodeGen
make install PREFIX=$HOME/.local
```

> ⚠️ **Piège** : XcodeGen a besoin de son dossier `SettingPresets/` **à côté du
> binaire**. S'il manque, il produit un projet sans `PRODUCT_NAME` et la
> compilation échoue sur un message trompeur :
> `module name "" is not a valid identifier`.
>
> Vérifiez avec `ls ~/.local/bin/SettingPresets` : le dossier doit contenir des fichiers.

## 2. Cloner et configurer

```bash
git clone https://github.com/Axoneur/Trackpad-Hub.git
cd Trackpad-Hub
./setup.sh
```

Le script pose **deux questions**, une seule fois.

### L'équipe de signature

Dix caractères, propres à votre identifiant Apple.

> Xcode → Settings → Accounts → sélectionnez votre identifiant.
> L'identifiant d'équipe est affiché à droite.

### Le préfixe d'identifiant

Par exemple `com.votrenom`.

**Pourquoi c'est obligatoire** : un App ID explicite est **unique dans tout le
système d'Apple**. `com.trackpadhub` appartient déjà au dépôt d'origine et sera
refusé à l'enregistrement. Le script propose un défaut construit à partir de
votre nom d'utilisateur.

Les réponses sont écrites dans `trackpadhub.conf`, qui n'est **pas** versionné.

## 3. Installer les apps

```bash
./reinstall.sh --all
```

| Commande | Effet |
|---|---|
| `./reinstall.sh --mac` | l'app macOS seule |
| `./reinstall.sh` | l'app iPhone seule |
| `./reinstall.sh --all` | les deux, iPhone branché |
| `./reinstall.sh --lite` | iPhone sans le clavier système ni les widgets |
| `./reinstall.sh --install` | réinstallation automatique tous les 6 jours |

Le script affiche :

```
App macOS installée et relancée (PID 1234, l'ancien était 1200)
```

> **Si les deux PID sont identiques, l'ancienne version tourne encore.** Le
> code que vous venez de compiler n'est pas celui qui s'exécute. Vérifiez-le
> avant de conclure qu'un correctif ne fonctionne pas.

## 4. Faire confiance à l'app sur l'iPhone

À la première installation, l'iPhone refuse d'ouvrir l'app :

> Réglages → Général → VPN et gestion de l'appareil → votre compte développeur → **Se fier**

## 5. Les autorisations macOS

| Autorisation | Pour quoi | Quand |
|---|---|---|
| **Accessibilité** | curseur, clics, clavier : **tout en dépend** | demandée au lancement |
| **Automatisation** | bureaux, App Exposé, redémarrage, extinction | demandée au lancement |
| **Réseau local** | découverte de l'iPhone | demandée au lancement |
| **Bluetooth** | liaison de secours | à la première utilisation |

> L'autorisation Accessibilité est liée à l'**emplacement du bundle** :
> déplacer l'app remet l'autorisation à zéro.

## ⏳ La limite des 7 jours

Avec un compte Apple **gratuit**, une signature vaut **7 jours**. Passé ce
délai, l'app cesse de s'ouvrir. Ce n'est pas une panne : c'est la règle d'Apple.

```bash
./reinstall.sh --install
```

pose un agent `launchd` qui réinstalle tout seul tous les 6 jours. L'iPhone
doit être branché à ce moment-là ; sinon la tentative échoue sans dégât et
recommence au cycle suivant.

**L'app macOS vous prévient trois jours avant.** Elle lit la date d'expiration
du profil iOS dans le dossier d'Xcode, et propose deux boutons :

| Bouton | Effet |
|---|---|
| **Renouveler maintenant** | Relance `./reinstall.sh --all` dans le Terminal |
| **Automatiser tous les 6 jours** | Pose l'agent `launchd`, sans ligne de commande |

## Mises à jour

À l'ouverture, les deux apps interrogent **une fois par jour** les versions
publiées sur GitHub. Un bandeau n'apparaît que s'il y a réellement plus récent.
La vérification lit une page publique : elle n'envoie rien.

Pour mettre à jour : `git pull` puis `./reinstall.sh --all`.

Un compte payant (99 €/an) lève cette limite et permet la notarisation. Ce
n'est nécessaire que pour **distribuer** l'app à d'autres.

---

Suite : [[Premier appairage|Premier-appairage]]
