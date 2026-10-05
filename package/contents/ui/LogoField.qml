/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts
import org.kde.iconthemes as KIconThemes
import org.kde.kirigami as Kirigami

// Selector de logo
RowLayout {
    id: field

    property string logo: ""
    property string defaultLogo
    property string letter
    property color accent

    ProviderLogo {
        implicitWidth: Kirigami.Units.iconSizes.medium
        source: field.logo || field.defaultLogo
        letter: field.letter
        accent: field.accent
    }

    QQC2.Button {
        icon.name: "document-open"
        text: i18n("Image...")
        onClicked: fileDialog.open()
    }

    QQC2.Button {
        icon.name: "preferences-desktop-icons"
        text: i18n("Icon...")
        onClicked: iconDialog.open()
    }

    QQC2.Button {
        icon.name: "edit-reset"
        text: i18n("Default")
        enabled: field.logo !== ""
        onClicked: field.logo = ""
    }

    QtDialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose an image for the logo")
        nameFilters: [i18n("Images (*.png *.svg *.svgz *.jpg *.jpeg *.webp *.gif *.bmp *.ico)"), i18n("All files (*)")]
        onAccepted: field.logo = selectedFile.toString()
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onAccepted: if (iconName) field.logo = iconName
    }
}
