#!/usr/bin/env bash
# Instalación del plasmoide
set -euo pipefail
cd "$(dirname "$0")"

# Notificaciones de KDE
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/knotifications6"
cp package/contents/notifications/aiusage.notifyrc "${XDG_DATA_HOME:-$HOME/.local/share}/knotifications6/"

# Icono del widget (metadata.json lo pide por nombre: Plasma no carga iconos por ruta)
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
cp package/contents/icons/io.github.natstyles.aiusage.svg "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps/"

if kpackagetool6 -t Plasma/Applet -s org.kde.plasma.aiusage >/dev/null 2>&1; then
    echo "¡Atención! El identificador antiguo 'org.kde.plasma.aiusage' está instalado."
    echo "Debes quitarlo del panel y desinstalarlo con:"
    echo "  kpackagetool6 -t Plasma/Applet -r org.kde.plasma.aiusage"
    echo "Se va a instalar la versión nueva."
fi

if kpackagetool6 -t Plasma/Applet -s io.github.natstyles.aiusage >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet -u package
    echo "Actualizado. Reinicia Plasma para ver los cambios: systemctl --user restart plasma-plasmashell"
else
    kpackagetool6 -t Plasma/Applet -i package
    echo "Instalado. Añádelo con clic derecho en el panel → Añadir widgets → \"Token Usage\"."
fi
