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

    property string infoText: ""

    view.model: kcm.manager.entries

    // Loading overlay
    Kirigami.OverlaySheet {
        id: loadingOverlay
        parent: root
        modal: true
        showCloseButton: false
        padding: Kirigami.Units.largeSpacing
        visible: kcm.manager.busy

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.BusyIndicator {
                running: kcm.manager.busy
                Layout.alignment: Qt.AlignHCenter
            }

            QQC.Label {
                text: i18nc("@info:status", "Loading…")
                Layout.alignment: Qt.AlignHCenter
            }
        }

        onOpened: {
            // Close automatically when no longer busy
            if (!kcm.manager.busy) {
                close()
            }
        }
    }

    // Add refresh button to the KCM header
    actions: [
        Kirigami.Action {
            id: refreshAction
            text: i18nc("@action:button", "Refresh")
            icon.name: "view-refresh"
            enabled: !kcm.manager.busy
            onTriggered: kcm.manager.refresh()
        }
    ]

    header: Kirigami.InlineMessage {
        id: headerMessage
        visible: kcm.manager.lastError !== ""
        text: kcm.manager.lastError
        type: Kirigami.MessageType.Error
        showCloseButton: true
        actions: [
            Kirigami.Action {
                text: i18nc("@action:button", "Details")
                icon.name: "dialog-information"
                onTriggered: errorDialog.open()
            }
        ]
    }

    Connections {
        target: kcm.manager
        function onBusyChanged() {
            // Close loading overlay when no longer busy
            if (!kcm.manager.busy && loadingOverlay.opened) {
                loadingOverlay.close()
            }
        }
        function onLastErrorChanged() {
            if (kcm.manager.lastError !== "") {
                // Show inline message for non-critical errors
                headerMessage.visible = true
            }
        }
        function onInfoMessage(text) {
            // Show info messages
            infoMessageDialog.text = text
            infoMessageDialog.open()
        }
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
        toolTip: isDefault ? i18nc("@info:tooltip", "[Default] ") + path : path

        // Add a visual badge for default entry
        Rectangle {
            parent: delegate.background
            anchors.fill: parent
            color: "transparent"
            border.width: delegate.isDefault ? 3 : 0
            border.color: Kirigami.Theme.highlightColor
            z: 1
        }

        // Use icon name from model instead of screenshot
        thumbnailAvailable: iconName ? true : false
        thumbnail: Item {
            anchors.fill: parent

            Kirigami.Icon {
                source: iconName
                anchors.fill: parent
            }

            // Default badge indicator
            Rectangle {
                visible: delegate.isDefault
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Kirigami.Units.smallSpacing
                width: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
                height: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
                color: Kirigami.Theme.backgroundColor
                radius: width / 2

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: "starred"
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: Kirigami.Units.iconSizes.smallMedium
                }
            }
        }

        actions: [
            Kirigami.Action {
                icon.name: "starred"
                tooltip: delegate.isDefault ? 
                    i18nc("@action:button", "Already set as default boot entry") :
                    i18nc("@action:button", "Set as default boot entry")
                enabled: !delegate.isDefault
                onTriggered: kcm.manager.setDefault(delegate.entryId)
            },
            Kirigami.Action {
                icon.name: "system-reboot"
                tooltip: i18nc("@action:button", "Set as one-time boot entry")
                enabled: true
                onTriggered: kcm.manager.rebootTo(delegate.entryId)
            }
        ]
    }

    QQC.Dialog {
        id: errorDialog
        title: i18nc("@title", "Error")
        modal: true

        contentItem: QQC.Label {
            width: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            text: kcm.manager.lastError
        }

        standardButtons: QQC.Dialog.Ok
    }

    QQC.Dialog {
        id: infoMessageDialog
        title: i18nc("@title", "Information")
        property string text: ""
        modal: true

        contentItem: QQC.Label {
            width: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            text: infoMessageDialog.text
        }

        standardButtons: QQC.Dialog.Ok
    }
}

