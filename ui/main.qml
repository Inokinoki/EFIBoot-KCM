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

    view.model: kcm.manager.entries
    // view.currentIndex: kcm.sortModelPluginIndex(kcm.splashScreenSettings.theme)

    header: Kirigami.InlineMessage {
        text: i18nc("@info:header", "EFI Startup Item")
        type: Kirigami.MessageType.Error
        showCloseButton: true
    }

    view.delegate: KCMUtils.GridDelegate {
        id: delegate

        required property string name
        required property string path
        required property int entryId
        required property string entryIdHex
        required property bool isDefault
        required property string iconName

        text: name
        subtitle: i18nc("@info:subtitle", "ID: ") + entryIdHex
        toolTip: path

        // Use icon name from model instead of screenshot
        thumbnailAvailable: iconName ? true : false
        thumbnail: Kirigami.Icon {
            source: iconName
            anchors.fill: parent
        }

        actions: [
            Kirigami.Action {
                icon.name: "starred"
                tooltip: i18nc("@action:button", "Set as default boot entry")
                enabled: !delegate.isDefault
                onTriggered: kcm.manager.setDefault(delegate.entryId)
            },
            Kirigami.Action {
                icon.name: "system-reboot"
                tooltip: i18nc("@action:button", "Set as one-time boot entry")
                enabled: true
                onTriggered: {
                    root.selectedEntryId = delegate.entryId
                    rebootDialog.open()
                }
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

