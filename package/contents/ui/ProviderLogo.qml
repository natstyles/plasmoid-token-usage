/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import org.kde.kirigami as Kirigami

// Logo del proveedor
Item {
    id: logo

    property string source
    property string letter
    property color accent

    implicitWidth: Kirigami.Units.iconSizes.smallMedium
    implicitHeight: implicitWidth

    Kirigami.Icon {
        id: icon
        anchors.fill: parent
        source: logo.source
    }

    Rectangle {
        visible: !icon.valid || logo.source === ""
        anchors.fill: parent
        radius: width / 2
        color: logo.accent

        Text {
            anchors.centerIn: parent
            text: logo.letter
            color: "white"
            font.bold: true
            font.pixelSize: parent.height * 0.55
        }
    }
}
