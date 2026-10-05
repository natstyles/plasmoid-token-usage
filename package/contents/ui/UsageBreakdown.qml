/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Reparto de uso semanal por producto.
ColumnLayout {
    id: breakdown

    property var breakdownData: null   // {rows: [{key, label, percent, parts}], since}

    readonly property var rows: breakdownData ? breakdownData.rows.filter(r => r.percent > 0) : []
    readonly property bool darkTheme: {
        const c = Kirigami.Theme.backgroundColor
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b < 0.5
    }
    readonly property var segmentColors: darkTheme
        ? { claude_code: "#3987e5", chat: "#d95926", other: "#199e70" }
        : { claude_code: "#2a78d6", chat: "#eb6834", other: "#1baf7a" }
    property int hoveredIndex: -1

    function rowName(key, fallback) {
        if (key === "claude_code") return i18n("Claude Code")
        if (key === "chat") return i18n("Chats")
        if (key === "other") return i18nc("Other usage categories", "Other")
        return fallback
    }

    function rowText(r) {
        return rowName(r.key, r.label) + " " + Math.round(r.percent) + " %"
    }

    spacing: Kirigami.Units.smallSpacing

    PC3.Label {
        text: i18n("Weekly usage breakdown")
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: Kirigami.Units.smallSpacing * 2.5

        Canvas {
            id: bar
            anchors.fill: parent
            antialiasing: true
            onWidthChanged: requestPaint()
            Connections {
                target: breakdown
                function onRowsChanged() { bar.requestPaint() }
                function onSegmentColorsChanged() { bar.requestPaint() }
                function onHoveredIndexChanged() { bar.requestPaint() }
            }

            // Cálculo de segmentos
            function segments() {
                const gap = 2
                const total = breakdown.rows.reduce((s, r) => s + r.percent, 0) || 1
                const usable = width - gap * Math.max(0, breakdown.rows.length - 1)
                let x = 0
                return breakdown.rows.map(r => {
                    const w = Math.max(2, usable * r.percent / total)
                    const seg = { x: x, w: w }
                    x += w + gap
                    return seg
                })
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const segs = segments()
                const h = height, r = Math.min(4, h / 2)
                segs.forEach((s, i) => {
                    const row = breakdown.rows[i]
                    ctx.fillStyle = breakdown.segmentColors[row.key]
                    ctx.globalAlpha = breakdown.hoveredIndex === -1 || breakdown.hoveredIndex === i ? 1 : 0.45
                    // Extremos redondeados
                    const rl = i === 0 ? r : 0, rr = i === segs.length - 1 ? r : 0
                    const x0 = s.x, x1 = s.x + s.w
                    ctx.beginPath()
                    ctx.moveTo(x0 + rl, 0)
                    ctx.lineTo(x1 - rr, 0)
                    ctx.arcTo(x1, 0, x1, rr, rr)
                    ctx.lineTo(x1, h - rr)
                    ctx.arcTo(x1, h, x1 - rr, h, rr)
                    ctx.lineTo(x0 + rl, h)
                    ctx.arcTo(x0, h, x0, h - rl, rl)
                    ctx.lineTo(x0, rl)
                    ctx.arcTo(x0, 0, x0 + rl, 0, rl)
                    ctx.closePath()
                    ctx.fill()
                })
            }
        }

        // Área interactiva de hover
        MouseArea {
            id: barHover
            anchors.fill: parent
            anchors.topMargin: -Kirigami.Units.smallSpacing
            anchors.bottomMargin: -Kirigami.Units.smallSpacing
            hoverEnabled: true
            onPositionChanged: mouse => {
                const segs = bar.segments()
                let found = -1
                segs.forEach((s, i) => { if (mouse.x >= s.x - 1 && mouse.x <= s.x + s.w + 1) found = i })
                breakdown.hoveredIndex = found
            }
            onExited: breakdown.hoveredIndex = -1

            PC3.ToolTip.visible: containsMouse && breakdown.hoveredIndex >= 0
            PC3.ToolTip.text: {
                const r = breakdown.rows[breakdown.hoveredIndex]
                if (!r) return ""
                return i18n("%1 of this week's usage", breakdown.rowText(r)) + (r.parts.length ? "\n" + r.parts.join("\n") : "")
            }
        }
    }

    // Leyenda
    Flow {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: breakdown.rows
            delegate: Row {
                required property var modelData
                required property int index
                spacing: Kirigami.Units.smallSpacing
                opacity: breakdown.hoveredIndex === -1 || breakdown.hoveredIndex === index ? 1 : 0.6

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Kirigami.Units.smallSpacing * 2
                    height: width
                    radius: 2
                    color: breakdown.segmentColors[modelData.key]
                }
                PC3.Label {
                    text: breakdown.rowText(modelData)
                    font: Kirigami.Theme.smallFont
                }

                HoverHandler {
                    onHoveredChanged: breakdown.hoveredIndex = hovered ? index : -1
                }
            }
        }
    }
}
