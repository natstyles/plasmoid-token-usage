/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Vista compacta del panel
GridLayout {
    id: view

    property var providers: []
    property bool vertical: false
    property int style: 0
    property int metric: 0
    property bool showWeekly: true
    property bool byLevel: true
    property int warn: 70
    property int crit: 90
    property var accentFor: id => Kirigami.Theme.highlightColor
    property var logoFor: id => ""

    function windowPercent(provider, kind) {
        if (!provider.ok) return -1
        let max = -1
        for (const w of provider.windows)
            if (w.kind === kind && w.percent !== null) max = Math.max(max, w.percent)
        return max
    }

    // Obtención del porcentaje según métrica
    function metricPercent(provider) {
        const session = windowPercent(provider, "session")
        const weekly = windowPercent(provider, "weekly")
        if (metric === 1) return weekly >= 0 ? weekly : session
        if (metric === 2) return Math.max(session, weekly)
        return session >= 0 ? session : weekly
    }

    function levelColor(p, fallback) {
        if (byLevel && p >= crit) return Kirigami.Theme.negativeTextColor
        if (byLevel && p >= warn) return Kirigami.Theme.neutralTextColor
        return fallback
    }

    flow: vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    rowSpacing: Kirigami.Units.smallSpacing
    columnSpacing: Kirigami.Units.smallSpacing * 2

    Kirigami.Icon {
        visible: view.providers.length === 0
        source: "utilities-system-monitor"
        Layout.fillHeight: !view.vertical
        Layout.fillWidth: view.vertical
        Layout.preferredWidth: view.vertical ? -1 : height
        Layout.preferredHeight: view.vertical ? width : -1
    }

    // Anillos
    Repeater {
        model: view.style === 2 ? [] : view.providers

        delegate: Gauge {
            id: gauge
            required property var modelData
            readonly property real percent: view.metricPercent(modelData)

            Layout.fillHeight: !view.vertical
            Layout.fillWidth: view.vertical
            Layout.preferredWidth: view.vertical ? -1 : height
            Layout.preferredHeight: view.vertical ? width : -1
            outerPercent: view.style === 0 ? view.windowPercent(modelData, "session") : percent
            innerPercent: view.style === 0 && view.showWeekly ? view.windowPercent(modelData, "weekly") : -1
            accent: view.accentFor(modelData.id)
            byLevel: view.byLevel
            warn: view.warn
            crit: view.crit
            thickness: view.style === 0 ? 0.11 : 0.13
            centerText: view.style === 1 ? Math.round(Math.max(0, percent)).toString() : ""
            failed: !modelData.ok

            // Logo central
            ProviderLogo {
                visible: view.style === 0 && gauge.modelData.ok
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * (view.showWeekly && view.windowPercent(gauge.modelData, "weekly") >= 0 ? 0.42 : 0.55)
                height: width
                source: view.logoFor(gauge.modelData.id)
                letter: gauge.modelData.name.charAt(0)
                accent: gauge.accent
            }
        }
    }

    // Logo y texto
    Repeater {
        model: view.style === 2 ? view.providers : []

        delegate: RowLayout {
            required property var modelData
            readonly property real percent: view.metricPercent(modelData)

            spacing: Kirigami.Units.smallSpacing
            Layout.alignment: Qt.AlignCenter

            ProviderLogo {
                implicitWidth: Kirigami.Units.iconSizes.small
                source: view.logoFor(modelData.id)
                letter: modelData.name.charAt(0)
                accent: view.accentFor(modelData.id)
            }
            PC3.Label {
                text: modelData.ok ? Math.round(Math.max(0, percent)) + "%" : "!"
                color: modelData.ok ? view.levelColor(percent, Kirigami.Theme.textColor) : Kirigami.Theme.negativeTextColor
                font.bold: true
            }
        }
    }
}
