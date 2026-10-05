/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import org.kde.kirigami as Kirigami

// Indicador circular
Item {
    id: gauge

    property real outerPercent: -1
    property real innerPercent: -1
    property color accent: Kirigami.Theme.highlightColor
    property bool byLevel: true
    property int warn: 70
    property int crit: 90
    property string centerText: ""
    property bool failed: false
    property real thickness: 0.11

    function levelColor(p) {
        if (byLevel && p >= crit) return Kirigami.Theme.negativeTextColor
        if (byLevel && p >= warn) return Kirigami.Theme.neutralTextColor
        return accent
    }

    implicitWidth: Kirigami.Units.gridUnit * 2
    implicitHeight: implicitWidth

    onOuterPercentChanged: canvas.requestPaint()
    onInnerPercentChanged: canvas.requestPaint()
    onAccentChanged: canvas.requestPaint()
    onByLevelChanged: canvas.requestPaint()
    onWarnChanged: canvas.requestPaint()
    onCritChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const size = Math.min(width, height)
            const line = Math.max(2, size * gauge.thickness)
            const cx = width / 2, cy = height / 2
            const start = -Math.PI / 2

            function ring(radius, percent) {
                ctx.lineWidth = line
                ctx.lineCap = "round"
                ctx.strokeStyle = Qt.alpha(gauge.accent, 0.18)
                ctx.beginPath()
                ctx.arc(cx, cy, radius, 0, 2 * Math.PI)
                ctx.stroke()
                if (percent > 0) {
                    ctx.strokeStyle = gauge.levelColor(percent)
                    ctx.beginPath()
                    ctx.arc(cx, cy, radius, start, start + 2 * Math.PI * Math.max(0.01, Math.min(percent, 100) / 100))
                    ctx.stroke()
                }
            }

            const outer = size / 2 - line / 2
            ring(outer, gauge.outerPercent)
            if (gauge.innerPercent >= 0)
                ring(outer - line * 1.5, gauge.innerPercent)
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width * 0.7
        horizontalAlignment: Text.AlignHCenter
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 6
        text: gauge.failed ? "!" : gauge.centerText
        color: gauge.failed ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        font.bold: true
        font.pixelSize: Math.max(6, Math.min(gauge.width, gauge.height) * (gauge.innerPercent >= 0 ? 0.3 : 0.32))
    }
}
