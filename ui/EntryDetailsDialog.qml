/*
    SPDX-License-Identifier: GPL-2.0-or-later
    SPDX-FileCopyrightText: 2026
*/

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

QQC.Dialog {
    id: root

    property var details: ({})

    title: i18nc("@title", "EFI Entry Details")
    standardButtons: QQC.Dialog.Close
    modal: true

    contentItem: Flickable {
        implicitWidth: Kirigami.Units.gridUnit * 28
        implicitHeight: Kirigami.Units.gridUnit * 20
        clip: true
        contentWidth: width
        contentHeight: form.implicitHeight

        Kirigami.FormLayout {
            id: form
            width: parent.width

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Name:")
                text: root.details.name ?? ""
                wrapMode: Text.WordWrap
            }

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Entry ID:")
                text: root.details.entryIdHex ? ("Boot" + root.details.entryIdHex) : ""
            }

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Default:")
                text: root.details.isDefault ? i18nc("@label", "Yes") : i18nc("@label", "No")
            }

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Visible:")
                text: root.details.isVisible ? i18nc("@label", "Yes") : i18nc("@label", "No")
            }

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Path:")
                text: root.details.path ?? ""
                wrapMode: Text.WordWrap
            }

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Raw size:")
                text: root.details.rawSize !== undefined ? i18nc("@label", "%1 bytes", root.details.rawSize) : ""
            }

            QQC.TextArea {
                Kirigami.FormData.label: i18nc("@label", "Raw (hex):")
                text: root.details.rawHex ?? ""
                readOnly: true
                wrapMode: Text.WrapAnywhere
                selectByMouse: true
                background: Rectangle {
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    radius: Kirigami.Units.smallSpacing
                }
            }
        }
    }
}

