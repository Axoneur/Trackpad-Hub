#!/bin/bash
#
# Configuration d'un clone de TrackPad Hub.
#
# Deux valeurs seulement sont propres à chaque personne : l'équipe de
# signature Apple et le préfixe d'identifiant. Ce script les demande, les
# écrit dans `trackpadhub.conf` — jamais versionné — puis génère le projet.
#
# Pourquoi c'est indispensable :
#
#   · Un App ID explicite est **unique dans tout le système d'Apple**. Les
#     identifiants du dépôt d'origine appartiennent déjà à un autre compte :
#     les réutiliser fait échouer l'enregistrement.
#   · L'équipe de signature est propre à votre identifiant Apple.
#
set -e

CONF="$(cd "$(dirname "$0")" && pwd)/trackpadhub.conf"

echo "── Configuration de TrackPad Hub ──────────────────────────────"
echo ""

# ---------------------------------------------------------------- équipe
echo "1. Équipe de signature Apple (10 caractères, ex. A1B2C3D4E5)"
echo ""
echo "   Où la trouver : Xcode > Settings > Accounts > sélectionnez votre"
echo "   identifiant Apple. L'identifiant d'équipe est affiché à droite."
echo ""
echo "   Un identifiant Apple gratuit suffit — aucun abonnement requis."
echo ""

# Aide : les certificats présents donnent une piste sur les comptes connus.
CERTS=$(security find-identity -v -p codesigning 2>/dev/null | grep "Apple Development" || true)
if [ -n "$CERTS" ]; then
    echo "   Certificats de développement trouvés sur ce Mac :"
    echo "$CERTS" | sed 's/^/     /'
    echo ""
fi

while true; do
    read -r -p "   Identifiant d'équipe : " TEAM
    TEAM=$(echo "$TEAM" | tr -d '[:space:]')
    if [ ${#TEAM} -eq 10 ]; then break; fi
    echo "   → Un identifiant d'équipe fait exactement 10 caractères. Réessayez."
done

# ---------------------------------------------------------------- préfixe
echo ""
echo "2. Préfixe d'identifiant (ex. com.votrenom)"
echo ""
echo "   Il doit vous être propre : « com.trackpadhub » est déjà enregistré"
echo "   par le dépôt d'origine et sera refusé."
echo ""

DEFAUT="com.$(whoami | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]').trackpadhub"
while true; do
    read -r -p "   Préfixe [$DEFAUT] : " PREFIX
    PREFIX=${PREFIX:-$DEFAUT}
    PREFIX=$(echo "$PREFIX" | tr -d '[:space:]')
    if [ "$PREFIX" = "com.trackpadhub" ]; then
        echo "   → Celui-là est déjà pris. Choisissez le vôtre."
        continue
    fi
    if echo "$PREFIX" | grep -qE '^[A-Za-z0-9.-]+$'; then break; fi
    echo "   → Lettres, chiffres, points et tirets uniquement."
done

# ---------------------------------------------------------------- écriture
cat > "$CONF" <<EOF
# Configuration locale de TrackPad Hub. Ne pas versionner.
# Régénérez ce fichier avec ./setup.sh
export TPH_TEAM="$TEAM"
export TPH_PREFIX="$PREFIX"
EOF

echo ""
echo "── Écrit dans trackpadhub.conf ────────────────────────────────"
echo "   Équipe  : $TEAM"
echo "   Préfixe : $PREFIX"
echo ""

# ---------------------------------------------------------------- XcodeGen
if [ ! -x "$HOME/.local/bin/xcodegen" ] && ! command -v xcodegen >/dev/null 2>&1; then
    echo "⚠️  XcodeGen est introuvable."
    echo ""
    echo "   Installez-le, puis relancez ./setup.sh :"
    echo "     git clone https://github.com/yonaskolb/XcodeGen"
    echo "     cd XcodeGen && make install PREFIX=\$HOME/.local"
    echo ""
    echo "   Attention : XcodeGen a besoin de son dossier SettingPresets/ à"
    echo "   côté du binaire. Sans lui, la compilation échoue sur"
    echo "   « module name \"\" is not a valid identifier »."
    exit 1
fi

echo "Génération du projet Xcode…"
"$(cd "$(dirname "$0")" && pwd)/generate.sh"

echo ""
echo "── Prêt ───────────────────────────────────────────────────────"
echo ""
echo "   ./reinstall.sh --mac      app macOS seule"
echo "   ./reinstall.sh --all      les deux (iPhone branché)"
echo "   ./reinstall.sh --install  réinstallation automatique tous les 6 jours"
echo ""
echo "   Rappel : avec un compte Apple gratuit, la signature expire au bout"
echo "   de 7 jours. L'app cesse alors de s'ouvrir jusqu'à réinstallation."
echo "   « --install » s'en charge tout seul."
echo ""
