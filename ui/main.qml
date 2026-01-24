/*
    SPDX-License-Identifier: GPL-2.0-or-later
    SPDX-FileCopyrightText: 2026
*/

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

pragma ComponentBehavior: Bound

KCMUtils.GridViewKCM {
    id: root

    property int selectedEntryId: -1
    property string infoText: ""

    // KCM.SettingStateBinding {
    //     configObject: kcm.splashScreenSettings
    //     settingName: "theme"
    //     extraEnabledConditions: !kcm.testing
    // }

    view.model: kcm.manager.entries
    // view.currentIndex: kcm.sortModelPluginIndex(kcm.splashScreenSettings.theme)

    header: Kirigami.InlineMessage {
        text: i18nc("@info:header", "EFI Startup Item")
        type: Kirigami.MessageType.Error
        showCloseButton: true
    }

    view.delegate: KCMUtils.GridDelegate {
        id: delegate

        text: model.display
        toolTip: model.description

        thumbnailAvailable: model.screenshot.toString() !== ""
        thumbnail: Image {
            anchors.fill: parent
            source: model.screenshot
            sourceSize: Qt.size(delegate.GridView.view.cellWidth * Screen.devicePixelRatio,
                                delegate.GridView.view.cellHeight * Screen.devicePixelRatio)
            opacity: model.pendingDeletion ? 0.3 : 1
        }

        actions: [
            Kirigami.Action {
                icon.name: "starred"
                tooltip: i18nc("@action:button", "Set as default boot entry")
                enabled: true
                onTriggered: kcm.test(model.pluginName)
            },
            Kirigami.Action {
                icon.name: "system-reboot"
                tooltip: i18nc("@action:button", "Set as one-time boot entry")
                enabled: true
                onTriggered: model.pendingDeletion = !model.pendingDeletion
            }
        ]
    }

    QQC.Dialog {
        id: rebootDialog
        title: i18nc("@title", "Reboot")
        standardButtons: QQC.Dialog.Cancel | QQC.Dialog.Ok
        modal: true

        onAccepted: kcm.manager.rebootTo(root.selectedEntryId)

        contentItem: QQC.Label {
            width: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            text: i18nc("@info", "The computer will reboot into the selected EFI boot entry.")
        }
    }
}

