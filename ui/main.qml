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

KCMUtils.ScrollViewKCM {
    id: root

    property int selectedEntryId: -1
    property string infoText: ""

    header: Kirigami.InlineMessage {
        visible: kcm.manager.lastError.length > 0
        text: kcm.manager.lastError
        type: Kirigami.MessageType.Error
        showCloseButton: true
        onVisibleChanged: if (!visible) kcm.manager.refresh()
    }

    view: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Connections {
            target: kcm.manager
            function onInfoMessage(text) {
                root.infoText = text ?? ""
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.infoText.length > 0
            text: root.infoText
            type: Kirigami.MessageType.Information
            showCloseButton: true
            onCloseClicked: root.infoText = ""
        }

        Kirigami.Heading {
            Layout.fillWidth: true
            text: i18nc("@title", "EFI Boot Entries")
            level: 2
        }

        QQC.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: i18nc("@info", "Select the boot entry you want to use as the default, reboot to it once, or inspect its details.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: kcm.manager.available && !kcm.manager.hasPrivilege
            type: Kirigami.MessageType.Information
            text: i18nc("@info", "Listing boot entries may be restricted on some systems. You will only be asked for permission when changing the default or reboot target.")
        }

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            visible: !kcm.manager.available
            text: i18nc("@info:placeholder", "EFI boot entries are not available on this system.")
        }

        ListView {
            id: entriesView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: kcm.manager.available
            clip: true
            model: kcm.manager.entries
            currentIndex: -1

            delegate: QQC.ItemDelegate {
                id: delegateRoot
                required property var model
                required property int index

                width: ListView.view.width
                highlighted: root.selectedEntryId === model.entryId

                onClicked: root.selectedEntryId = model.entryId

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: "drive-harddisk"
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: Kirigami.Units.iconSizes.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 4
                            text: delegateRoot.model.name
                            elide: Text.ElideRight
                        }

                        QQC.Label {
                            Layout.fillWidth: true
                            text: delegateRoot.model.path.length > 0
                                ? i18nc("@info:inlistbox", "Path: %1", delegateRoot.model.path)
                                : i18nc("@info:inlistbox", "Path: (not available)")
                            elide: Text.ElideRight
                            color: Kirigami.Theme.disabledTextColor
                        }

                        QQC.Label {
                            Layout.fillWidth: true
                            text: i18nc("@info:inlistbox", "Entry ID: %1", delegateRoot.model.entryIdHex)
                            elide: Text.ElideRight
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    Kirigami.Icon {
                        visible: delegateRoot.model.isDefault
                        source: "emblem-favorite"
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        Kirigami.ToolTip.visible: hovered
                        Kirigami.ToolTip.text: i18nc("@info:tooltip", "Default")
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC.Button {
                text: i18nc("@action:button", "Set as Default")
                icon.name: "emblem-favorite"
                enabled: kcm.manager.available && root.selectedEntryId >= 0 && !kcm.manager.busy
                onClicked: kcm.manager.setDefault(root.selectedEntryId)
            }

            QQC.Button {
                text: i18nc("@action:button", "Reboot to…")
                icon.name: "system-reboot"
                enabled: kcm.manager.available && root.selectedEntryId >= 0 && !kcm.manager.busy
                onClicked: rebootDialog.open()
            }

            QQC.Button {
                text: i18nc("@action:button", "Details…")
                icon.name: "documentinfo"
                enabled: kcm.manager.available && root.selectedEntryId >= 0
                onClicked: detailsDialog.open()
            }

            Item { Layout.fillWidth: true }

            QQC.BusyIndicator {
                running: kcm.manager.busy
                visible: running
            }
        }
    }

    EntryDetailsDialog {
        id: detailsDialog
        details: kcm.manager.detailsForEntry(root.selectedEntryId)
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

