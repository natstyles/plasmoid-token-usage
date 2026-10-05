/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_compactStyle: compactStyleCombo.currentIndex
    property alias cfg_compactMetric: compactMetricCombo.currentIndex
    property alias cfg_popupStyle: popupStyleCombo.currentIndex
    property alias cfg_popupWidth: popupWidthSpin.value
    property alias cfg_cardBackground: cardBackgroundCheck.checked
    property alias cfg_colorByLevel: colorByLevelCheck.checked
    property alias cfg_warnThreshold: warnSpin.value
    property alias cfg_critThreshold: critSpin.value
    property alias cfg_colorClaude: claudeColor.color
    property alias cfg_colorChatGPT: chatgptColor.color
    property alias cfg_colorGemini: geminiColor.color
    property alias cfg_logoClaude: claudeLogo.logo
    property alias cfg_logoChatGPT: chatgptLogo.logo
    property alias cfg_logoGemini: geminiLogo.logo
    property alias cfg_notifyEnabled: notifyCheck.checked
    property alias cfg_notifyWarn: notifyWarnCheck.checked
    property alias cfg_notifyCrit: notifyCritCheck.checked
    property alias cfg_notifyReset: notifyResetCheck.checked
    property alias cfg_alertSound: alertSoundField.value
    property alias cfg_resetSound: resetSoundField.value

    function bundledLogo(id) {
        return Qt.resolvedUrl("../images/" + id + ".svg").toString()
    }

    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel")
        }

        QQC2.ComboBox {
            id: compactStyleCombo
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Double rings (session and weekly)"), i18n("Ring with percentage"), i18n("Logo and percentage")]
        }
        QQC2.ComboBox {
            id: compactMetricCombo
            Kirigami.FormData.label: i18n("Percentage shown:")
            visible: compactStyleCombo.currentIndex !== 0
            model: [i18n("Session"), i18n("Weekly"), i18n("Highest")]
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: compactStyleCombo.currentIndex === 0
                ? i18n("The outer ring is the session and the inner ring is the week, with the logo in the center.")
                : i18n("Gemini only has a session limit, so it always shows that.")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Popup")
        }

        QQC2.ComboBox {
            id: popupStyleCombo
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Rings"), i18n("Bars")]
        }
        QQC2.SpinBox {
            id: popupWidthSpin
            Kirigami.FormData.label: i18n("Width (units):")
            from: 16
            to: 40
        }
        QQC2.CheckBox {
            id: cardBackgroundCheck
            text: i18n("Colored background cards")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Claude"
        }
        ColorField {
            id: claudeColor
            Kirigami.FormData.label: i18n("Color:")
            defaultColor: "#D97757"
        }
        LogoField {
            id: claudeLogo
            Kirigami.FormData.label: i18n("Logo:")
            defaultLogo: bundledLogo("claude")
            letter: "C"
            accent: claudeColor.color
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "ChatGPT"
        }
        ColorField {
            id: chatgptColor
            Kirigami.FormData.label: i18n("Color:")
            defaultColor: "#10A37F"
        }
        LogoField {
            id: chatgptLogo
            Kirigami.FormData.label: i18n("Logo:")
            defaultLogo: bundledLogo("chatgpt")
            letter: "C"
            accent: chatgptColor.color
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Gemini"
        }
        ColorField {
            id: geminiColor
            Kirigami.FormData.label: i18n("Color:")
            defaultColor: "#4285F4"
        }
        LogoField {
            id: geminiLogo
            Kirigami.FormData.label: i18n("Logo:")
            defaultLogo: bundledLogo("gemini")
            letter: "G"
            accent: geminiColor.color
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Alerts")
        }
        QQC2.CheckBox {
            id: colorByLevelCheck
            text: i18n("Change color when approaching limit")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Warning / critical (%):")
            enabled: colorByLevelCheck.checked
            QQC2.SpinBox {
                id: warnSpin
                from: 1
                to: 99
            }
            QQC2.SpinBox {
                id: critSpin
                from: 2
                to: 100
            }
        }

        QQC2.CheckBox {
            id: notifyCheck
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("Notify me")
        }
        ColumnLayout {
            enabled: notifyCheck.checked
            spacing: 0
            QQC2.CheckBox {
                id: notifyWarnCheck
                text: i18n("When reaching the warning threshold (%1 %)", warnSpin.value)
            }
            QQC2.CheckBox {
                id: notifyCritCheck
                text: i18n("When reaching the critical threshold (%1 %)", critSpin.value)
            }
            QQC2.CheckBox {
                id: notifyResetCheck
                text: i18n("When a quota is reset (tokens reloaded)")
            }
        }
        SoundField {
            id: alertSoundField
            Kirigami.FormData.label: i18n("Warning sound:")
            enabled: notifyCheck.checked && (notifyWarnCheck.checked || notifyCritCheck.checked)
            defaultLabel: i18nc("Default warning sound", "Default (Warning)")
            onTestRequested: notifier.send("threshold", i18n("Claude: %1 % of the session (5 h)", warnSpin.value),
                i18n("Notification test: you have reached the warning threshold. Resets in 2 h 15 min."),
                bundledLogo("claude"), value, false)
        }
        SoundField {
            id: resetSoundField
            Kirigami.FormData.label: i18n("Reset sound:")
            enabled: notifyCheck.checked && notifyResetCheck.checked
            defaultLabel: i18nc("Default reset sound", "Default (Completed)")
            onTestRequested: notifier.send("reset", i18n("Gemini: tokens reloaded"),
                i18n("Notification test: your session quota has been reset and you have 100 % available again."),
                bundledLogo("gemini"), value, false)
        }

        Notifier {
            id: notifier
            visible: false
        }
    }
}
