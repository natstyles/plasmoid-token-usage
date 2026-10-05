/*
SPDX-FileCopyrightText: 2026 Steven <richardsarizandieta@gmail.com>
SPDX-License-Identifier: GPL-3.0-or-later
*/
import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_refreshMinutes: refreshSpin.value
    property alias cfg_showClaude: claudeCheck.checked
    property alias cfg_showChatGPT: chatgptCheck.checked
    property alias cfg_showGemini: geminiCheck.checked
    property alias cfg_showWeekly: weeklyCheck.checked
    property alias cfg_showResetDate: resetDateCheck.checked
    property alias cfg_showHistory: historyCheck.checked
    property alias cfg_showBreakdown: breakdownCheck.checked
    property int cfg_historyHours

    readonly property var historyRanges: [6, 24, 72, 168]

    Kirigami.FormLayout {
        QQC2.SpinBox {
            id: refreshSpin
            Kirigami.FormData.label: i18n("Update every (min):")
            from: 1
            to: 120
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: claudeCheck
            Kirigami.FormData.label: i18n("Providers:")
            text: i18n("Claude (Claude Code session)")
        }
        QQC2.CheckBox {
            id: chatgptCheck
            text: i18n("ChatGPT (Codex CLI session)")
        }
        QQC2.CheckBox {
            id: geminiCheck
            text: i18n("Gemini (Antigravity running)")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.CheckBox {
            id: weeklyCheck
            Kirigami.FormData.label: i18n("Show:")
            text: i18n("Weekly limits")
        }
        QQC2.CheckBox {
            id: resetDateCheck
            text: i18n("Exact reset date and time")
        }
        QQC2.CheckBox {
            id: breakdownCheck
            text: i18n("Claude's weekly usage breakdown (Chats, Claude Code...)")
        }
        QQC2.CheckBox {
            id: historyCheck
            text: i18n("Usage history chart")
        }
        QQC2.ComboBox {
            Kirigami.FormData.label: i18n("History period:")
            enabled: historyCheck.checked
            model: [i18n("Last 6 hours"), i18n("Last 24 hours"), i18n("Last 3 days"), i18n("Last 7 days")]
            currentIndex: Math.max(0, historyRanges.indexOf(cfg_historyHours))
            onActivated: index => cfg_historyHours = historyRanges[index]
        }
    }
}
