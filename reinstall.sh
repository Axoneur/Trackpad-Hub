#!/bin/bash
# Recompile et réinstalle TrackPad Hub sur l'iPhone branché.
#
# Un compte Apple gratuit signe pour 7 jours seulement : au-delà, l'app refuse
# de s'ouvrir. Ce script refait le cycle complet sans passer par l'interface
# de Xcode. À lancer une fois par semaine, ou à planifier (voir --install).
#
#   ./reinstall.sh              réinstalle sur l'iPhone branché
#   ./reinstall.sh --mac        réinstalle l'app macOS uniquement
#   ./reinstall.sh --all        les deux
#   ./reinstall.sh --lite       iPhone, sans le clavier ni les widgets
#   ./reinstall.sh --install    planifie une exécution automatique hebdomadaire
#   ./reinstall.sh --uninstall  retire la planification


# Configuration locale : équipe de signature et préfixe d'identifiant.
# XcodeGen les lit dans l'environnement (voir project.yml).
CONF="$(cd "$(dirname "$0")" && pwd)/trackpadhub.conf"
if [ -f "$CONF" ]; then
    # shellcheck source=/dev/null
    . "$CONF"
else
    echo "Configuration absente. Lancez d'abord ./setup.sh" >&2
    exit 1
fi

set -euo pipefail
cd "$(dirname "$0")"

PROJECT="TrackPadHub.xcodeproj"
BUILD_DIR="build/reinstall"
LABEL="com.trackpadhub.reinstall"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/TrackPadHub-reinstall.log"

# ---------------------------------------------------------------- planification

install_schedule() {
    mkdir -p "$(dirname "$PLIST")" "$(dirname "$LOG")"
    cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(pwd)/reinstall.sh</string>
    </array>
    <!-- Tous les 6 jours plutôt que 7 : une marge avant l'expiration. -->
    <key>StartInterval</key>
    <integer>518400</integer>
    <!-- Rattrape l'exécution si le Mac dormait à l'heure prévue. -->
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
</dict>
</plist>
PLISTEOF

    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load "$PLIST"
    echo "Planification installée : réinstallation tous les 6 jours."
    echo "Journal : $LOG"
    echo ""
    echo "L'iPhone doit être branché au moment de l'exécution. Si ce n'est pas"
    echo "le cas, le script échoue sans conséquence et retentera au cycle suivant."
    exit 0
}

uninstall_schedule() {
    launchctl unload "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Planification retirée."
    exit 0
}

# ------------------------------------------------------------------- app macOS

install_mac() {
    echo "Compilation de l'app macOS…"
    if ! xcodebuild -project "$PROJECT" \
                    -scheme MacHost \
                    -configuration Debug \
                    -destination 'platform=macOS' \
                    -derivedDataPath "$BUILD_DIR" \
                    -allowProvisioningUpdates \
                    build > /tmp/trackpadhub-mac.log 2>&1; then
        echo "Échec :"
        grep -E "error:" /tmp/trackpadhub-mac.log | tail -5 | sed 's/^/    /'
        exit 1
    fi

    MAC_APP="$BUILD_DIR/Build/Products/Debug/MacHost.app"
    [ -d "$MAC_APP" ] || { echo "App macOS introuvable après compilation."; exit 1; }

    # L'app installée s'appelle « TrackPad Hub.app » mais son exécutable
    # « MacHost » : chercher « MacHost.app » ne correspondait à rien, l'ancienne
    # version restait en mémoire et `open` se contentait de l'activer. On
    # tuait donc dans le vide à chaque réinstallation.
    # `|| true` indispensable : sous `set -e`, un `pgrep` qui ne trouve rien
    # renvoie 1 et interrompt tout le script sans le moindre message.
    OLD_PID=$(pgrep -x MacHost | head -1 || true)
    if [ -n "$OLD_PID" ]; then
        kill "$OLD_PID" 2>/dev/null || true
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            pgrep -x MacHost >/dev/null || break
            sleep 0.3
        done
        pgrep -x MacHost >/dev/null && kill -9 "$OLD_PID" 2>/dev/null || true
    fi

    rm -rf "/Applications/TrackPad Hub.app"
    cp -R "$MAC_APP" "/Applications/TrackPad Hub.app"
    open -n "/Applications/TrackPad Hub.app"

    sleep 2
    NEW_PID=$(pgrep -x MacHost | head -1 || true)
    if [ -z "$NEW_PID" ]; then
        echo "App macOS installée, mais elle n'a pas démarré."
        exit 1
    fi
    if [ "$NEW_PID" = "${OLD_PID:-}" ]; then
        echo "App macOS installée, mais l'ancienne instance tourne encore (PID $NEW_PID)."
        echo "Quittez-la par la barre des menus puis relancez ce script."
        exit 1
    fi
    echo "App macOS installée et relancée (PID $NEW_PID, l'ancien était ${OLD_PID:-aucun})."
}

MODE="iphone"
case "${1:-}" in
    --install)   install_schedule ;;
    --uninstall) uninstall_schedule ;;
    --mac)       MODE="mac" ;;
    --all)       MODE="all" ;;
    --lite)      MODE="lite" ;;
esac

echo "[$(date '+%Y-%m-%d %H:%M')] Réinstallation de TrackPad Hub"

# L'app macOS d'abord : elle ne dépend pas de l'iPhone, autant qu'elle soit
# en place même si la partie iPhone échoue ensuite.
if [ "$MODE" = "mac" ] || [ "$MODE" = "all" ]; then
    install_mac
    [ "$MODE" = "mac" ] && exit 0
fi

# Identifiant de l'iPhone branché.
#
# La sortie de `devicectl` change d'une version de Xcode à l'autre : on
# extrait l'UUID par sa forme plutôt que par sa position dans la ligne.
RAW=$(xcrun devicectl list devices 2>/dev/null || true)
DEVICE=$(echo "$RAW" \
    | grep -i "iphone" \
    | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' \
    | head -1)

if [ -z "$DEVICE" ]; then
    echo ""
    echo "Aucun iPhone détecté."
    echo ""
    echo "Vérifiez, dans cet ordre :"
    echo "  1. l'iPhone est branché en USB (pas seulement en charge sans fil) ;"
    echo "  2. il est déverrouillé, écran allumé ;"
    echo "  3. vous avez touché « Se fier » sur l'iPhone au premier branchement ;"
    echo "  4. Xcode a fini de préparer l'appareil (Window > Devices and Simulators)."
    echo ""
    if [ -n "$RAW" ]; then
        echo "Ce que le système voit actuellement :"
        echo "$RAW" | sed 's/^/    /'
    fi
    exit 1
fi
echo "iPhone trouvé : $DEVICE"

echo "Compilation… (une à deux minutes la première fois)"
if ! xcodebuild -project "$PROJECT" \
                -scheme iOSApp \
                -configuration Debug \
                -destination "id=$DEVICE" \
                -derivedDataPath "$BUILD_DIR" \
                -allowProvisioningUpdates \
                build > /tmp/trackpadhub-build.log 2>&1; then
    echo ""
    echo "La compilation a échoué. Dernières erreurs :"
    grep -E "error:" /tmp/trackpadhub-build.log | tail -5 | sed 's/^/    /'
    echo ""
    echo "Journal complet : /tmp/trackpadhub-build.log"
    exit 1
fi

APP="$BUILD_DIR/Build/Products/Debug-iphoneos/iOSApp.app"
[ -d "$APP" ] || { echo "App introuvable après compilation."; exit 1; }

# Mode allégé : on retire le clavier et les widgets, puis on resigne.
#
# Un compte Apple gratuit n'autorise que 3 apps installées à la fois sur un
# appareil, et chaque extension compte pour une. L'app seule en consomme donc
# une au lieu de trois.
if [ "$MODE" = "lite" ] && [ -d "$APP/PlugIns" ]; then
    echo "Mode allégé : retrait du clavier système et des widgets…"
    rm -rf "$APP/PlugIns"
    IDENTITY=$(security find-identity -v -p codesigning \
        | grep "Apple Development" | head -1 \
        | sed -E 's/.*"(.*)"/\1/')
    if [ -z "$IDENTITY" ]; then
        echo "Aucun certificat de développement trouvé pour resigner."
        exit 1
    fi
    # Retirer un composant invalide la signature du bundle : il faut la refaire.
    codesign --force --sign "$IDENTITY" \
             --entitlements <(codesign -d --entitlements :- "$APP" 2>/dev/null) \
             "$APP" > /dev/null 2>&1 \
        || codesign --force --sign "$IDENTITY" "$APP" > /dev/null 2>&1
fi

echo "Installation sur l'iPhone…"
if ! xcrun devicectl device install app --device "$DEVICE" "$APP" > /tmp/trackpadhub-install.log 2>&1; then
    echo ""
    echo "L'installation a échoué :"
    tail -6 /tmp/trackpadhub-install.log | sed 's/^/    /'

    if grep -q "ApplicationVerificationFailed\|MIFreeProfile" /tmp/trackpadhub-install.log; then
        echo ""
        echo "─────────────────────────────────────────────────────────────"
        echo "Cause probable : limite du compte Apple gratuit."
        echo ""
        echo "Apple n'autorise que 3 apps signées gratuitement par appareil."
        echo "TrackPad Hub en consomme 3 à lui seul : l'app, le clavier"
        echo "système et les widgets."
        echo ""
        echo "Trois solutions, de la plus simple à la plus radicale :"
        echo ""
        echo "  1. Supprimez de l'iPhone les autres apps installées depuis"
        echo "     Xcode ou un outil de sideloading — y compris une ancienne"
        echo "     version de TrackPad Hub. Appui long sur l'icône, Supprimer."
        echo ""
        echo "  2. Installez la version allégée, sans clavier système ni"
        echo "     widgets. Tout le reste fonctionne :"
        echo "         ./reinstall.sh --lite"
        echo ""
        echo "  3. Passez au compte Apple Developer payant, qui lève la limite."
        echo "─────────────────────────────────────────────────────────────"
    fi
    exit 1
fi

echo ""
echo "Terminé — profils renouvelés pour 7 jours."
echo ""
echo "Si c'est la première installation, l'iPhone refusera d'ouvrir l'app."
echo "Allez dans : Réglages > Général > VPN et gestion de l'appareil,"
echo "touchez votre compte développeur, puis « Se fier »."

