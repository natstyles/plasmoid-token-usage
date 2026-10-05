/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import org.kde.notification
import org.kde.plasma.plasma5support as P5Support

// Gestor de notificaciones y sonidos
Item {
    id: notifier


    readonly property string defaultAlertSound: "/usr/share/sounds/ocean/stereo/dialog-warning.oga"
    readonly property string defaultResetSound: "/usr/share/sounds/ocean/stereo/completion-success.oga"

    property int playCount: 0

    function localPath(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
    }

    function soundPath(value, fallback) {
        if (value === "none") return ""
        return localPath(value || fallback)
    }


    function send(kind, title, text, icon, sound, critical) {
        const notification = notificationComponent.createObject(notifier, {
            eventId: kind,
            title: title,
            text: text,
            iconName: icon.startsWith("file:") || icon.startsWith("/") ? localPath(icon) : icon,
            urgency: critical ? Notification.HighUrgency : Notification.NormalUrgency
        })
        notification.sendEvent()
        play(soundPath(sound, kind === "reset" ? defaultResetSound : defaultAlertSound))
    }

    function play(path) {
        if (!path) return
        const quoted = "'" + path.replace(/'/g, "'\\''") + "'"
        // Identificador único de reproducción
        player.connectSource("pw-play " + quoted + " 2>/dev/null || paplay " + quoted + " #" + (++playCount))
    }

    Component {
        id: notificationComponent
        Notification {
            componentName: "aiusage"
            autoDelete: true
        }
    }

    P5Support.DataSource {
        id: player
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }
}
