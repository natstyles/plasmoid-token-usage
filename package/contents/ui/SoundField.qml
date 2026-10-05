/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as QtDialogs
import QtQuick.Layouts

// Selector de sonido
RowLayout {
    id: field

    property string value: ""
    property string defaultLabel: i18nc("Default sound option", "Default")
    signal testRequested()

    readonly property string oceanDir: "/usr/share/sounds/ocean/stereo/"
    readonly property var presets: [
        { label: field.defaultLabel, value: "" },
        { label: i18n("No sound"), value: "none" },
        { label: i18nc("Sound name", "Warning"), value: oceanDir + "dialog-warning.oga" },
        { label: i18nc("Sound name", "Information"), value: oceanDir + "dialog-information.oga" },
        { label: i18nc("Sound name", "Attention"), value: oceanDir + "message-attention.oga" },
        { label: i18nc("Sound name", "New message"), value: oceanDir + "message-new-instant.oga" },
        { label: i18nc("Sound name", "New email"), value: oceanDir + "message-new-email.oga" },
        { label: i18nc("Sound name", "Completed"), value: oceanDir + "completion-success.oga" },
        { label: i18nc("Sound name", "Success"), value: oceanDir + "outcome-success.oga" },
        { label: i18nc("Sound name", "Alarm"), value: oceanDir + "alarm-clock-elapsed.oga" },
        { label: i18nc("Sound name", "Bell"), value: oceanDir + "bell.oga" },
        { label: i18nc("Sound name", "Low battery"), value: oceanDir + "battery-caution.oga" },
        { label: i18nc("Sound name", "Error"), value: oceanDir + "dialog-error.oga" },
        { label: i18nc("Sound name", "Incoming call"), value: oceanDir + "phone-incoming-call.oga" }
    ]

    function presetIndex(v) {
        for (let i = 0; i < presets.length; ++i)
            if (presets[i].value === v) return i
        return -1
    }

    // Opción personalizada
    readonly property bool isCustom: presetIndex(value) === -1
    readonly property var entries: isCustom
        ? presets.concat([{ label: i18n("File: ") + decodeURIComponent(value.split("/").pop()), value: value }])
        : presets

    QQC2.ComboBox {
        id: combo
        Layout.minimumWidth: implicitWidth
        model: field.entries
        textRole: "label"
        currentIndex: field.isCustom ? field.entries.length - 1 : field.presetIndex(field.value)
        onActivated: index => field.value = field.entries[index].value
    }

    QQC2.Button {
        icon.name: "document-open"
        text: i18n("File...")
        onClicked: fileDialog.open()
    }

    QQC2.Button {
        icon.name: "edit-reset"
        text: i18n("Default")
        enabled: field.value !== ""
        onClicked: field.value = ""
    }

    QQC2.Button {
        icon.name: "media-playback-start"
        text: i18n("Test")
        onClicked: field.testRequested()
        QQC2.ToolTip.text: i18n("Shows a test notification with this sound")
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: 500
    }

    QtDialogs.FileDialog {
        id: fileDialog
        title: i18n("Choose a sound")
        currentFolder: "file:///usr/share/sounds"
        nameFilters: [i18n("Audio (*.oga *.ogg *.wav *.mp3 *.flac *.opus)"), i18n("All files (*)")]
        onAccepted: field.value = selectedFile.toString()
    }
}
