/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Gráfica de uso (%) en el tiempo.
ColumnLayout {
    id: chart

    property var series: []          // [{label, kind, points: [[epoch, percent], ...]}]
    property real hours: 168
    property color accent
    property bool byLevel: true
    property int warn: 70
    property int crit: 90
    property real now: Date.now()

    property var windowLabelFn

    readonly property real endSec: now / 1000
    readonly property real startSec: endSec - hours * 3600
    readonly property int pointCount: series.reduce((n, s) => n + s.points.length, 0)
    readonly property var dashes: [[], [6, 4], [2, 3]]
    readonly property real gapSec: 90 * 60   // Umbral de hueco
    // Posición del cursor en segundos (-1 = fuera)
    property real hoverSec: -1

    spacing: Kirigami.Units.smallSpacing

    function rangeLabel() {
        return hours >= 48 ? i18n("%1 d ago", Math.round(hours / 24)) : i18n("%1 h ago", Math.round(hours))
    }

    // Valores en el instante t
    function valuesAt(t) {
        return series.map(s => {
            let found = null
            for (const pt of s.points) {
                if (pt[0] > t) break
                found = pt
            }
            return { label: chart.windowLabelFn ? chart.windowLabelFn(s) : s.label, value: found && t - found[0] <= gapSec ? found[1] : null }
        })
    }

    onSeriesChanged: canvas.requestPaint()
    onNowChanged: canvas.requestPaint()
    onAccentChanged: canvas.requestPaint()
    onHoverSecChanged: canvas.requestPaint()

    PC3.Label {
        visible: chart.pointCount < 2
        Layout.fillWidth: true
        text: i18n("The history will fill up with each update.")
        opacity: 0.6
        font: Kirigami.Theme.smallFont
        wrapMode: Text.Wrap
    }

    Item {
        visible: chart.pointCount >= 2
        Layout.fillWidth: true
        implicitHeight: Kirigami.Units.gridUnit * 5

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            readonly property real plotLeft: Kirigami.Units.gridUnit * 1.8
            readonly property real plotTop: Kirigami.Units.smallSpacing
            readonly property real plotBottom: Kirigami.Theme.smallFont.pixelSize + Kirigami.Units.smallSpacing * 2
            readonly property real plotW: width - plotLeft - Kirigami.Units.smallSpacing
            readonly property real plotH: height - plotTop - plotBottom

            function xFor(t) { return plotLeft + (t - chart.startSec) / (chart.endSec - chart.startSec) * plotW }
            function yFor(p) { return plotTop + (1 - Math.min(100, Math.max(0, p)) / 100) * plotH }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const ink = Kirigami.Theme.textColor
                ctx.font = Kirigami.Theme.smallFont.pixelSize + "px sans-serif"

                // Eje Y y rejilla
                ctx.lineWidth = 1
                ctx.textAlign = "right"
                ctx.textBaseline = "middle"
                for (const p of [0, 50, 100]) {
                    const y = Math.round(yFor(p)) + 0.5
                    ctx.strokeStyle = Qt.alpha(ink, 0.12)
                    ctx.beginPath(); ctx.moveTo(plotLeft, y); ctx.lineTo(plotLeft + plotW, y); ctx.stroke()
                    ctx.fillStyle = Qt.alpha(ink, 0.55)
                    ctx.fillText(p + "%", plotLeft - 4, y)
                }

                // Umbrales de alerta
                if (chart.byLevel) {
                    ctx.setLineDash([3, 3])
                    for (const [p, color] of [[chart.warn, Kirigami.Theme.neutralTextColor], [chart.crit, Kirigami.Theme.negativeTextColor]]) {
                        const y = Math.round(yFor(p)) + 0.5
                        ctx.strokeStyle = Qt.alpha(color, 0.45)
                        ctx.beginPath(); ctx.moveTo(plotLeft, y); ctx.lineTo(plotLeft + plotW, y); ctx.stroke()
                    }
                    ctx.setLineDash([])
                }

                // Eje X
                ctx.fillStyle = Qt.alpha(ink, 0.55)
                ctx.textBaseline = "bottom"
                ctx.textAlign = "left"
                ctx.fillText(chart.rangeLabel(), plotLeft, height)
                ctx.textAlign = "right"
                ctx.fillText(i18nc("current time in a chart", "now"), plotLeft + plotW, height)

                // Series
                ctx.lineWidth = 2
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                chart.series.forEach((s, i) => {
                    ctx.strokeStyle = chart.accent
                    ctx.setLineDash(chart.dashes[i % chart.dashes.length])
                    ctx.beginPath()
                    let prev = null
                    for (const pt of s.points) {
                        if (pt[0] < chart.startSec) continue
                        const x = xFor(pt[0]), y = yFor(pt[1])
                        if (!prev || pt[0] - prev[0] > chart.gapSec) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                        prev = pt
                    }
                    ctx.stroke()
                })
                ctx.setLineDash([])

                // Cruz del cursor
                if (chart.hoverSec >= 0) {
                    const x = Math.round(xFor(chart.hoverSec)) + 0.5
                    ctx.strokeStyle = Qt.alpha(ink, 0.4)
                    ctx.lineWidth = 1
                    ctx.beginPath(); ctx.moveTo(x, plotTop); ctx.lineTo(x, plotTop + plotH); ctx.stroke()
                    for (const v of chart.valuesAt(chart.hoverSec)) {
                        if (v.value === null) continue
                        ctx.fillStyle = chart.accent
                        ctx.strokeStyle = Kirigami.Theme.backgroundColor
                        ctx.lineWidth = 2
                        ctx.beginPath(); ctx.arc(x, yFor(v.value), 4, 0, 2 * Math.PI); ctx.fill(); ctx.stroke()
                    }
                }
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            anchors.leftMargin: canvas.plotLeft
            hoverEnabled: true
            onPositionChanged: mouse => chart.hoverSec = chart.startSec + Math.max(0, Math.min(1, mouse.x / width)) * (chart.endSec - chart.startSec)
            onExited: chart.hoverSec = -1
        }

        // Tooltip del cursor
        Rectangle {
            visible: chart.hoverSec >= 0
            readonly property real cursorX: canvas.xFor(chart.hoverSec)
            x: Math.min(Math.max(0, cursorX + Kirigami.Units.smallSpacing * 2), parent.width - width)
            y: 0
            width: tipColumn.implicitWidth + Kirigami.Units.smallSpacing * 3
            height: tipColumn.implicitHeight + Kirigami.Units.smallSpacing * 2
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.backgroundColor
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.2)

            ColumnLayout {
                id: tipColumn
                anchors.centerIn: parent
                spacing: 0
                PC3.Label {
                    text: chart.hoverSec >= 0 ? new Date(chart.hoverSec * 1000).toLocaleString(Qt.locale(), "ddd d, HH:mm") : ""
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
                Repeater {
                    model: chart.hoverSec >= 0 ? chart.valuesAt(chart.hoverSec) : []
                    delegate: PC3.Label {
                        required property var modelData
                        text: modelData.label + ": " + (modelData.value === null ? "—" : Math.round(modelData.value) + " %")
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }
    }

    // Leyenda
    Flow {
        visible: chart.pointCount >= 2 && chart.series.length > 1
        Layout.fillWidth: true
        Layout.leftMargin: canvas.plotLeft
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: chart.series
            delegate: Row {
                required property var modelData
                required property int index
                spacing: Kirigami.Units.smallSpacing

                Canvas {
                    width: Kirigami.Units.gridUnit
                    height: legendLabel.height
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.strokeStyle = chart.accent
                        ctx.lineWidth = 2
                        ctx.lineCap = "round"
                        ctx.setLineDash(chart.dashes[index % chart.dashes.length])
                        ctx.beginPath(); ctx.moveTo(1, height / 2); ctx.lineTo(width - 1, height / 2); ctx.stroke()
                    }
                }
                PC3.Label {
                    id: legendLabel
                    text: chart.windowLabelFn ? chart.windowLabelFn(modelData) : modelData.label
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                }
            }
        }
    }
}
