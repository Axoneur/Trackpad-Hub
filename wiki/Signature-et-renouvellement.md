# Signature et renouvellement

## La réponse courte

**Vous n'avez rien à signer. Il n'existe aucune manipulation de signature.**

Elle se fait toute seule, à chaque fois que vous lancez `./reinstall.sh`.
C'est pour cette raison que vous ne l'avez jamais vue : il n'y a rien à voir.

---

## Ce qu'est la signature, concrètement

Apple refuse qu'un iPhone lance une app venue de nulle part. Chaque app doit
porter une preuve qu'elle a été construite par un compte identifié.

Cette preuve tient en deux morceaux :

| Morceau | Ce que c'est | Qui le fabrique |
|---|---|---|
| **Le certificat** | Votre identité de développeur | Xcode, à l'ajout de votre compte Apple |
| **Le profil** | L'autorisation d'installer cette app sur cet iPhone | Xcode, à chaque compilation |

Les deux sont créés **automatiquement** par Xcode la première fois, puis
réutilisés. Vous n'ouvrez jamais Xcode pour ça.

## Qui fait quoi, exactement

```
vous : ./reinstall.sh --all
   │
   └─► xcodebuild            (appelé par le script)
         │
         ├─► demande à Xcode un profil pour votre équipe
         ├─► signe les apps avec votre certificat
         └─► installe sur l'iPhone
```

La seule chose que vous avez fournie, c'est votre **identifiant d'équipe**,
une fois, à `./setup.sh`. Tout le reste en découle.

---

## Pourquoi ça expire au bout de 7 jours

Apple accorde deux durées de vie très différentes :

| Type de compte | Durée du profil | Prix |
|---|---|---|
| **Gratuit** | **7 jours** | 0 € |
| Payant (Apple Developer Program) | 1 an | 99 €/an |

Avec un compte gratuit, au bout de 7 jours l'app iPhone **refuse de s'ouvrir**.
Elle ne plante pas, elle ne s'efface pas : elle ne démarre plus.

> **Ce n'est pas un bug, et ce n'est pas réparable.** C'est la règle d'Apple
> pour les comptes sans abonnement.

**L'app macOS n'est pas concernée** : elle n'embarque aucun profil, seul un
certificat, qui lui ne s'épuise pas de cette façon.

---

## Renouveler : trois façons

Renouveler, c'est simplement **réinstaller**. La signature est refaite au
passage, et vous repartez pour 7 jours.

### 1. Ne plus jamais y penser — recommandé

Dans l'app **macOS**, quand l'avertissement apparaît :

> **[ Automatiser tous les 6 jours ]**

Un agent système réinstalle tout seul, tous les 6 jours, sans rien vous
demander. La seule condition : **l'iPhone doit être branché** au moment où ça
se déclenche. S'il ne l'est pas, la tentative échoue sans dégât et recommence
au cycle suivant.

L'équivalent en ligne de commande :

```bash
./reinstall.sh --install
```

### 2. En un clic, quand l'app prévient

L'app macOS lit la date d'expiration et affiche, **3 jours avant** :

> **L'app iPhone expire dans 3 jours**
> [ Renouveler maintenant ] [ Automatiser tous les 6 jours ]

**Renouveler maintenant** ouvre le Terminal et relance l'installation. Vous
voyez la compilation défiler, elle dure deux à trois minutes.

### 3. À la main, quand vous voulez

Branchez l'iPhone, déverrouillez-le, puis dans le dossier du projet :

```bash
./reinstall.sh --all
```

---

## Être prévenu sans y penser

Les deux apps envoient de vraies notifications à trois moments : **J-3**,
**J-1**, et le jour de l'expiration.

| Quand | Mac | iPhone |
|---|---|---|
| 3 jours avant | « L'app iPhone expire dans 3 jours » | « TrackPad Hub expire dans 3 jours » |
| La veille | « L'app iPhone expire demain » | « TrackPad Hub expire demain » |
| Le jour même | « L'app iPhone a expiré » | « TrackPad Hub a expiré » |

**Pourquoi trois paliers et pas un rappel quotidien.** Une notification qui
répète la même chose chaque jour finit désactivée au bout de trois jours — et
l'avertissement vraiment utile, celui de la veille, n'est alors jamais lu.
Chaque palier n'est annoncé qu'une fois.

**Pourquoi l'iPhone programme à l'avance.** Une fois la signature expirée,
l'app ne s'ouvre plus : au moment où l'avertissement serait le plus utile, elle
n'est plus là pour l'émettre. Elle dépose donc ses trois avertissements dès le
lancement, tant qu'elle fonctionne encore. iOS les délivre même si l'app ne
s'ouvre plus. Ils sont reprogrammés à chaque lancement, puisqu'une
réinstallation repousse la date.

**Le Mac relit la date toutes les heures.** Une app de bureau reste ouverte des
jours ; sans cette relecture, la date lue au lancement resterait figée et le
palier « expire demain » ne serait jamais franchi.

### Si vous ne recevez rien

Un refus des notifications est définitif du point de vue de l'app : macOS ne
réaffiche jamais l'alerte de demande. L'app macOS le détecte et affiche une
carte **« Notifications désactivées »** avec un bouton **Ouvrir les Réglages**.

Sur l'iPhone : Réglages → Notifications → TrackPad Hub.

---

## Vérifier combien de temps il reste

`./reinstall.sh` l'annonce à la fin de chaque installation, avec la date
réelle lue dans le profil :

```
Terminé — l'app iPhone fonctionne jusqu'au mardi 18 août à 12h25
          soit encore 4 jour(s).
```

> **Relancer le script ne repousse pas toujours l'échéance.** Apple ne délivre
> un profil neuf que lorsque l'ancien approche de sa fin ; entre-temps Xcode
> réutilise celui qui existe et la date ne bouge pas. C'est normal.

L'app macOS l'affiche aussi quand l'échéance approche. Pour le savoir à tout
moment :

```bash
for f in ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision; do
  security cms -D -i "$f" 2>/dev/null | grep -A1 ExpirationDate | tail -1
done
```

---

## Questions fréquentes

### Faut-il ouvrir Xcode à chaque fois ?

Non. Jamais. Une seule fois, à l'installation, pour y ajouter votre compte
Apple. Ensuite `reinstall.sh` fait tout.

### Faut-il refaire l'appairage après un renouvellement ?

Non. Le jeton d'appairage vit dans le trousseau et survit à la réinstallation.

### Perd-on ses réglages, macros, statistiques ?

Non. La réinstallation remplace l'app, pas ses données.

### L'iPhone doit-il être branché ?

Oui, pour l'installation. Une fois installée, l'app fonctionne en Wi-Fi et en
Bluetooth sans câble.

### Et si je paie les 99 € ?

Le profil vaut alors un an au lieu de 7 jours, et vous pouvez distribuer l'app
à d'autres personnes. Pour un usage personnel, l'automatisation tous les
6 jours revient au même sans rien payer.
