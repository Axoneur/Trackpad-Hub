# Dépannage

*Quand quelque chose ne marche pas : comment le prouver plutôt que le deviner.*

## La commande qui tranche

Avant toute hypothèse, regardez ce que le Mac reçoit réellement :

```bash
/usr/bin/log stream --predicate 'subsystem == "com.trackpadhub.machost"' --info
```

| Ce que vous voyez | Ce que ça signifie |
|---|---|
| `reçu · …` puis `action · …` | L'iPhone envoie **et** le Mac exécute |
| `reçu · …` seul | Le message arrive, l'exécution échoue. Regardez la ligne `problème` |
| Rien | Rien n'arrive : le problème est sur la liaison |

> Le journal montre ce qui **change**, pas ce qui **est**. Une liaison déjà
> établie n'y apparaît pas. Pour l'état réel, regardez la pastille sur l'iPhone.

## Connexion

| Symptôme | Cause |
|---|---|
| « Recherche du Mac… » ne s'arrête pas | Même réseau Wi-Fi requis, et l'app macOS ouverte |
| Déconnexions répétées | Le Wi-Fi passe en veille. Branchez le câble : l'USB prend le relais |
| L'app ne s'ouvre plus après une semaine | Signature expirée. `./reinstall.sh --all`, ou `--install` pour automatiser |

## Curseur et clavier

| Symptôme | Cause |
|---|---|
| Le curseur ne bouge pas | Autorisation **Accessibilité** non accordée |
| Tout se met à glisser | Un clic est resté maintenu : retouchez le bouton main levée |
| Les mauvaises lettres arrivent | Choisissez la bonne disposition dans l'app macOS |
| Les bureaux et App Exposé ne font rien | Autorisation **Automatisation** refusée |

> Le WindowServer **filtre** les raccourcis de bureaux quand ils viennent d'une
> app tierce en `CGEvent`, alors qu'il laisse passer ⌘Espace. Ces quatre-là
> passent obligatoirement par System Events, donc par l'Automatisation.

## Compilation

| Message | Cause |
|---|---|
| `module name "" is not a valid identifier` | `SettingPresets/` manque à côté du binaire XcodeGen |
| `Configuration absente` | `./setup.sh` n'a pas encore été exécuté |
| Refus d'enregistrement d'App ID | Le préfixe est déjà pris. Relancez `./setup.sh` avec le vôtre |

## Vérifier qu'on teste bien la dernière version

`./reinstall.sh` affiche deux PID. **S'ils sont identiques, l'ancienne version
tourne encore.** Le panneau de diagnostic du Mac affiche aussi la date de
compilation du binaire en cours : à vérifier avant de conclure qu'un correctif
ne fonctionne pas.

## Réinitialiser une autorisation refusée

Un refus enregistré empêche toute nouvelle demande :

```bash
tccutil reset AppleEvents com.trackpadhub.machost
```
