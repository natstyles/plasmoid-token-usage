/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property var providers: []
    property var lastUpdate: null
    property string errorText: ""
    property bool loading: false
    property real now: Date.now()

    // Estado anterior de los límites
    property var lastWindows: ({})
    property var resetRefreshed: ({})

    readonly property var cfg: Plasmoid.configuration
    readonly property string scriptPath: decodeURIComponent(Qt.resolvedUrl("../code/aiusage.py").toString().replace(/^file:\/\//, ""))

    function accentFor(id) {
        if (id === "claude") return cfg.colorClaude
        if (id === "chatgpt") return cfg.colorChatGPT
        if (id === "gemini") return cfg.colorGemini
        return Kirigami.Theme.highlightColor
    }

    function logoFor(id) {
        const custom = id === "claude" ? cfg.logoClaude : id === "chatgpt" ? cfg.logoChatGPT : id === "gemini" ? cfg.logoGemini : ""
        return custom || Qt.resolvedUrl("../images/" + id + ".svg").toString()
    }

    function enabledProviders() {
        const ids = []
        if (cfg.showClaude) ids.push("claude")
        if (cfg.showChatGPT) ids.push("chatgpt")
        if (cfg.showGemini) ids.push("gemini")
        return ids
    }

    function windowLabel(w) {
        if (w.label_id === "session") return i18n("Session (%1 h)", w.label_args.hours)
        if (w.label_id === "weekly") return i18n("Weekly")
        if (w.label_id === "weekly_model") return i18n("Weekly · %1", w.label_args.model)
        if (w.label_id === "daily") return i18n("Daily")
        if (w.label_id === "model_group") return i18n("Session · %1", w.label_args.families.join(" / "))
        return w.label
    }

    // Traduce el error que manda el backend (error_id). No puede llamarse errorText:
    // en QML la propiedad errorText taparía la función y no se podría llamar.
    function providerErrorText(id, args, fallback) {
        args = args || {}
        if (id === "claude_not_logged_in") return i18n("Log in to Claude Code (no ~/.claude/.credentials.json found)")
        if (id === "claude_no_oauth") return i18n("Claude Code does not have an OAuth token (API key session?)")
        if (id === "claude_session_expired") return i18n("Claude Code session has expired: log in again")
        if (id === "claude_no_refresh_token") return i18n("Token expired and no refresh token available")
        if (id === "claude_token_expired_running") return i18n("Token expired: Claude Code is running and will refresh it")
        if (id === "claude_refresh_failed") return i18n("Failed to refresh Claude token")
        if (id === "codex_not_logged_in") return i18n("Codex is not logged into ChatGPT")
        if (id === "codex_not_installed") return i18n("Install Codex CLI and log in with your ChatGPT account")
        if (id === "codex_no_data") return i18n("No ChatGPT data (%1). Use Codex once to generate it", args.detail)
        if (id === "antigravity_not_running") return i18n("Open Antigravity to read Gemini quota")
        if (id === "antigravity_no_response") return i18n("Antigravity server did not respond")
        if (id === "antigravity_no_quotas") return i18n("Antigravity returned no model quotas")
        if (id === "unexpected") return i18n("Unexpected error: %1", args.detail)
        return fallback
    }

    function refresh() {
        const ids = enabledProviders()
        if (ids.length === 0) {
            providers = []
            return
        }
        loading = true
        executable.connectSource("python3 '" + scriptPath + "' --hours " + cfg.historyHours + " " + ids.join(" "))
    }

    function countdown(epoch) {
        let s = Math.max(0, Math.floor(epoch - Date.now() / 1000))
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (h >= 24) return i18n("%1 d %2 h", Math.floor(h / 24), h % 24)
        return h > 0 ? i18n("%1 h %2 min", h, m) : i18n("%1 min", m)
    }

    // Comprueba umbrales y reinicios de cuota
    function checkAlerts(list) {
        const previous = lastWindows
        const next = {}
        const nowSec = Date.now() / 1000
        for (const p of list) {
            if (!p.ok) continue
            for (const w of p.windows) {
                if (w.percent === null) continue
                const key = p.id + "|" + w.label
                next[key] = { percent: w.percent, resets_at: w.resets_at }
                const old = previous[key]
                if (!old || !cfg.notifyEnabled) continue

                const reset = old.percent > 0 && w.percent < old.percent
                    && old.resets_at && nowSec >= old.resets_at - 60
                const remaining = w.resets_at ? i18n(" Resets in %1.", countdown(w.resets_at)) : ""
                if (reset) {
                    if (cfg.notifyReset)
                        notifier.send("reset", i18n("%1: tokens reloaded", p.name),
                            i18n("%1 has been reset. You are now at %2 %.", root.windowLabel(w), Math.round(w.percent)),
                            logoFor(p.id), cfg.resetSound, false)
                } else if (cfg.notifyCrit && old.percent < cfg.critThreshold && w.percent >= cfg.critThreshold) {
                    notifier.send("threshold", i18n("%1: %2 % · %3", p.name, Math.round(w.percent), root.windowLabel(w)),
                        i18n("You have reached the critical threshold (%1 %).", cfg.critThreshold) + remaining,
                        logoFor(p.id), cfg.alertSound, true)
                } else if (cfg.notifyWarn && old.percent < cfg.warnThreshold && w.percent >= cfg.warnThreshold
                           && w.percent < cfg.critThreshold) {
                    notifier.send("threshold", i18n("%1: %2 % · %3", p.name, Math.round(w.percent), root.windowLabel(w)),
                        i18n("You have reached the warning threshold (%1 %).", cfg.warnThreshold) + remaining,
                        logoFor(p.id), cfg.alertSound, false)
                }
            }
        }
        lastWindows = next
    }

    // Recarga al vencer una cuota
    function refreshIfResetDue() {
        const nowSec = Date.now() / 1000
        for (const key in lastWindows) {
            const w = lastWindows[key]
            const id = key + "@" + w.resets_at
            if (w.percent > 0 && w.resets_at && nowSec >= w.resets_at + 30 && !resetRefreshed[id]) {
                resetRefreshed[id] = true
                refresh()
                return
            }
        }
    }

    function updatedText() {
        if (!lastUpdate) return ""
        const minutes = Math.floor((now - lastUpdate.getTime()) / 60000)
        if (minutes < 1) return i18n("Updated just now")
        if (minutes < 60) return i18np("Updated 1 min ago", "Updated %1 min ago", minutes)
        return i18nc("Updated at [time]", "Updated at %1", Qt.formatTime(lastUpdate, "HH:mm"))
    }

    function tooltipText() {
        if (errorText) return errorText
        return providers.map(p => {
            if (!p.ok) return p.name + ": " + root.providerErrorText(p.error_id, p.error_args, p.error)
            return p.name + ": " + p.windows
                .filter(w => cfg.showWeekly || w.kind !== "weekly")
                .map(w => root.windowLabel(w) + " " + Math.round(w.percent) + " %").join(" · ")
        }).join("\n")
    }

    toolTipMainText: i18n("Token Usage")
    toolTipSubText: tooltipText()
    Plasmoid.icon: "io.github.natstyles.aiusage"

    Component.onCompleted: {
        const pkg = Qt.resolvedUrl("..").toString().replace(/^file:\/\//, "")
        const quotedPkg = "'" + pkg.replace(/'/g, "'\\''") + "'"
        const cmd = `mkdir -p "\${XDG_DATA_HOME:-\$HOME/.local/share}/knotifications6" && cp ${quotedPkg}notifications/aiusage.notifyrc "\${XDG_DATA_HOME:-\$HOME/.local/share}/knotifications6/" && mkdir -p "\${XDG_DATA_HOME:-\$HOME/.local/share}/icons/hicolor/scalable/apps" && cp ${quotedPkg}icons/io.github.natstyles.aiusage.svg "\${XDG_DATA_HOME:-\$HOME/.local/share}/icons/hicolor/scalable/apps/"`
        initExec.connectSource(cmd)
    }

    P5Support.DataSource {
        id: initExec
        engine: "executable"
        connectedSources: []
        onNewData: source => disconnectSource(source)
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: (source, data) => {
            disconnectSource(source)
            root.loading = false
            try {
                const list = JSON.parse(data["stdout"]).providers
                root.checkAlerts(list)
                root.providers = list
                root.lastUpdate = new Date()
                root.now = Date.now()
                root.errorText = ""
            } catch (e) {
                root.errorText = data["stderr"] || i18n("Could not read response: %1", e)
            }
        }
    }

    Timer {
        interval: Math.max(1, root.cfg.refreshMinutes) * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Actualización de temporizadores locales
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            root.now = Date.now()
            root.refreshIfResetDue()
        }
    }

    Notifier {
        id: notifier
    }

    Connections {
        target: Plasmoid.configuration
        function onShowClaudeChanged() { root.refresh() }
        function onShowChatGPTChanged() { root.refresh() }
        function onShowGeminiChanged() { root.refresh() }
        function onHistoryHoursChanged() { root.refresh() }
    }

    compactRepresentation: MouseArea {
        id: compact

        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

        Layout.minimumWidth: vertical ? 0 : view.implicitWidth
        Layout.minimumHeight: vertical ? view.implicitHeight : 0
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        CompactView {
            id: view
            anchors.fill: parent
            providers: root.providers
            vertical: compact.vertical
            style: root.cfg.compactStyle
            metric: root.cfg.compactMetric
            showWeekly: root.cfg.showWeekly
            byLevel: root.cfg.colorByLevel
            warn: root.cfg.warnThreshold
            crit: root.cfg.critThreshold
            accentFor: id => root.accentFor(id)
            logoFor: id => root.logoFor(id)
        }
    }

    fullRepresentation: ColumnLayout {
        // Ajuste de dimensión del popup
        readonly property real configuredWidth: Kirigami.Units.gridUnit * root.cfg.popupWidth
        Layout.preferredWidth: configuredWidth
        Layout.minimumWidth: configuredWidth
        Layout.maximumWidth: configuredWidth
        Layout.minimumHeight: implicitHeight
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            ColumnLayout {
                spacing: 0
                Kirigami.Heading {
                    text: i18n("Token Usage")
                    level: 2
                }
                PC3.Label {
                    text: root.updatedText()
                    visible: text !== ""
                    opacity: 0.6
                    font: Kirigami.Theme.smallFont
                }
            }
            Item {
                Layout.fillWidth: true
            }
            PC3.BusyIndicator {
                visible: root.loading
                running: visible
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
            }
            PC3.ToolButton {
                visible: !root.loading
                icon.name: "view-refresh"
                onClicked: root.refresh()
                PC3.ToolTip.text: i18n("Refresh now")
                PC3.ToolTip.visible: hovered
            }
            PC3.ToolButton {
                icon.name: "configure"
                onClicked: Plasmoid.internalAction("configure").trigger()
                PC3.ToolTip.text: i18n("Configure")
                PC3.ToolTip.visible: hovered
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.errorText !== ""
            type: Kirigami.MessageType.Error
            text: root.errorText
        }

        PC3.Label {
            visible: root.providers.length === 0 && !root.loading && root.errorText === ""
            text: i18n("Enable at least one provider in the widget settings.")
            wrapMode: Text.Wrap
            opacity: 0.7
            Layout.fillWidth: true
        }

        Repeater {
            model: root.providers

            delegate: ProviderCard {
                required property var modelData
                provider: modelData
                accent: root.accentFor(modelData.id)
                logo: root.logoFor(modelData.id)
                now: root.now
                popupStyle: root.cfg.popupStyle
                cardBackground: root.cfg.cardBackground
                showWeekly: root.cfg.showWeekly
                showResetDate: root.cfg.showResetDate
                byLevel: root.cfg.colorByLevel
                warn: root.cfg.warnThreshold
                crit: root.cfg.critThreshold
                showHistory: root.cfg.showHistory
                showBreakdown: root.cfg.showBreakdown
                historyHours: root.cfg.historyHours
                windowLabelFn: root.windowLabel
                errorTextFn: root.providerErrorText
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
