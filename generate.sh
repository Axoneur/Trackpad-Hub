#!/bin/sh
# Génère le projet Xcode et l'ouvre.

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

set -e
cd "$(dirname "$0")"

# XcodeGen peut être installé via Homebrew, Mint, ou compilé depuis les
# sources dans ~/.local/bin.
XCODEGEN=""
for candidate in xcodegen "$HOME/.local/bin/xcodegen" "$HOME/.mint/bin/xcodegen"; do
    if command -v "$candidate" >/dev/null 2>&1; then
        XCODEGEN="$candidate"
        break
    fi
done

if [ -z "$XCODEGEN" ]; then
    if command -v brew >/dev/null 2>&1; then
        echo "XcodeGen absent, installation via Homebrew…"
        brew install xcodegen
        XCODEGEN=xcodegen
    else
        echo "XcodeGen est introuvable et Homebrew n'est pas installé."
        echo ""
        echo "Deux options :"
        echo "  1. Installer Homebrew puis : brew install xcodegen"
        echo "  2. Compiler XcodeGen depuis les sources :"
        echo "       git clone --depth 1 https://github.com/yonaskolb/XcodeGen.git"
        echo "       cd XcodeGen && swift build -c release --product xcodegen"
        echo "       mkdir -p ~/.local/bin && cp .build/release/xcodegen ~/.local/bin/"
        echo ""
        echo "Le fichier TrackPadHub.xcodeproj déjà présent reste utilisable"
        echo "tel quel si vous ne modifiez pas project.yml."
        exit 1
    fi
fi

"$XCODEGEN" generate
echo "Projet généré : TrackPadHub.xcodeproj"
open TrackPadHub.xcodeproj
