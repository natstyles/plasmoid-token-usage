/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

Rectangle {
    id: card

    property var provider
    property color accent
    property string logo
    property real now: Date.now()
    property int popupStyle: 0
    property bool cardBackground: true
    property bool showWeekly: true
    property bool showResetDate: true
    property bool byLevel: true
    property int warn: 70
    property int crit: 90
    property bool showHistory: true
    property bool showBreakdown: true
    property real historyHours: 168

    property var windowLabelFn
    property var errorTextFn

    readonly property int padding: Kirigami.Units.largeSpacing
    readonly property var visibleWindows: provider.ok
        ? provider.windows.filter(w => showWeekly || w.kind !== "weekly")
        : []

    function levelColor(p) {
        if (byLevel && p >= crit) return Kirigami.Theme.negativeTextColor
        if (byLevel && p >= warn) return Kirigami.Theme.neutralTextColor
        return accent
    }

    function countdown(epoch) {
        let s = Math.max(0, Math.floor(epoch - now / 1000))
        if (s === 0) return i18nc("time left until reset", "now")
        const d = Math.floor(s / 86400)
        s %= 86400
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (d > 0) return i18n("%1 d %2 h", d, h)
        if (h > 0) return i18n("%1 h %2 min", h, m)
        return i18n("%1 min", Math.max(1, m))
    }

    function resetDate(epoch) {
        return new Date(epoch * 1000).toLocaleString(Qt.locale(), "ddd d, HH:mm")
    }

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + padding * 2
    radius: Kirigami.Units.largeSpacing
    color: cardBackground ? Qt.alpha(accent, 0.07) : "transparent"
    border.width: cardBackground ? 1 : 0
    border.color: Qt.alpha(accent, 0.25)

    ColumnLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: card.padding
        }
        spacing: Kirigami.Units.largeSpacing

        // Cabecera
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 2

            ProviderLogo {
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                source: card.logo
                letter: card.provider.name.charAt(0)
                accent: card.accent
            }
            Kirigami.Heading {
                text: card.provider.name
                level: 4
                font.weight: Font.DemiBold
            }
            Rectangle {
                visible: !!card.provider.plan
                implicitWidth: planLabel.implicitWidth + Kirigami.Units.smallSpacing * 3
                implicitHeight: planLabel.implicitHeight + Kirigami.Units.smallSpacing
                radius: height / 2
                color: Qt.alpha(card.accent, 0.2)
                PC3.Label {
                    id: planLabel
                    anchors.centerIn: parent
                    text: String(card.provider.plan || "").toUpperCase()
                    color: card.accent
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    font.bold: true
                }
            }
            Item { Layout.fillWidth: true }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !card.provider.ok
            type: Kirigami.MessageType.Warning
            text: card.errorTextFn ? card.errorTextFn(card.provider.error_id, card.provider.error_args, card.provider.error) : card.provider.error || ""
        }

        PC3.Label {
            visible: !!card.provider.stale_since
            Layout.fillWidth: true
            text: i18n("Saved data (%1)", card.resetDate(card.provider.stale_since || 0))
                  + (card.provider.notice ? ". " + (card.errorTextFn ? card.errorTextFn(card.provider.notice_id, card.provider.notice_args, card.provider.notice) : card.provider.notice) : "")
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            wrapMode: Text.Wrap
        }

        GridLayout {
            Layout.fillWidth: true
            columns: card.popupStyle === 0 && card.width > Kirigami.Units.gridUnit * 19 ? 2 : 1
            rowSpacing: Kirigami.Units.largeSpacing
            columnSpacing: Kirigami.Units.largeSpacing * 2

            Repeater {
                model: card.visibleWindows

                delegate: Item {
                    id: win
                    required property var modelData
                    readonly property real percent: modelData.percent === null ? 0 : modelData.percent
                    readonly property string percentText: modelData.percent === null ? "—" : Math.round(percent) + " %"

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: card.popupStyle === 0 ? ringView.implicitHeight : barView.implicitHeight

                    HoverHandler { id: hover }
                    PC3.ToolTip.visible: hover.hovered && !!win.modelData.models
                    PC3.ToolTip.text: (win.modelData.models || []).join("\n")

                    // Anillos
                    RowLayout {
                        id: ringView
                        visible: card.popupStyle === 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Kirigami.Units.largeSpacing

                        Gauge {
                            implicitWidth: Kirigami.Units.gridUnit * 3.2
                            outerPercent: win.percent
                            accent: card.accent
                            byLevel: card.byLevel
                            warn: card.warn
                            crit: card.crit
                            thickness: 0.12
                            centerText: win.percentText
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            PC3.Label {
                                Layout.fillWidth: true
                                text: card.windowLabelFn ? card.windowLabelFn(win.modelData) : win.modelData.label
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            PC3.Label {
                                visible: !!win.modelData.resets_at
                                Layout.fillWidth: true
                                text: i18n("Resets in %1", card.countdown(win.modelData.resets_at || 0))
                                opacity: 0.8
                                elide: Text.ElideRight
                            }
                            PC3.Label {
                                visible: card.showResetDate && !!win.modelData.resets_at
                                Layout.fillWidth: true
                                text: card.resetDate(win.modelData.resets_at || 0)
                                opacity: 0.55
                                font: Kirigami.Theme.smallFont
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // Barras
                    ColumnLayout {
                        id: barView
                        visible: card.popupStyle === 1
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            PC3.Label {
                                Layout.fillWidth: true
                                text: card.windowLabelFn ? card.windowLabelFn(win.modelData) : win.modelData.label
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            PC3.Label {
                                text: win.percentText
                                color: card.levelColor(win.percent)
                                font.bold: true
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Kirigami.Units.smallSpacing * 2
                            radius: height / 2
                            color: Qt.alpha(card.accent, 0.18)
                            Rectangle {
                                width: Math.max(height, parent.width * Math.min(win.percent, 100) / 100)
                                visible: win.percent > 0
                                height: parent.height
                                radius: parent.radius
                                color: card.levelColor(win.percent)
                            }
                        }
                        PC3.Label {
                            visible: !!win.modelData.resets_at
                            Layout.fillWidth: true
                            text: i18n("Resets in %1", card.countdown(win.modelData.resets_at || 0))
                                  + (card.showResetDate ? " · " + card.resetDate(win.modelData.resets_at || 0) : "")
                            opacity: 0.7
                            font: Kirigami.Theme.smallFont
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        UsageBreakdown {
            visible: card.showBreakdown && card.provider.ok && !!card.provider.breakdown
            Layout.fillWidth: true
            breakdownData: card.provider.breakdown || null
        }

        HistoryChart {
            visible: card.showHistory && card.provider.ok
            Layout.fillWidth: true
            series: (card.provider.history || []).filter(s => card.showWeekly || s.kind !== "weekly")
            hours: card.historyHours
            accent: card.accent
            byLevel: card.byLevel
            warn: card.warn
            crit: card.crit
            now: card.now
            windowLabelFn: card.windowLabelFn
        }
    }
}
