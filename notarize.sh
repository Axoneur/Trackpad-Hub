#!/bin/sh
# Compile, signe et notarise l'app macOS pour une distribution hors App Store.
#
# Prérequis :
#   · un compte Apple Developer payant (99 €/an) — la notarisation n'est pas
#     possible avec un compte gratuit ;
#   · un certificat « Developer ID Application » dans le trousseau ;
#   · un profil de mot de passe stocké une fois pour toutes :
#       xcrun notarytool store-credentials "trackpadhub" \
#           --apple-id VOTRE@EMAIL --team-id VOTRE_TEAM_ID \
#           --password MOT_DE_PASSE_APPLICATION
#
# Usage : ./notarize.sh "Developer ID Application: Nom (TEAMID)"
set -e
cd "$(dirname "$0")"

IDENTITY="$1"
PROFILE="${2:-trackpadhub}"
BUILD_DIR="build/notarize"

if [ -z "$IDENTITY" ]; then
    echo "Usage : ./notarize.sh \"Developer ID Application: Nom (TEAMID)\" [profil-notarytool]"
    echo ""
    echo "Identités disponibles :"
    security find-identity -v -p codesigning | grep "Developer ID Application" || \
        echo "  (aucune — il en faut une pour distribuer hors App Store)"
    exit 1
fi

echo "▸ Compilation…"
rm -rf "$BUILD_DIR"
xcodebuild -project TrackPadHub.xcodeproj \
           -scheme MacHost \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           CODE_SIGN_IDENTITY="$IDENTITY" \
           CODE_SIGN_STYLE=Manual \
           build

APP="$BUILD_DIR/Build/Products/Release/MacHost.app"
[ -d "$APP" ] || { echo "App introuvable : $APP"; exit 1; }

echo "▸ Vérification de la signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

# Le hardened runtime est requis pour la notarisation ; sans lui, l'étape
# suivante échoue avec « The executable does not have the hardened runtime
# enabled ».
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q "disable-library-validation" || \
    echo "  (avertissement : entitlement library-validation absent, MediaRemote risque de ne pas charger)"

echo "▸ Archive ZIP…"
ZIP="$BUILD_DIR/TrackPadHub.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "▸ Notarisation (peut prendre quelques minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "▸ Agrafage du ticket…"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo ""
echo "Terminé : $APP"
echo "L'app peut être distribuée : elle s'ouvrira sans avertissement Gatekeeper."
