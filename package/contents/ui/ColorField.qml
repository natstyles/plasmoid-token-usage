/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kquickcontrols as KQControls
import org.kde.plasma.plasma5support as P5Support

// Selector de color
RowLayout {
    id: field

    property alias color: button.color
    property color defaultColor

    readonly property string pickerPath: decodeURIComponent(Qt.resolvedUrl("../code/pickcolor.py").toString().replace(/^file:\/\//, ""))

    KQControls.ColorButton {
        id: button
        showAlphaChannel: false
    }

    QQC2.Button {
        icon.name: "color-picker"
        text: i18n("Color Picker")
        enabled: !picker.running
        onClicked: {
            picker.running = true
            picker.connectSource("python3 '" + field.pickerPath + "'")
        }
        QQC2.ToolTip.text: i18n("Click anywhere on the screen to copy its color")
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: 500
    }

    QQC2.Button {
        icon.name: "edit-reset"
        text: i18n("Default")
        enabled: !Qt.colorEqual(button.color, field.defaultColor)
        onClicked: button.color = field.defaultColor
    }

    P5Support.DataSource {
        id: picker

        property bool running: false

        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => {
            disconnectSource(source)
            running = false
            const picked = (data["stdout"] || "").trim()
            if (/^#[0-9a-fA-F]{6}$/.test(picked))
                button.color = picked
        }
    }
}
