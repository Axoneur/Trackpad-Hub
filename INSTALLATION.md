# Installer et tester TrackPad Hub

Guide complet, de zéro à l'app qui fonctionne sur votre iPhone.
Comptez **20 minutes** la première fois.

Il y a **deux apps à installer** : celle du Mac, et celle de l'iPhone.
Les deux doivent tourner en même temps pour que quoi que ce soit fonctionne.

---

## Avant de commencer

| À vérifier | Comment |
|---|---|
| Xcode est installé | Il doit apparaître dans le Launchpad ou `/Applications` |
| Votre compte Apple est dans Xcode | Xcode → Settings (⌘ virgule) → Accounts : votre nom doit y figurer |
| L'iPhone et le Mac sont sur le même Wi-Fi | Même réseau des deux côtés, pas un partage de connexion |
| Un câble USB pour l'iPhone | Le premier transfert passe par le câble, pas par le Wi-Fi |

---

## Étape 1 — Installer l'app du Mac

Ouvrez le Terminal et collez cette ligne :

```bash
cd "/Users/timeo/Documents/Default Project/TrackPadHub" && ./reinstall.sh --mac
```

**Ce que vous devez voir :** des lignes de compilation, puis `App macOS réinstallée dans /Applications`.
L'app s'ouvre toute seule, et une petite icône de souris apparaît **en haut à droite de votre écran**, dans la barre des menus.

> **Si ça échoue** — le message d'erreur indique la cause. Copiez-le-moi.

---

## Étape 2 — Autoriser le Mac à être contrôlé

Sans cette autorisation, le curseur ne bougera jamais. C'est la cause n°1 des « ça ne marche pas ».

1. Dans la fenêtre de TrackPad Hub, cliquez sur **« Accorder l'accès »**.
2. macOS ouvre les Réglages Système sur la bonne page.
3. Cochez **TrackPad Hub** dans la liste.
4. Si on vous demande votre mot de passe, saisissez-le.

**Vérification :** revenez à la fenêtre de TrackPad Hub. La ligne doit être passée à
**« Accès Accessibilité accordé »** avec une coche verte. C'est automatique, sans redémarrer l'app.

---

## Étape 3 — Vérifier que vous avez bien la dernière version

Cette étape évite de chercher pendant une heure un bug déjà corrigé.

1. En bas de la fenêtre du Mac, cliquez sur **« Diagnostic clavier… »**.
2. Regardez la ligne **« Version compilée le … »**.
3. La date doit être **celle d'aujourd'hui**.

Si la date est ancienne, c'est qu'une vieille copie tourne encore : quittez l'app par la barre
des menus, puis refaites l'étape 1.

---

## Étape 4 — Installer l'app sur l'iPhone

1. **Branchez l'iPhone au Mac en USB.**
2. **Déverrouillez l'iPhone** et laissez l'écran allumé.
3. Si l'iPhone demande **« Se fier à cet ordinateur ? »**, touchez **Se fier** et saisissez votre code.
4. Dans le Terminal :

```bash
cd "/Users/timeo/Documents/Default Project/TrackPadHub" && ./reinstall.sh
```

**Ce que vous devez voir :** `iPhone trouvé : …`, puis la compilation, puis `Terminé`.

> **Si vous voyez « Aucun iPhone détecté »** — le script vous liste ce que le système voit.
> Le plus souvent : l'iPhone est verrouillé, ou vous n'avez pas touché « Se fier ».

### Si vous voyez `ApplicationVerificationFailed`

C'est la **limite du compte Apple gratuit** : Apple n'autorise que **3 apps signées
gratuitement installées à la fois** sur un iPhone. TrackPad Hub en consomme 3 à lui seul —
l'app, le clavier système et les widgets sont trois programmes distincts aux yeux d'Apple.

Trois solutions, de la plus simple à la plus radicale :

1. **Faites de la place.** Supprimez de l'iPhone les autres apps installées depuis Xcode ou
   un outil de sideloading, **y compris une ancienne version de TrackPad Hub**.
   Appui long sur l'icône → Supprimer l'app. Puis relancez `./reinstall.sh`.

2. **Installez la version allégée**, sans clavier système ni widgets. Le trackpad, le clavier
   de l'app, le média, les apps du Mac, le transfert de fichiers et tout le reste fonctionnent :

   ```bash
   cd "/Users/timeo/Documents/Default Project/TrackPadHub" && ./reinstall.sh --lite
   ```

3. **Passez au compte Apple Developer payant** (99 €/an), qui lève la limite.

---

## Étape 5 — Autoriser l'app sur l'iPhone

L'app est installée mais iOS refuse encore de l'ouvrir. C'est normal avec un compte Apple gratuit.

1. Sur l'iPhone : **Réglages** → **Général** → **VPN et gestion de l'appareil**.
2. Touchez votre compte développeur (votre adresse e-mail).
3. Touchez **« Se fier à … »**, puis confirmez.

L'app TrackPad Hub s'ouvre maintenant normalement depuis l'écran d'accueil.

---

## Étape 6 — Relier les deux appareils

1. Ouvrez **TrackPad Hub** sur l'iPhone.
2. Acceptez la demande d'**accès au réseau local** — sans elle, l'iPhone ne trouvera jamais le Mac.
3. Un **QR code** et un **code à 6 chiffres** s'affichent sur le Mac.
4. Sur l'iPhone, l'écran d'appairage apparaît : pointez la caméra vers le QR code.
   Ou touchez **« Saisir le code »** et tapez les 6 chiffres.

**Vérification :** la pastille en haut de l'écran iPhone passe au **vert**.

Cet appairage n'est demandé **qu'une seule fois**. Les fois suivantes, la connexion est automatique.

---

## Étape 7 — Tester, dans cet ordre

Testez du plus fondamental au plus accessoire. Si le premier échoue, les suivants échoueront aussi.

| # | Test | Résultat attendu |
|---|---|---|
| 1 | Un doigt qui glisse sur la grande surface | Le curseur du Mac bouge |
| 2 | Un doigt, appui bref | Clic gauche |
| 3 | Deux doigts qui glissent | La page défile |
| 4 | **Deux doigts, appui bref** | Menu contextuel — **pas** deux clics gauches |
| 5 | Double appui rapide sur un fichier du Finder | Le fichier s'ouvre |
| 6 | Trois doigts qui glissent sur une fenêtre | La fenêtre se déplace |
| 7 | Onglet Clavier : écrire du texte, puis « envoyer » | Le texte apparaît sur le Mac |
| 8 | Onglet Clavier : taper « é à ç » | Les accents passent |
| 9 | **Onglet Clavier : ⌘ puis A**, dans un document | Tout se sélectionne — **l'app ne doit pas quitter** |
| 10 | Onglet Mac | Batterie, processeur, mémoire s'affichent |
| 11 | Onglet Mac → Envoyer un fichier → Photos | Le fichier arrive dans Téléchargements › TrackPad Hub |

**Pour le test 9**, gardez le **Diagnostic clavier** ouvert sur le Mac : chaque frappe s'y affiche
avec une pastille verte si la touche envoyée produit bien le caractère demandé, rouge sinon.

---

## Étape 8 — Ne plus jamais réinstaller à la main

Un compte Apple gratuit signe l'app pour **7 jours**. Passé ce délai, elle refuse de s'ouvrir.

```bash
cd "/Users/timeo/Documents/Default Project/TrackPadHub" && ./reinstall.sh --install
```

Le Mac recompile et réinstalle tout seul **tous les 6 jours**, un jour avant l'expiration.
L'iPhone doit être branché à ce moment-là ; sinon le script réessaie au cycle suivant.

Pour arrêter : `./reinstall.sh --uninstall`.

---

## Les commandes, en résumé

| Commande | Effet |
|---|---|
| `./reinstall.sh --mac` | App macOS uniquement, installée dans `/Applications` et lancée |
| `./reinstall.sh` | App iPhone uniquement |
| `./reinstall.sh --lite` | App iPhone sans le clavier système ni les widgets |
| `./reinstall.sh --all` | Les deux |
| `./reinstall.sh --install` | Planifie la réinstallation tous les 6 jours |
| `./reinstall.sh --uninstall` | Retire la planification |

---

## Retrouver les fonctionnalités

Plusieurs d'entre elles ne sont pas dans les onglets principaux.
**Réglages → Fonctionnalités** liste tout, avec l'état de chacune et l'endroit exact où la trouver.

| Fonctionnalité | Où |
|---|---|
| Souris gyroscopique | Onglet Trackpad, icône de main dans la barre du bas |
| Vitesses du curseur | Onglet Trackpad, icône de compteur |
| Touches F1 à F12 | Onglet Clavier, section « Touches de fonction », bouton Afficher |
| Dictée vocale | Onglet Clavier, bouton micro |
| Presse-papiers partagé | Onglet Clavier, sous le champ de texte |
| Liste complète des apps | Onglet Mac → « Tout voir » |
| Transfert de fichiers | Onglet Mac → « Envoyer un fichier » |
| Raccourcis | Onglet Mac → « Raccourcis » |
| Mode présentation | Onglet Média, en bas |
| Tutoriels | Réglages → Aide et tutoriels |

**Hors de l'app**, à activer vous-même :

- **Widgets** : écran d'accueil → appui long → Modifier → Ajouter un widget → TrackPad Hub
- **Raccourcis Siri** : app Raccourcis, ou « Dis Siri, verrouille mon Mac »
- **Clavier système** : Réglages iOS → Général → Clavier → Claviers → Ajouter un clavier

---

## En cas de problème

| Symptôme | Cause la plus fréquente |
|---|---|
| Le curseur ne bouge pas | Autorisation Accessibilité non accordée (étape 2) |
| « Recherche du Mac… » sans fin | Pas le même Wi-Fi, ou app macOS fermée |
| Aucun code sur le Mac | Le Mac ne demande un code que pour un appareil inconnu. Utilisez « Oublier » dans la barre des menus |
| Une fonctionnalité manque | L'app installée date d'avant : refaites l'étape 4 |
| Un comportement corrigé revient | Version ancienne : vérifiez la date à l'étape 3 |
| L'app ne s'ouvre plus après une semaine | Profil expiré : refaites l'étape 4, ou automatisez (étape 8) |
| Le défilement part à l'envers | Réglages → Trackpad → Défilement naturel |
