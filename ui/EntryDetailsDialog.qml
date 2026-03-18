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

    contentItem: ScrollView {
        implicitWidth: Kirigami.Units.gridUnit * 32
        implicitHeight: Kirigami.Units.gridUnit * 22

        Kirigami.FormLayout {
            width: parent.width

            // OS Type Information Card
            Kirigami.AbstractCard {
                Kirigami.FormData.isSection: true
                Layout.fillWidth: true

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    // OS icon with accent color background
                    Rectangle {
                        width: Kirigami.Units.iconSizes.large + Kirigami.Units.largeSpacing
                        height: width
                        radius: width / 2
                        color: root.details.accentColor || "#2196F3"
                        opacity: 0.15

                        Kirigami.Icon {
                            anchors.centerIn: parent
                            source: root.details.iconName || "computer"
                            width: Kirigami.Units.iconSizes.large
                            height: Kirigami.Units.iconSizes.large
                        }
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true

                        QQC.Label {
                            text: root.details.name ?? ""
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            // Device icon
                            Kirigami.Icon {
                                source: root.details.deviceIcon || "drive-harddisk"
                                width: Kirigami.Units.iconSizes.small
                                height: Kirigami.Units.iconSizes.small
                            }

                            QQC.Label {
                                text: root.details.path ?? ""
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // Entry Information Section
            QQC.Label {
                Kirigami.FormData.section: true
                text: i18nc("@title", "Entry Information")
            }

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Entry ID:")
                text: root.details.entryIdHex ? ("Boot" + root.details.entryIdHex) : ""
                font.family: "monospace"
            }

            RowLayout {
                Kirigami.FormData.label: i18nc("@label", "Status:")
                spacing: Kirigami.Units.smallSpacing

                // Current boot badge
                Rectangle {
                    visible: root.details.isCurrent
                    width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    height: width
                    radius: width / 2
                    color: Kirigami.Theme.neutralTextColor
                    opacity: 0.8

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: "media-playback-start"
                        color: "white"
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                    }
                }

                // Default badge
                Rectangle {
                    visible: root.details.isDefault
                    width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    height: width
                    radius: width / 2
                    color: root.details.accentColor || "#FFC107"
                    opacity: 0.8

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: "starred"
                        color: "white"
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                    }
                }

                // BootNext badge
                Rectangle {
                    visible: root.details.isBootNext
                    width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    height: width
                    radius: width / 2
                    color: Kirigami.Theme.positiveTextColor
                    opacity: 0.8

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: "go-next"
                        color: "white"
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                    }
                }

                // Visible badge
                Rectangle {
                    visible: root.details.isVisible
                    width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                    height: width
                    radius: width / 2
                    color: "#4CAF50"
                    opacity: 0.8

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: "visibility"
                        color: "white"
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
                    }
                }

                QQC.Label {
                    text: !root.details.isDefault && !root.details.isVisible ?
                        i18nc("@label", "Hidden") : ""
                    }
                }
            }

            // Technical Details Section
            QQC.Label {
                Kirigami.FormData.section: true
                text: i18nc("@title", "Technical Details")
            }

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Path:")
                text: root.details.path ?? ""
                wrapMode: Text.WordWrap
                font.family: "monospace"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.9
            }

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Raw size:")
                text: root.details.rawSize !== undefined ?
                    i18nc("@label", "%1 bytes", root.details.rawSize) : ""
            }

            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Optional data:")
                text: root.details.optionalDataSize !== undefined ?
                    i18nc("@label", "%1 bytes", root.details.optionalDataSize) : i18nc("@label", "None")
            }

            // Raw Data Section
            QQC.Label {
                Kirigami.FormData.section: true
                text: i18nc("@title", "Raw Data (Hex)")
            }

            QQC.TextArea {
                Kirigami.FormData.label: ""
                text: root.details.rawHex ?? ""
                readOnly: true
                wrapMode: Text.WrapAnywhere
                selectByMouse: true
                implicitHeight: Kirigami.Units.gridUnit * 6
                font.family: "monospace"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                background: Rectangle {
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    radius: Kirigami.Units.smallSpacing
                }
            }

            // Optional Data Section
            QQC.Label {
                Kirigami.FormData.label: i18nc("@label", "Optional Data:")
                visible: root.details.optionalDataHex && root.details.optionalDataHex.length > 0
            }

            QQC.TextArea {
                Kirigami.FormData.label: ""
                text: root.details.optionalDataHex ?? ""
                readOnly: true
                wrapMode: Text.WrapAnywhere
                selectByMouse: true
                implicitHeight: Kirigami.Units.gridUnit * 4
                visible: root.details.optionalDataHex && root.details.optionalDataHex.length > 0
                font.family: "monospace"
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.85
                background: Rectangle {
                    color: Kirigami.Theme.backgroundColor
                    border.color: Kirigami.Theme.disabledTextColor
                    radius: Kirigami.Units.smallSpacing
                }
            }
        }
    }
}

