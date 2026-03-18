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
    property bool hasBootNext: false
    property var selectedEntry: null
    property int selectedIndex: -1
    property string searchText: ""
    property int filteredCount: 0

    // Filter function - checks if entry matches search text
    function entryMatchesSearch(entryName, entryPath) {
        if (searchField.text.length === 0) {
            return true
        }

        const searchLower = searchField.text.toLowerCase()
        const nameLower = entryName.toLowerCase()
        const pathLower = entryPath.toLowerCase()

        return nameLower.includes(searchLower) || pathLower.includes(searchLower)
    }

    // Update the filtered count based on current search text
    function updateFilteredCount() {
        let count = 0
        for (let i = 0; i < kcm.manager.entries.rowCount; i++) {
            const index = kcm.manager.entries.index(i, 0)
            const name = kcm.manager.entries.data(index, EfiBootEntryModel.NameRole)
            const path = kcm.manager.entries.data(index, EfiBootEntryModel.PathRole)
            if (entryMatchesSearch(name, path)) {
                count++
            }
        }
        filteredCount = count
    }

    // Update filtered count when search text changes
    Connections {
        target: searchField
        function onTextChanged() {
            updateFilteredCount()
        }
    }

    // Also update when entries change
    Connections {
        target: kcm.manager
        function onEntriesChanged() {
            updateFilteredCount()
        }
    }

    // Keyboard shortcuts
    focus: true
    Keys.onPressed: (event) => {
        // Ctrl+R: Refresh
        if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_R) {
            kcm.manager.refresh()
            event.accepted = true
        }
        // Ctrl+F: Focus search field
        else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_F) {
            searchField.forceActiveFocus()
            searchField.selectAll()
            event.accepted = true
        }
        // Ctrl+Shift+B: Reboot to BIOS
        else if (event.modifiers & Qt.ControlModifier && event.modifiers & Qt.ShiftModifier && event.key === Qt.Key_B) {
            rebootToBiosConfirmationDialog.open()
            event.accepted = true
        }
        // Ctrl+D: System Diagnostics
        else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_D) {
            kcm.manager.getDiagnostics()
            event.accepted = true
        }
        // Ctrl+P: Boot Performance Statistics
        else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_P) {
            kcm.manager.getBootStats()
            event.accepted = true
        }
        // Ctrl+H: Boot History
        else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_H) {
            kcm.manager.getBootHistory()
            event.accepted = true
        }
        // Ctrl+V: Validate Entries
        else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_V) {
            kcm.manager.validateEntries()
            event.accepted = true
        }
        // F1: About dialog
        else if (event.key === Qt.Key_F1) {
            aboutDialog.open()
            event.accepted = true
        }
        // Escape: Close dialogs or clear search
        else if (event.key === Qt.Key_Escape) {
            if (resultDialog.opened) resultDialog.close()
            else if (errorDialog.opened) errorDialog.close()
            else if (infoMessageDialog.opened) infoMessageDialog.close()
            else if (entryDetailsDialog.opened) entryDetailsDialog.close()
            else if (rebootToBiosConfirmationDialog.opened) rebootToBiosConfirmationDialog.close()
            else if (diagnosticsDialog.opened) diagnosticsDialog.close()
            else if (bootStatsDialog.opened) bootStatsDialog.close()
            else if (bootHistoryDialog.opened) bootHistoryDialog.close()
            else if (validationDialog.opened) validationDialog.close()
            else if (compareDialog.opened) compareDialog.close()
            else if (compareSelectionDialog.opened) compareSelectionDialog.close()
            else if (bootHealthDialog.opened) bootHealthDialog.close()
            else if (aboutDialog.opened) aboutDialog.close()
            else if (searchField.text.length > 0) {
                searchField.text = ""
                searchField.focus = false
            }
            event.accepted = true
        }
        // Arrow keys for navigation
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Left) {
            navigateEntries(-1)
            event.accepted = true
        }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Right) {
            navigateEntries(1)
            event.accepted = true
        }
        // Enter: Show details for selected entry
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (selectedEntry) {
                const details = kcm.manager.detailsForEntry(selectedEntry.entryId)
                entryDetailsDialog.details = details
                entryDetailsDialog.open()
                event.accepted = true
            }
        }
    }

    // Navigation function
    function navigateEntries(direction) {
        const count = kcm.manager.entries.rowCount
        if (count === 0) return

        let newIndex = selectedIndex + direction

        // Wrap around
        if (newIndex < 0) {
            newIndex = count - 1
        } else if (newIndex >= count) {
            newIndex = 0
        }

        // Update selection
        selectedIndex = newIndex
        const index = kcm.manager.entries.index(newIndex, 0)
        if (index.isValid()) {
            selectedEntry = {
                entryId: kcm.manager.entries.data(index, EfiBootEntryModel.EntryIdRole),
                entryIdHex: kcm.manager.entries.data(index, EfiBootEntryModel.EntryIdHexRole),
                name: kcm.manager.entries.data(index, EfiBootEntryModel.NameRole),
                path: kcm.manager.entries.data(index, EfiBootEntryModel.PathRole),
                isDefault: kcm.manager.entries.data(index, EfiBootEntryModel.IsDefaultRole),
                isBootNext: kcm.manager.entries.data(index, EfiBootEntryModel.IsBootNextRole),
                isCurrent: kcm.manager.entries.data(index, EfiBootEntryModel.IsCurrentRole),
                iconName: kcm.manager.entries.data(index, EfiBootEntryModel.IconNameRole),
                accentColor: kcm.manager.entries.data(index, EfiBootEntryModel.AccentColorRole)
            }

            // Force grid view to update visual selection
            view.currentIndex = newIndex
        }
    }

    // Check if any entry has BootNext set
    function checkBootNext() {
        hasBootNext = false
        for (let i = 0; i < kcm.manager.entries.rowCount; i++) {
            if (kcm.manager.entries.data(kcm.manager.entries.index(i, 0),
                                         EfiBootEntryModel.IsBootNextRole)) {
                hasBootNext = true
                break
            }
        }
    }

    // Monitor for changes
    Connections {
        target: kcm.manager
        function onEntriesChanged() {
            checkBootNext()
            updateFilteredCount()
        }
    }

    Component.onCompleted: {
        checkBootNext()
        updateFilteredCount()
    }

    view.model: kcm.manager.entries

    // Empty state placeholder
    QQC.Label {
        visible: kcm.manager.entries.rowCount === 0 && !kcm.manager.busy
        anchors.centerIn: parent
        text: i18nc("@info:placeholder", "No EFI boot entries found")
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        font.pointSize: -1
        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
        opacity: 0.7
    }

    // No search results placeholder
    ColumnLayout {
        visible: kcm.manager.entries.rowCount > 0 && filteredCount === 0 && searchField.text.length > 0
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: "search"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            opacity: 0.5
        }

        QQC.Label {
            text: i18nc("@info:placeholder", "No matching boot entries found")
            Layout.alignment: Qt.AlignHCenter
            font.pointSize: -1
            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
            opacity: 0.7
        }

        QQC.Label {
            text: i18nc("@info:placeholder", "Try a different search term")
            Layout.alignment: Qt.AlignHCenter
            font: Kirigami.Theme.smallFont
            opacity: 0.5
        }

        QQC.Button {
            text: i18nc("@action:button", "Clear Search")
            Layout.alignment: Qt.AlignHCenter
            onClicked: searchField.text = ""
        }
    }

    // Loading overlay
    Kirigami.OverlaySheet {
        id: loadingOverlay
        parent: root
        modal: true
        showCloseButton: false
        padding: Kirigami.Units.largeSpacing * 2
        visible: kcm.manager.busy

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.BusyIndicator {
                running: kcm.manager.busy
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            }

            QQC.Label {
                text: i18nc("@info:status", "Loading EFI boot entries…")
                Layout.alignment: Qt.AlignHCenter
                font.pointSize: -1
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
            }

            QQC.Label {
                text: i18nc("@info:status", "This may take a moment")
                Layout.alignment: Qt.AlignHCenter
                font.pointSize: -1
                opacity: 0.7
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
            tooltip: i18nc("@info:tooltip", "Refresh boot entries (Ctrl+R)")
            onTriggered: kcm.manager.refresh()
        },
        Kirigami.Action {
            id: diagnosticsAction
            text: i18nc("@action:button", "System Info")
            icon.name: "hwinfo"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Show EFI diagnostics (Ctrl+D)")
            onTriggered: {
                kcm.manager.getDiagnostics()
            }
        },
        Kirigami.Action {
            id: bootStatsAction
            text: i18nc("@action:button", "Boot Stats")
            icon.name: "view-statistics"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Show boot performance statistics (Ctrl+P)")
            onTriggered: {
                kcm.manager.getBootStats()
            }
        },
        Kirigami.Action {
            id: bootHistoryAction
            text: i18nc("@action:button", "Boot History")
            icon.name: "view-history"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Show boot history (Ctrl+H)")
            onTriggered: {
                kcm.manager.getBootHistory()
            }
        },
        Kirigami.Action {
            id: validateAction
            text: i18nc("@action:button", "Validate")
            icon.name: "checkmark"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Validate boot entries (Ctrl+V)")
            onTriggered: {
                kcm.manager.validateEntries()
            }
        },
        Kirigami.Action {
            id: verifyFilesAction
            text: i18nc("@action:button", "Verify Files")
            icon.name: "document-open-folder"
            enabled: !kcm.manager.busy && kcm.manager.entries.rowCount > 0
            tooltip: i18nc("@info:tooltip", "Verify boot loader files exist and are accessible")
            onTriggered: {
                kcm.manager.verifyAllEntries()
            }
        },
        Kirigami.Action {
            id: secureBootAction
            text: i18nc("@action:button", "Secure Boot")
            icon.name: "security-high"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Check Secure Boot status")
            onTriggered: {
                kcm.manager.checkSecureBoot()
            }
        },
        Kirigami.Action {
            id: firmwareInfoAction
            text: i18nc("@action:button", "Firmware Info")
            icon.name: "computer-chip"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "View firmware and system information")
            onTriggered: {
                kcm.manager.getFirmwareInfo()
            }
        },
        Kirigami.Action {
            id: autoRepairAction
            text: i18nc("@action:button", "Auto Repair")
            icon.name: "tools-repair"
            enabled: !kcm.manager.busy && kcm.manager.entries.rowCount > 0
            tooltip: i18nc("@info:tooltip", "Scan and attempt to repair boot entry issues")
            onTriggered: {
                kcm.manager.autoRepairAllEntries()
            }
        },
        Kirigami.Action {
            id: addFromTemplateAction
            text: i18nc("@action:button", "Add from Template")
            icon.name: "document-new-from-template"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Create a new boot entry from a template")
            onTriggered: {
                templateSelectionDialog.open()
            }
        },
        Kirigami.Action {
            id: optimizeBootOrderAction
            text: i18nc("@action:button", "Optimize Order")
            icon.name: "format-list-ordered"
            enabled: !kcm.manager.busy && kcm.manager.entries.rowCount > 1
            tooltip: i18nc("@info:tooltip", "Analyze and optimize boot order for better performance")
            onTriggered: {
                kcm.manager.optimizeBootOrder()
            }
        },
        Kirigami.Action {
            id: saveProfileAction
            text: i18nc("@action:button", "Save Profile")
            icon.name: "document-save-as"
            enabled: !kcm.manager.busy && kcm.manager.entries.rowCount > 0
            tooltip: i18nc("@info:tooltip", "Save current boot configuration as a profile")
            onTriggered: {
                saveProfileDialog.open()
            }
        },
        Kirigami.Action {
            id: loadProfileAction
            text: i18nc("@action:button", "Load Profile")
            icon.name: "document-open"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Load a saved boot configuration profile")
            onTriggered: {
                loadProfileDialog.open()
            }
        },
        Kirigami.Action {
            id: exportReportAction
            text: i18nc("@action:button", "Export Report")
            icon.name: "document-export"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Export comprehensive configuration report")
            onTriggered: {
                exportReportDialog.open()
            }
        },
        Kirigami.Action {
            id: efiVariablesAction
            text: i18nc("@action:button", "EFI Variables")
            icon.name: "view-form"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "View and analyze EFI variables")
            onTriggered: {
                kcm.manager.getEfiVariables()
            }
        },
        Kirigami.Action {
            id: auditLogAction
            text: i18nc("@action:button", "Audit Log")
            icon.name: "view-history"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "View configuration change history")
            onTriggered: {
                kcm.manager.getAuditLog()
            }
        },
        Kirigami.Action {
            id: createSnapshotAction
            text: i18nc("@action:button", "Create Snapshot")
            icon.name: "camera-photo"
            enabled: !kcm.manager.busy && kcm.manager.entries.rowCount > 0
            tooltip: i18nc("@info:tooltip", "Save current configuration as a snapshot for comparison")
            onTriggered: {
                createSnapshotDialog.open()
            }
        },
        Kirigami.Action {
            id: benchmarkAction
            text: i18nc("@action:button", "Benchmark Performance")
            icon.name: "office-chart-line"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Analyze boot configuration performance")
            onTriggered: {
                kcm.manager.benchmarkBootPerformance()
            }
        },
        Kirigami.Action {
            id: advancedSearchAction
            text: i18nc("@action:button", "Advanced Search")
            icon.name: "search"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Search entries with multiple criteria")
            onTriggered: {
                advancedSearchDialog.open()
            }
        },
        Kirigami.Action {
            id: entryGroupsAction
            text: i18nc("@action:button", "Entry Groups")
            icon.name: "group"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Manage entry groups for organization")
            onTriggered: {
                kcm.manager.getEntryGroups()
            }
        },
        Kirigami.Action {
            id: createGroupAction
            text: i18nc("@action:button", "Create Group")
            icon.name: "group-new"
            enabled: !kcm.manager.busy && kcm.manager.entries.rowCount > 0
            tooltip: i18nc("@info:tooltip", "Create a new entry group")
            onTriggered: {
                createGroupDialog.open()
            }
        },
        Kirigami.Action {
            id: systemBootLogAction
            text: i18nc("@action:button", "System Boot Log")
            icon.name: "view-log"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "View system boot logs")
            onTriggered: {
                kcm.manager.getSystemBootLog(100)
            }
        },
        Kirigami.Action {
            id: resetDefaultsAction
            text: i18nc("@action:button", "Reset to Defaults")
            icon.name: "edit-undo"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Reset configuration to default settings")
            onTriggered: {
                resetDefaultsDialog.open()
            }
        },
        Kirigami.Action {
            id: importSystemdBootAction
            text: i18nc("@action:button", "Import from systemd-boot")
            icon.name: "document-import"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Import boot entries from systemd-boot configuration")
            onTriggered: {
                kcm.manager.importFromSystemdBoot()
            }
        },
        Kirigami.Action {
            id: exportSystemdBootAction
            text: i18nc("@action:button", "Export to systemd-boot")
            icon.name: "document-export"
            enabled: !kcm.manager.busy && kcm.manager.entries.rowCount > 0
            tooltip: i18nc("@info:tooltip", "Export boot entries to systemd-boot configuration")
            onTriggered: {
                kcm.manager.exportToSystemdBoot()
            }
        },
        Kirigami.Action {
            id: bootHealthAction
            text: i18nc("@action:button", "Health Check")
            icon.name: "health"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Analyze boot configuration health")
            onTriggered: {
                kcm.manager.analyzeBootHealth()
            }
        },
        Kirigami.Action {
            id: helpAction
            text: i18nc("@action:button", "Help")
            icon.name: "help-faq"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Show help and keyboard shortcuts (F1)")
            onTriggered: {
                aboutDialog.open()
            }
        },
        Kirigami.Action {
            id: resetBootNextAction
            text: i18nc("@action:button", "Reset BootNext")
            icon.name: "edit-clear"
            enabled: hasBootNext && !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Clear one-time boot setting")
            onTriggered: {
                kcm.manager.resetBootNext()
            }
        },
        Kirigami.Action {
            id: rebootToBiosAction
            text: i18nc("@action:button", "Reboot to BIOS")
            icon.name: "system-run"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Request firmware setup (Ctrl+Shift+B)")
            onTriggered: {
                rebootToBiosConfirmationDialog.open()
            }
        },
        Kirigami.Action {
            id: backupAction
            text: i18nc("@action:button", "Backup")
            icon.name: "document-save"
            enabled: !kcm.manager.busy && kcm.manager.entries.rowCount > 0
            tooltip: i18nc("@info:tooltip", "Backup boot entries to a file")
            onTriggered: {
                backupDialog.open()
            }
        },
        Kirigami.Action {
            id: restoreAction
            text: i18nc("@action:button", "Restore")
            icon.name: "document-open"
            enabled: !kcm.manager.busy
            tooltip: i18nc("@info:tooltip", "Restore boot entries from a backup file")
            onTriggered: {
                restoreDialog.open()
            }
        }
    ]

    header: ColumnLayout {
        spacing: 0

        Kirigami.InlineMessage {
            id: headerMessage
            Layout.fillWidth: true
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

        // Boot settings panel
        Kirigami.AbstractCard {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.largeSpacing
            leftPadding: Kirigami.Units.largeSpacing
            rightPadding: Kirigami.Units.largeSpacing

            contentItem: RowLayout {
                spacing: Kirigami.Units.largeSpacing

                // BootTimeout setting
                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC.Label {
                        text: i18nc("@label", "Boot timeout:")
                        font.weight: Font.Bold
                    }

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        // Current timeout visual indicator
                        Rectangle {
                            width: Kirigami.Units.gridUnit * 1.5
                            height: timeoutSpinBox.height
                            color: kcm.manager.bootTimeout > 0 ? "#4CAF50" : "#FF9800"
                            radius: Kirigami.Units.smallSpacing
                            opacity: 0.3

                            Behavior on color {
                                ColorAnimation { duration: 300 }
                            }

                            QQC.Label {
                                anchors.centerIn: parent
                                text: kcm.manager.bootTimeout >= 0 ? kcm.manager.bootTimeout : "∞"
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                                font.weight: Font.Bold
                                color: "white"
                            }
                        }

                        QQC.SpinBox {
                            id: timeoutSpinBox
                            from: 0
                            to: 65535
                            stepSize: 1
                            value: kcm.manager.bootTimeout >= 0 ? kcm.manager.bootTimeout : 5
                            enabled: !kcm.manager.busy
                            editable: true

                            QQC.Label {
                                anchors.left: parent.right
                                anchors.leftMargin: Kirigami.Units.smallSpacing
                                anchors.verticalCenter: parent.verticalCenter
                                text: i18nc("@label", "seconds")
                            }
                        }

                        QQC.Button {
                            text: i18nc("@action:button", "Set")
                            enabled: !kcm.manager.busy && timeoutSpinBox.value !== kcm.manager.bootTimeout
                            onClicked: {
                                kcm.manager.setBootTimeout(timeoutSpinBox.value)
                            }
                        }

                        // Quick preset buttons
                        QQC.ToolButton {
                            text: "0"
                            display: QQC.AbstractButton.TextOnly
                            tooltip: i18nc("@action:button", "No timeout (boot immediately)")
                            onClicked: { timeoutSpinBox.value = 0 }
                        }
                        QQC.ToolButton {
                            text: "5"
                            display: QQC.AbstractButton.TextOnly
                            tooltip: i18nc("@action:button", "5 seconds")
                            onClicked: { timeoutSpinBox.value = 5 }
                        }
                        QQC.ToolButton {
                            text: "10"
                            display: QQC.AbstractButton.TextOnly
                            tooltip: i18nc("@action:button", "10 seconds")
                            onClicked: { timeoutSpinBox.value = 10 }
                        }
                        QQC.ToolButton {
                            text: "30"
                            display: QQC.AbstractButton.TextOnly
                            tooltip: i18nc("@action:button", "30 seconds")
                            onClicked: { timeoutSpinBox.value = 30 }
                        }
                    }
                }

                Kirigami.Separator {
                    Layout.fillHeight: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                // Quick actions
                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Layout.fillWidth: false

                    QQC.Label {
                        text: i18nc("@label", "Quick actions:")
                        font.weight: Font.Bold
                    }

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Button {
                            text: i18nc("@action:button", "Reset BootNext")
                            icon.name: "edit-clear"
                            enabled: hasBootNext && !kcm.manager.busy
                            onClicked: {
                                kcm.manager.resetBootNext()
                            }
                        }

                        QQC.Button {
                            text: i18nc("@action:button", "Reboot to BIOS")
                            icon.name: "system-run"
                            enabled: !kcm.manager.busy
                            onClicked: {
                                rebootToBiosConfirmationDialog.open()
                            }
                        }
                    }

                    QQC.Label {
                        Layout.fillWidth: true
                        text: hasBootNext ?
                            i18nc("@info:tooltip", "⚠ BootNext is set - system will boot to selected entry once") :
                            i18nc("@info:tooltip", "BootNext is not set - normal boot order will be used")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        // Search/Filter panel
        Kirigami.AbstractCard {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            topPadding: Kirigami.Units.smallSpacing
            bottomPadding: Kirigami.Units.smallSpacing
            leftPadding: Kirigami.Units.smallSpacing
            rightPadding: Kirigami.Units.smallSpacing
            visible: kcm.manager.entries.rowCount > 0

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "search"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }

                QQC.TextField {
                    id: searchField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "Search boot entries by name or path...")
                    enabled: !kcm.manager.busy
                    clearButtonEnabled: true

                    // Keyboard shortcut: Ctrl+F focuses search
                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            searchField.text = ""
                            searchField.focus = false
                            event.accepted = true
                        }
                    }
                }

                // Clear button
                QQC.ToolButton {
                    icon.name: "edit-clear"
                    visible: searchField.text.length > 0
                    onClicked: searchField.text = ""
                }

                // Sort combo box
                QQC.ComboBox {
                    id: sortComboBox
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                    enabled: !kcm.manager.busy
                    model: [
                        i18nc("@item:inlistbox", "Default Order"),
                        i18nc("@item:inlistbox", "By Name"),
                        i18nc("@item:inlistbox", "By ID")
                    ]
                    currentIndex: kcm.manager.currentSortOrder
                    onActivated: (index) => {
                        kcm.manager.sortEntries(index)
                    }

                    QQC.Label {
                        anchors.left: parent.left
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.verticalCenter: parent.verticalCenter
                        text: i18nc("@label:combobox", "Sort:")
                        font: Kirigami.Theme.smallFont
                        visible: parent.count > 0
                    }
                }

                // Filter by OS type combo box
                QQC.ComboBox {
                    id: filterComboBox
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                    enabled: !kcm.manager.busy
                    model: [
                        i18nc("@item:inlistbox", "All OS Types"),
                        i18nc("@item:inlistbox", "Windows"),
                        i18nc("@item:inlistbox", "Linux"),
                        i18nc("@item:inlistbox", "macOS"),
                        i18nc("@item:inlistbox", "Unknown OS")
                    ]
                    currentIndex: kcm.manager.currentFilter + 1 // -1 becomes 0
                    onActivated: (index) => {
                        kcm.manager.filterByOsType(index - 1) // Convert back: 0 becomes -1
                    }

                    Connections {
                        target: kcm.manager
                        function onCurrentFilterChanged() {
                            filterComboBox.currentIndex = kcm.manager.currentFilter + 1
                        }
                        function onCurrentSortOrderChanged() {
                            sortComboBox.currentIndex = kcm.manager.currentSortOrder
                        }
                    }
                }

                // Reset filter button
                QQC.ToolButton {
                    icon.name: "view-filter"
                    enabled: kcm.manager.currentFilter !== -1 && !kcm.manager.busy
                    onClicked: kcm.manager.resetFilter()
                    tooltip: i18nc("@info:tooltip", "Reset to show all entries")
                }

                Kirigami.Separator {
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                    Kirigami.Orientation.Vertical {}
                }

                // Results count
                QQC.Label {
                    text: i18nc("@label", "%1/%2", filteredCount, kcm.manager.entries.rowCount)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    visible: searchField.text.length > 0
                }
            }
        }
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
        function onOperationResult(success, message) {
            // Show operation result dialog
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
        }
        function onDiagnosticsReady(diagnostics) {
            // Show diagnostics dialog
            diagnosticsDialog.diagnostics = diagnostics
            diagnosticsDialog.open()
        }
        function onBootStatsReady(bootStats) {
            // Show boot statistics dialog
            bootStatsDialog.bootStats = bootStats
            bootStatsDialog.open()
        }
        function onBootHistoryReady(bootHistory) {
            // Show boot history dialog
            bootHistoryDialog.bootHistory = bootHistory
            bootHistoryDialog.open()
        }
        function onValidationReady(issues) {
            // Show validation results
            validationDialog.issues = issues
            validationDialog.open()
        }
        function onComparisonReady(comparison) {
            // Show comparison results
            if (comparison && comparison.entry1Id !== undefined) {
                compareDialog.comparison = comparison
                compareDialog.open()
            }
        }
        function onDiagnosticsExported(success, message) {
            // Show export result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
        }
        function onBootHealthAnalysisReady(analysis) {
            // Show boot health analysis
            bootHealthDialog.analysis = analysis
            bootHealthDialog.open()
        }
        function onEntryVerificationReady(verificationResult) {
            // Show single entry verification result
            entryVerificationDialog.verificationResult = verificationResult
            entryVerificationDialog.open()
        }
        function onAllEntriesVerificationReady(verificationResults) {
            // Show all entries verification results
            allEntriesVerificationDialog.verificationResults = verificationResults
            allEntriesVerificationDialog.open()
        }
        function onSecureBootStatusReady(status) {
            // Show Secure Boot status
            secureBootDialog.status = status
            secureBootDialog.open()
        }
        function onFirmwareInfoReady(info) {
            // Show firmware information
            firmwareInfoDialog.info = info
            firmwareInfoDialog.open()
        }
        function onEntryRepairReady(repairResult) {
            // Show entry repair result
            entryRepairDialog.repairResult = repairResult
            entryRepairDialog.open()
        }
        function onAutoRepairComplete(results) {
            // Show auto repair results
            autoRepairDialog.results = results
            autoRepairDialog.open()
        }
        function onEntryExportComplete(success, message) {
            // Show export result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
        }
        function onFavoritesChanged() {
            // Favorites changed, refresh if needed
        }
        function onTemplateCreated(success, message) {
            // Show template creation result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
            if (success) {
                kcm.manager.refresh()
            }
        }
        function onEntryTestReady(testResult) {
            // Show entry test result
            entryTestDialog.testResult = testResult
            entryTestDialog.open()
        }
        function onBootOrderOptimized(result) {
            // Show boot order optimization result
            bootOrderOptimizeDialog.result = result
            bootOrderOptimizeDialog.open()
        }
        function onProfileSaved(success, message) {
            // Show profile save result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
        }
        function onProfileLoaded(success, message) {
            // Show profile load result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
            if (success) {
                kcm.manager.refresh()
            }
        }
        function onProfileDeleted(success, message) {
            // Show profile delete result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
        }
        function onBatchOperationComplete(result) {
            // Show batch operation result
            batchOperationDialog.result = result
            batchOperationDialog.open()
        }
        function onConfigReportExported(success, message) {
            // Show config report export result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
        }
        function onEfiVariablesReady(variables) {
            // Show EFI variables
            efiVariablesDialog.variables = variables
            efiVariablesDialog.open()
        }
        function onDependenciesAnalyzed(dependencies) {
            // Show dependency analysis
            dependenciesDialog.dependencies = dependencies
            dependenciesDialog.open()
        }
        function onAuditLogReady(auditLog) {
            // Show audit log
            auditLogDialog.auditLog = auditLog
            auditLogDialog.open()
        }
        function onSnapshotCreated(success, message) {
            // Show snapshot creation result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
        }
        function onSnapshotsCompared(comparison) {
            // Show snapshot comparison
            snapshotComparisonDialog.comparison = comparison
            snapshotComparisonDialog.open()
        }
        function onBootPerformanceBenchmarked(benchmark) {
            // Show boot performance benchmark
            bootPerformanceDialog.benchmark = benchmark
            bootPerformanceDialog.open()
        }
        function onAdvancedSearchReady(results) {
            // Show advanced search results
            advancedSearchResultsDialog.results = results
            advancedSearchResultsDialog.open()
        }
        function onEntryGroupCreated(success, message) {
            // Show group creation result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
        }
        function onEntryGroupDeleted(success, message) {
            // Show group deletion result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
        }
        function onSystemBootLogReady(bootLog) {
            // Show system boot log
            systemBootLogDialog.bootLog = bootLog
            systemBootLogDialog.open()
        }
        function onResetCompleted(success, message) {
            // Show reset result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
            if (success) {
                kcm.manager.refresh()
            }
        }
        function onSystemdBootImportCompleted(success, message) {
            // Show systemd-boot import result
            resultDialog.resultDialogSuccess = success
            resultDialog.resultMessage = message
            resultDialog.open()
            if (success) {
                kcm.manager.refresh()
            }
        }
    }

    view.delegate: KCMUtils.GridDelegate {
        id: delegate

        required property string name
        required property string path
        required property int entryId
        required property string entryIdHex
        required property bool isDefault
        required property bool isBootNext
        required property bool isCurrent
        required property bool isVisible
        required property string iconName
        required property string accentColor

        // Filter visibility based on search text
        visible: root.entryMatchesSearch(delegate.name, delegate.path)

        text: delegate.isCurrent ? i18nc("@item:inlistbox", "[Current] ") + delegate.name : delegate.name
        subtitle: i18nc("@info:subtitle", "ID: ") + delegate.entryIdHex
        toolTip: {
            let tooltip = delegate.path
            if (delegate.isDefault) {
                tooltip = i18nc("@info:tooltip", "[Default] ") + tooltip
            }
            if (delegate.isBootNext) {
                tooltip = i18nc("@info:tooltip", "[Next] ") + tooltip
            }
            return tooltip
        }

        // Add hover effect
        hoverEnabled: true
        scale: delegate.hovered ? 1.02 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }

        // Add visual badge with OS color
        Rectangle {
            parent: delegate.background
            anchors.fill: parent
            color: "transparent"
            border.width: delegate.isCurrent ? 4 : (delegate.isDefault ? 3 : (delegate.isBootNext ? 2 : 1))
            border.color: {
                if (delegate.isCurrent) {
                    return Kirigami.Theme.neutralTextColor
                } else if (delegate.isDefault) {
                    return delegate.accentColor || Kirigami.Theme.highlightColor
                } else if (delegate.isBootNext) {
                    return Kirigami.Theme.positiveTextColor
                } else {
                    return delegate.accentColor || "transparent"
                }
            }
            opacity: delegate.isCurrent || delegate.isDefault || delegate.isBootNext ? 1.0 : 0.3
            z: 1

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }
        }

        // Use icon name from model instead of screenshot
        thumbnailAvailable: iconName ? true : false
        thumbnail: Item {
            anchors.fill: parent

            // Add subtle glow effect for icons
            Rectangle {
                anchors.fill: parent
                anchors.margins: -Kirigami.Units.smallSpacing
                radius: Kirigami.Units.smallSpacing * 2
                color: delegate.accentColor
                opacity: delegate.hovered ? 0.2 : 0.0
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }

            Kirigami.Icon {
                id: mainIcon
                source: iconName
                anchors.fill: parent
                opacity: delegate.hovered ? 1.0 : 0.9

                // Fallback icon handling with visual feedback
                onStatusChanged: {
                    if (status === Image.Error) {
                        // Icon failed to load, show fallback
                        source = "computer"
                    }
                }

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                // Smooth transition when icon changes
                Behavior on source {
                    enabled: false
                }

                // Loading indicator while icon is being loaded
                QQC.BusyIndicator {
                    anchors.centerIn: parent
                    running: parent.status === Image.Loading
                    visible: running
                    width: Kirigami.Units.iconSizes.medium
                    height: Kirigami.Units.iconSizes.medium
                }
            }

            // OS type badge (bottom-left corner)
            Rectangle {
                visible: true
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: Kirigami.Units.smallSpacing
                width: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 2
                height: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                color: delegate.accentColor
                radius: Kirigami.Units.smallSpacing
                opacity: 0.9

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: iconName || "computer"
                    width: Kirigami.Units.iconSizes.small
                    height: Kirigami.Units.iconSizes.small
                    color: "white"

                    // Fallback to generic icon if specific icon fails
                    onStatusChanged: {
                        if (status === Image.Error && source !== "computer") {
                            source = "computer"
                        }
                    }
                }
            }

            // Current boot badge indicator (top-left corner)
            Rectangle {
                visible: delegate.isCurrent
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Kirigami.Units.smallSpacing
                width: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
                height: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
                color: Kirigami.Theme.backgroundColor
                radius: width / 2
                border.width: 2
                border.color: Kirigami.Theme.neutralTextColor

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: "media-playback-start"
                    color: Kirigami.Theme.neutralTextColor
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: Kirigami.Units.iconSizes.smallMedium
                }

                // Pulse animation for current boot
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Kirigami.Theme.neutralTextColor
                    opacity: 0.3

                    PropertyAnimation on scale {
                        from: 1.0
                        to: 1.3
                        duration: 1000
                        loops: Animation.Infinite
                        easing.type: Easing.InOutQuad
                    }
                    PropertyAnimation on opacity {
                        from: 0.3
                        to: 0.0
                        duration: 1000
                        loops: Animation.Infinite
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            // BootNext badge indicator (bottom-right corner)
            Rectangle {
                visible: delegate.isBootNext
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: Kirigami.Units.smallSpacing
                width: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing * 1.5
                height: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing * 1.5
                color: Kirigami.Theme.positiveBackgroundColor
                radius: width / 2
                z: 2
                border.width: 2
                border.color: Kirigami.Theme.positiveTextColor

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: "go-next"
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: Kirigami.Units.iconSizes.smallMedium
                }
            }

            // Default badge indicator (top-right corner)
            Rectangle {
                visible: delegate.isDefault
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Kirigami.Units.smallSpacing
                width: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
                height: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
                color: Kirigami.Theme.backgroundColor
                radius: width / 2
                border.width: 2
                border.color: delegate.accentColor

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: "starred"
                    color: delegate.accentColor
                    width: Kirigami.Units.iconSizes.smallMedium
                    height: Kirigami.Units.iconSizes.smallMedium
                }
            }

            // Success/Failure animation overlay
            Item {
                id: animationOverlay
                anchors.fill: parent
                visible: false
                z: 10

                // Semi-transparent background
                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.smallSpacing * 2
                    color: kcm.manager.lastOperationSuccess ? "#4CAF50" : "#F44336"
                    opacity: 0.3
                }

                // Success checkmark or error icon
                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: kcm.manager.lastOperationSuccess ? "dialog-ok" : "dialog-error"
                    width: Kirigami.Units.iconSizes.huge
                    height: Kirigami.Units.iconSizes.huge
                    color: kcm.manager.lastOperationSuccess ? "white" : "white"
                    scale: 0
                    opacity: 0

                    // Success/failure animation
                    ParallelAnimation {
                        id: resultAnimation
                        NumberAnimation {
                            target: animationOverlay
                            property: "visible"
                            to: 1
                            duration: 0
                        }

                        SequentialAnimation {
                            // Fade in and scale up
                            ParallelAnimation {
                                NumberAnimation {
                                    target: parent
                                    property: "scale"
                                    from: 0
                                    to: 1.2
                                    duration: 200
                                    easing.type: Easing.OutBack
                                }
                                NumberAnimation {
                                    target: parent
                                    property: "opacity"
                                    from: 0
                                    to: 1
                                    duration: 200
                                }
                            }
                            // Scale down to normal
                            NumberAnimation {
                                target: parent
                                property: "scale"
                                from: 1.2
                                to: 1.0
                                duration: 100
                                easing.type: Easing.InOutQuad
                            }
                            // Hold
                            PauseAnimation {
                                duration: 600
                            }
                            // Fade out
                            ParallelAnimation {
                                NumberAnimation {
                                    target: parent
                                    property: "opacity"
                                    from: 1
                                    to: 0
                                    duration: 200
                                }
                                NumberAnimation {
                                    target: parent
                                    property: "scale"
                                    from: 1.0
                                    to: 0.8
                                    duration: 200
                                }
                            }
                            // Hide overlay
                            ScriptAction {
                                script: {
                                    animationOverlay.visible = false
                                    parent.scale = 1.0
                                }
                            }
                        }
                    }
                }
            }

            // Shake animation for error
            SequentialAnimation {
                id: shakeAnimation
                running: false

                PropertyAction {
                    target: delegate
                    property: "scale"
                    value: 1.0
                }
                NumberAnimation {
                    target: delegate
                    property: "scale"
                    to: 0.95
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: delegate
                    property: "scale"
                    to: 1.05
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: delegate
                    property: "scale"
                    to: 0.98
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: delegate
                    property: "scale"
                    to: 1.02
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: delegate
                    property: "scale"
                    to: 1.0
                    duration: 50
                    easing.type: Easing.InOutQuad
                }
            }

            // Trigger animation when operation completes for this entry
            Connections {
                target: kcm.manager
                function onLastOperationSuccessChanged() {
                    if (kcm.manager.lastOperationEntryId === delegate.entryId) {
                        if (kcm.manager.lastOperationSuccess) {
                            resultAnimation.start()
                        } else {
                            shakeAnimation.start()
                        }
                    }
                }
            }
        }

        actions: [
            Kirigami.Action {
                icon.name: "documentinfo"
                text: i18nc("@action:button", "Details")
                tooltip: i18nc("@action:button", "View detailed information about this boot entry")
                onTriggered: {
                    const details = kcm.manager.detailsForEntry(delegate.entryId)
                    entryDetailsDialog.details = details
                    entryDetailsDialog.open()
                }
            },
            Kirigami.Action {
                icon.name: "edit-rename"
                text: i18nc("@action:button", "Rename")
                tooltip: i18nc("@action:button", "Rename this boot entry")
                enabled: !kcm.manager.busy
                onTriggered: {
                    renameDialog.entryId = delegate.entryId
                    renameDialog.currentName = delegate.name
                    renameDialog.newNameField.text = delegate.name
                    renameDialog.open()
                }
            },
            Kirigami.Action {
                icon.name: "go-up"
                text: i18nc("@action:button", "Move Up")
                tooltip: i18nc("@action:button", "Move entry up in boot order")
                enabled: !delegate.isDefault && !kcm.manager.busy
                onTriggered: kcm.manager.moveEntryUp(delegate.entryId)
            },
            Kirigami.Action {
                icon.name: "go-down"
                text: i18nc("@action:button", "Move Down")
                tooltip: i18nc("@action:button", "Move entry down in boot order")
                enabled: !kcm.manager.busy
                onTriggered: kcm.manager.moveEntryDown(delegate.entryId)
            },
            Kirigami.Action {
                icon.name: "starred"
                icon.color: delegate.isDefault ? "#FFC107" : Kirigami.Theme.textColor
                text: delegate.isDefault ?
                    i18nc("@action:button", "Default") :
                    i18nc("@action:button", "Set Default")
                tooltip: delegate.isDefault ?
                    i18nc("@action:button", "Already set as default boot entry") :
                    i18nc("@action:button", "Set this entry as the default boot option")
                enabled: !delegate.isDefault
                onTriggered: kcm.manager.setDefault(delegate.entryId)
            },
            Kirigami.Action {
                icon.name: "system-reboot"
                text: delegate.isBootNext ?
                    i18nc("@action:button", "Next Boot") :
                    i18nc("@action:button", "Boot to this entry once")
                tooltip: delegate.isBootNext ?
                    i18nc("@action:button", "Already set as one-time boot entry") :
                    i18nc("@action:button", "Boot this entry once (next reboot only)")
                enabled: !delegate.isBootNext
                onTriggered: kcm.manager.rebootTo(delegate.entryId)
            },
            Kirigami.Action {
                icon.name: "edit-delete"
                icon.color: Kirigami.Theme.negativeTextColor
                text: i18nc("@action:button", "Delete")
                tooltip: i18nc("@action:button", "Delete this boot entry (cannot be undone)")
                enabled: !kcm.manager.busy && !delegate.isCurrent
                onTriggered: {
                    deleteConfirmationDialog.entryId = delegate.entryId
                    deleteConfirmationDialog.entryName = delegate.name
                    deleteConfirmationDialog.open()
                }
            },
            Kirigami.Action {
                icon.name: delegate.isVisible ? "view-visible" : "view-hidden"
                text: delegate.isVisible ?
                    i18nc("@action:button", "Hide") :
                    i18nc("@action:button", "Show")
                tooltip: delegate.isVisible ?
                    i18nc("@action:button", "Hide this boot entry from the boot menu") :
                    i18nc("@action:button", "Show this boot entry in the boot menu")
                enabled: !kcm.manager.busy && !delegate.isCurrent
                onTriggered: {
                    kcm.manager.toggleEntryVisibility(delegate.entryId, !delegate.isVisible)
                }
            },
            Kirigami.Action {
                icon.name: "edit-copy"
                text: i18nc("@action:button", "Clone")
                tooltip: i18nc("@action:button", "Duplicate this boot entry")
                enabled: !kcm.manager.busy
                onTriggered: {
                    cloneDialog.entryId = delegate.entryId
                    cloneDialog.sourceName = delegate.name
                    cloneDialog.suggestedName = i18nc("@info", "%1 (Copy)").arg(delegate.name)
                    cloneDialog.cloneNameField.text = cloneDialog.suggestedName
                    cloneDialog.open()
                }
            },
            Kirigami.Action {
                icon.name: "git-diff"
                text: i18nc("@action:button", "Compare")
                tooltip: i18nc("@action:button", "Compare with another entry")
                enabled: !kcm.manager.busy
                onTriggered: {
                    compareSelectionDialog.firstEntryId = delegate.entryId
                    compareSelectionDialog.firstEntryName = delegate.name
                    compareSelectionDialog.open()
                }
            }
        ]

        // Context menu for right-click
        MouseArea {
            acceptedButtons: Qt.RightButton
            anchors.fill: parent
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    root.selectedEntry = delegate
                    contextMenu.popup()
                }
            }
        }
    }

    // Context menu
    QQC.Menu {
        id: contextMenu
        QQC.MenuItem {
            text: i18nc("@action:menu", "View Details")
            icon.name: "documentinfo"
            onTriggered: {
                if (root.selectedEntry) {
                    const details = kcm.manager.detailsForEntry(root.selectedEntry.entryId)
                    entryDetailsDialog.details = details
                    entryDetailsDialog.open()
                }
            }
        }
        QQC.MenuSeparator {}
        QQC.MenuItem {
            text: i18nc("@action:menu", "Move Up")
            icon.name: "go-up"
            enabled: root.selectedEntry && !root.selectedEntry.isDefault && !kcm.manager.busy
            onTriggered: {
                if (root.selectedEntry) {
                    kcm.manager.moveEntryUp(root.selectedEntry.entryId)
                }
            }
        }
        QQC.MenuItem {
            text: i18nc("@action:menu", "Move Down")
            icon.name: "go-down"
            enabled: root.selectedEntry && !kcm.manager.busy
            onTriggered: {
                if (root.selectedEntry) {
                    kcm.manager.moveEntryDown(root.selectedEntry.entryId)
                }
            }
        }
        QQC.MenuSeparator {}
        QQC.MenuItem {
            text: root.selectedEntry && root.selectedEntry.isDefault ?
                i18nc("@action:menu", "Already Default") :
                i18nc("@action:menu", "Set as Default")
            icon.name: "starred"
            enabled: root.selectedEntry && !root.selectedEntry.isDefault && !kcm.manager.busy
            onTriggered: {
                if (root.selectedEntry) {
                    kcm.manager.setDefault(root.selectedEntry.entryId)
                }
            }
        }
        QQC.MenuItem {
            text: i18nc("@action:menu", "Verify Files")
            icon.name: "document-open-folder"
            enabled: root.selectedEntry && !kcm.manager.busy
            onTriggered: {
                if (root.selectedEntry) {
                    kcm.manager.verifyEntryFiles(root.selectedEntry.entryId)
                }
            }
        }
        QQC.MenuItem {
            text: i18nc("@action:menu", "Repair Entry")
            icon.name: "tools-repair"
            enabled: root.selectedEntry && !kcm.manager.busy
            onTriggered: {
                if (root.selectedEntry) {
                    kcm.manager.repairEntry(root.selectedEntry.entryId)
                }
            }
        }
        QQC.MenuItem {
            id: favoriteMenuItem
            text: i18nc("@action:menu", "Add to Favorites")
            icon.name: "bookmark-new"
            enabled: root.selectedEntry && !kcm.manager.busy
            onTriggered: {
                if (root.selectedEntry) {
                    kcm.manager.toggleEntryFavorite(root.selectedEntry.entryId)
                }
            }
        }
        QQC.MenuItem {
            text: i18nc("@action:menu", "Test Entry")
            icon.name: "system-run"
            enabled: root.selectedEntry && !kcm.manager.busy
            onTriggered: {
                if (root.selectedEntry) {
                    kcm.manager.testBootEntry(root.selectedEntry.entryId)
                }
            }
        }
        QQC.MenuItem {
            text: i18nc("@action:menu", "Analyze Dependencies")
            icon.name: "view-list-tree"
            enabled: root.selectedEntry && !kcm.manager.busy
            onTriggered: {
                if (root.selectedEntry) {
                    kcm.manager.analyzeDependencies(root.selectedEntry.entryId)
                }
            }
        }
        QQC.MenuItem {
            text: root.selectedEntry && root.selectedEntry.isBootNext ?
                i18nc("@action:menu", "Already Next Boot") :
                i18nc("@action:menu", "Boot Once Next")
            icon.name: "system-reboot"
            enabled: root.selectedEntry && !root.selectedEntry.isBootNext && !kcm.manager.busy
            onTriggered: {
                if (root.selectedEntry) {
                    kcm.manager.rebootTo(root.selectedEntry.entryId)
                }
            }
        }
        QQC.MenuSeparator {}
        QQC.MenuItem {
            text: i18nc("@action:menu", "Refresh All")
            icon.name: "view-refresh"
            enabled: !kcm.manager.busy
            onTriggered: kcm.manager.refresh()
        }
    }

    QQC.Dialog {
        id: resultDialog
        title: resultDialog.resultDialogSuccess ? i18nc("@title", "Success") : i18nc("@title", "Error")
        modal: true
        property bool resultDialogSuccess: true
        property string resultMessage: ""

        standardButtons: QQC.Dialog.Ok

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: resultDialog.resultDialogSuccess ? "dialog-ok" : "dialog-error"
                    color: resultDialog.resultDialogSuccess ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                }

                QQC.Label {
                    text: resultDialog.resultMessage
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }
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

    EntryDetailsDialog {
        id: entryDetailsDialog
    }

    QQC.Dialog {
        id: diagnosticsDialog
        title: i18nc("@title", "EFI System Diagnostics")
        modal: true
        width: Kirigami.Units.gridUnit * 40
        height: Kirigami.Units.gridUnit * 30

        property var diagnostics: ({})

        contentItem: ScrollView {
            clip: true

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                width: Kirigami.Units.gridUnit * 38

                // EFI Status
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "EFI Status")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "EFI Available:")
                            }
                            QQC.Label {
                                text: diagnosticsDialog.diagnostics.efiAvailable ?
                                    i18nc("@label", "Yes") : i18nc("@label", "No")
                                font.weight: Font.Bold
                                color: diagnosticsDialog.diagnostics.efiAvailable ?
                                    Kirigami.Theme.positiveTextColor :
                                    Kirigami.Theme.negativeTextColor
                            }
                        }

                        QQC.Label {
                            text: diagnosticsDialog.diagnostics.efiError || ""
                            visible: text !== ""
                            color: Kirigami.Theme.negativeTextColor
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        ColumnLayout {
                            visible: !diagnosticsDialog.diagnostics.efiAvailable &&
                                      diagnosticsDialog.diagnostics.suggestions !== undefined
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Suggestions:")
                                font.weight: Font.Bold
                            }

                            Repeater {
                                model: diagnosticsDialog.diagnostics.suggestions || []
                                QQC.Label {
                                    text: "• " + modelData
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    leftPadding: Kirigami.Units.smallSpacing * 2
                                }
                            }
                        }
                    }
                }

                // Boot Configuration
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: diagnosticsDialog.diagnostics.efiAvailable
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Boot Configuration")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Boot Order:")
                            }
                            QQC.Label {
                                text: i18nc("@label", "%1 entries", diagnosticsDialog.diagnostics.bootOrderCount || 0)
                                font.weight: Font.Bold
                            }
                        }

                        QQC.Label {
                            text: "BootOrder: " + (diagnosticsDialog.diagnostics.bootOrder || []).join(", ")
                            wrapMode: Text.WrapAnywhere
                            Layout.fillWidth: true
                            font: Kirigami.Theme.smallFont
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Current Boot:")
                            }
                            QQC.Label {
                                text: diagnosticsDialog.diagnostics.bootCurrent || "Unknown"
                                font.weight: Font.Bold
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Boot Next:")
                            }
                            QQC.Label {
                                text: diagnosticsDialog.diagnostics.bootNext || "Not set"
                                font.weight: Font.Bold
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Timeout:")
                            }
                            QQC.Label {
                                text: diagnosticsDialog.diagnostics.timeout >= 0 ?
                                    i18nc("@label", "%1 seconds", diagnosticsDialog.diagnostics.timeout) :
                                    i18nc("@label", "Not set")
                                font.weight: Font.Bold
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Total Entries:")
                            }
                            QQC.Label {
                                text: diagnosticsDialog.diagnostics.totalBootEntries || 0
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                // Capabilities
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: diagnosticsDialog.diagnostics.efiAvailable
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Firmware Capabilities")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "OsIndications Supported:")
                            }
                            QQC.Label {
                                text: diagnosticsDialog.diagnostics.osIndicationsSupported ?
                                    i18nc("@label", "Yes") : i18nc("@label", "No")
                                font.weight: Font.Bold
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Boot to Firmware:")
                            }
                            QQC.Label {
                                text: diagnosticsDialog.diagnostics.osIndicationsBootToFirmware ?
                                    i18nc("@label", "Available") : i18nc("@label", "Not Available")
                                font.weight: Font.Bold
                            }
                        }
                    }
                }

                // Firmware & Platform Information
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: diagnosticsDialog.diagnostics.efiAvailable
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Firmware & Platform Information")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        // Firmware Information Section
                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: diagnosticsDialog.diagnostics.firmwareVendor ||
                                     diagnosticsDialog.diagnostics.firmwareVersion

                            QQC.Label {
                                text: i18nc("@label", "Firmware")
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.95
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.firmwareVendor

                                QQC.Label {
                                    text: i18nc("@label", "Vendor:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.firmwareVendor || ""
                                    font.weight: Font.Medium
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.firmwareVersion

                                QQC.Label {
                                    text: i18nc("@label", "Version:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.firmwareVersion || ""
                                    font.weight: Font.Medium
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.firmwareDate

                                QQC.Label {
                                    text: i18nc("@label", "Release Date:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.firmwareDate || ""
                                    font.weight: Font.Medium
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.efiRuntimeVersion

                                QQC.Label {
                                    text: i18nc("@label", "EFI Runtime:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.efiRuntimeVersion || ""
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Kirigami.Separator {
                            visible: diagnosticsDialog.diagnostics.biosVendor ||
                                     diagnosticsDialog.diagnostics.biosVersion
                        }

                        // BIOS Information Section
                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: diagnosticsDialog.diagnostics.biosVendor ||
                                     diagnosticsDialog.diagnostics.biosVersion

                            QQC.Label {
                                text: i18nc("@label", "BIOS")
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.95
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.biosVendor

                                QQC.Label {
                                    text: i18nc("@label", "Vendor:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.biosVendor || ""
                                    font.weight: Font.Medium
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.biosVersion

                                QQC.Label {
                                    text: i18nc("@label", "Version:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.biosVersion || ""
                                    font.weight: Font.Medium
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.biosDate &&
                                         diagnosticsDialog.diagnostics.biosDate !== diagnosticsDialog.diagnostics.firmwareDate

                                QQC.Label {
                                    text: i18nc("@label", "Date:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.biosDate || ""
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Kirigami.Separator {
                            visible: diagnosticsDialog.diagnostics.boardVendor ||
                                     diagnosticsDialog.diagnostics.boardName
                        }

                        // Board Information Section
                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: diagnosticsDialog.diagnostics.boardVendor ||
                                     diagnosticsDialog.diagnostics.boardName

                            QQC.Label {
                                text: i18nc("@label", "Motherboard")
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.95
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.boardVendor

                                QQC.Label {
                                    text: i18nc("@label", "Vendor:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.boardVendor || ""
                                    font.weight: Font.Medium
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.boardName

                                QQC.Label {
                                    text: i18nc("@label", "Model:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.boardName || ""
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Kirigami.Separator {
                            visible: diagnosticsDialog.diagnostics.platformName ||
                                     diagnosticsDialog.diagnostics.machineId
                        }

                        // Platform Information Section
                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: diagnosticsDialog.diagnostics.platformName ||
                                     diagnosticsDialog.diagnostics.machineId

                            QQC.Label {
                                text: i18nc("@label", "Platform")
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.95
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.platformName

                                QQC.Label {
                                    text: i18nc("@label", "Name:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.platformName || ""
                                    font.weight: Font.Medium
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: diagnosticsDialog.diagnostics.machineId

                                QQC.Label {
                                    text: i18nc("@label", "Machine ID:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: diagnosticsDialog.diagnostics.machineId || ""
                                    font.weight: Font.Medium
                                    font.family: "monospace"
                                }
                            }
                        }
                    }
                }

                // Health Status
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: diagnosticsDialog.diagnostics.efiAvailable
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "System Health")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        // Status messages
                        Repeater {
                            model: diagnosticsDialog.diagnostics.healthStatus || []
                            QQC.Label {
                                text: "✓ " + modelData
                                color: Kirigami.Theme.positiveTextColor
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        // Warning messages
                        Repeater {
                            model: diagnosticsDialog.diagnostics.healthWarnings || []
                            QQC.Label {
                                text: "⚠ " + modelData
                                color: Kirigami.Theme.negativeTextColor
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        standardButtons: QQC.Dialog.Close
    }

    QQC.Dialog {
        id: bootStatsDialog
        title: i18nc("@title", "Boot Performance Statistics")
        modal: true
        width: Kirigami.Units.gridUnit * 40
        height: Kirigami.Units.gridUnit * 35

        property var bootStats: ({})

        contentItem: ScrollView {
            clip: true

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                width: Kirigami.Units.gridUnit * 38

                // Boot Time Information
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Boot Time Information")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: bootStatsDialog.bootStats.currentBootTime !== undefined

                            QQC.Label {
                                text: i18nc("@label", "Boot Time:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: {
                                    if (!bootStatsDialog.bootStats.currentBootTime) return ""
                                    const dateTime = new Date(bootStatsDialog.bootStats.currentBootTime)
                                    return dateTime.toLocaleString()
                                }
                                font.weight: Font.Medium
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: bootStatsDialog.bootStats.kernelBootDateTime !== undefined

                            QQC.Label {
                                text: i18nc("@label", "Kernel Boot Time:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: {
                                    if (!bootStatsDialog.bootStats.kernelBootDateTime) return ""
                                    const dateTime = new Date(bootStatsDialog.bootStats.kernelBootDateTime)
                                    return dateTime.toLocaleString()
                                }
                                font.weight: Font.Medium
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: bootStatsDialog.bootStats.bootCurrent !== undefined

                            QQC.Label {
                                text: i18nc("@label", "Booted Entry:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: bootStatsDialog.bootStats.bootCurrent !== undefined ?
                                    "Boot" + bootStatsDialog.bootStats.bootCurrent.toString(16).toUpperCase().padStart(4, '0') : ""
                                font.weight: Font.Medium
                                font.family: "monospace"
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: bootStatsDialog.bootStats.bootId !== undefined

                            QQC.Label {
                                text: i18nc("@label", "Boot ID:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: bootStatsDialog.bootStats.bootId || ""
                                font.weight: Font.Medium
                                font.family: "monospace"
                            }
                        }
                    }
                }

                // System Uptime
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "System Uptime")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: bootStatsDialog.bootStats.uptimeFormatted !== undefined

                            Kirigami.Icon {
                                source: "clock"
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            }

                            QQC.Label {
                                text: bootStatsDialog.bootStats.uptimeFormatted || ""
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: bootStatsDialog.bootStats.uptimeSeconds !== undefined

                            QQC.Label {
                                text: i18nc("@label", "Total Uptime:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: i18nc("@label", "%1 seconds", bootStatsDialog.bootStats.uptimeSeconds || 0)
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // System Performance
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "System Performance")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        // Load Averages
                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: bootStatsDialog.bootStats.loadAverage1m !== undefined

                            QQC.Label {
                                text: i18nc("@label", "Load Average")
                                font.weight: Font.Medium
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                QQC.Label {
                                    text: i18nc("@label", "1 min:")
                                    opacity: 0.7
                                    font: Kirigami.Theme.smallFont
                                }
                                QQC.Label {
                                    text: bootStatsDialog.bootStats.loadAverage1m || ""
                                    font.weight: Font.Medium
                                    font: Kirigami.Theme.smallFont
                                }

                                QQC.Label {
                                    text: i18nc("@label", "5 min:"
                                    opacity: 0.7
                                    font: Kirigami.Theme.smallFont
                                }
                                QQC.Label {
                                    text: bootStatsDialog.bootStats.loadAverage5m || ""
                                    font.weight: Font.Medium
                                    font: Kirigami.Theme.smallFont
                                }

                                QQC.Label {
                                    text: i18nc("@label", "15 min:"
                                    opacity: 0.7
                                    font: Kirigami.Theme.smallFont
                                }
                                QQC.Label {
                                    text: bootStatsDialog.bootStats.loadAverage15m || ""
                                    font.weight: Font.Medium
                                    font: Kirigami.Theme.smallFont
                                }
                            }
                        }

                        Kirigami.Separator {
                            visible: bootStatsDialog.bootStats.runningProcesses !== undefined ||
                                     bootStatsDialog.bootStats.totalProcesses !== undefined
                        }

                        // Process Information
                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: bootStatsDialog.bootStats.runningProcesses !== undefined ||
                                     bootStatsDialog.bootStats.totalProcesses !== undefined

                            QQC.Label {
                                text: i18nc("@label", "Processes")
                                font.weight: Font.Medium
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: bootStatsDialog.bootStats.runningProcesses !== undefined

                                QQC.Label {
                                    text: i18nc("@label", "Running:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: bootStatsDialog.bootStats.runningProcesses || 0
                                    font.weight: Font.Medium
                                }
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                visible: bootStatsDialog.bootStats.totalProcesses !== undefined

                                QQC.Label {
                                    text: i18nc("@label", "Total:")
                                    opacity: 0.7
                                }
                                QQC.Label {
                                    text: bootStatsDialog.bootStats.totalProcesses || 0
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }
            }
        }

        standardButtons: QQC.Dialog.Close
    }

    QQC.Dialog {
        id: bootHistoryDialog
        title: i18nc("@title", "Boot History")
        modal: true
        width: Kirigami.Units.gridUnit * 50
        height: Kirigami.Units.gridUnit * 40

        property var bootHistory: []

        contentItem: ScrollView {
            clip: true

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                width: Kirigami.Units.gridUnit * 48

                // Summary Card
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Boot History Summary")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            QQC.Label {
                                text: i18nc("@label", "Total Boots Recorded:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: bootHistoryDialog.bootHistory.length || 0
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing
                            visible: bootHistoryDialog.bootHistory.length > 0

                            QQC.Label {
                                text: i18nc("@label", "Most Recent Boot:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: {
                                    if (bootHistoryDialog.bootHistory.length === 0) return ""
                                    const latest = bootHistoryDialog.bootHistory[0]
                                    if (!latest || !latest.bootDateTime) return ""
                                    const dateTime = new Date(latest.bootDateTime)
                                    return dateTime.toLocaleString()
                                }
                                font.weight: Font.Medium
                            }
                        }
                    }
                }

                // History List
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Recent Boot Sessions")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                model: bootHistoryDialog.bootHistory.length
                                delegate: Kirigami.AbstractListItem {
                                    width: ListView.view.width
                                    highlighted: false

                                    property var historyEntry: bootHistoryDialog.bootHistory[index] || {}

                                    contentItem: RowLayout {
                                        spacing: Kirigami.Units.largeSpacing

                                        // Boot icon
                                        Kirigami.Icon {
                                            source: "system-boot"
                                            implicitWidth: Kirigami.Units.iconSizes.medium
                                            implicitHeight: Kirigami.Units.iconSizes.medium
                                        }

                                        // Boot info column
                                        ColumnLayout {
                                            spacing: Kirigami.Units.smallSpacing
                                            Layout.fillWidth: true

                                            // Entry name
                                            QQC.Label {
                                                text: historyEntry.entryName || i18nc("@item:inlistbox", "Unknown Entry")
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            // Entry ID and time
                                            QQC.Label {
                                                text: {
                                                    const entryId = historyEntry.entryId || ""
                                                    const dateTime = historyEntry.bootDateTime ? new Date(historyEntry.bootDateTime).toLocaleString() : ""
                                                    return entryId + " • " + dateTime
                                                }
                                                font: Kirigami.Theme.smallFont
                                                opacity: 0.7
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        // Boot count badge
                                        Rectangle {
                                            implicitWidth: Kirigami.Units.gridUnit * 2.5
                                            implicitHeight: Kirigami.Units.gridUnit * 1.5
                                            radius: width / 2
                                            color: Kirigami.Theme.backgroundColor

                                            QQC.Label {
                                                anchors.centerIn: parent
                                                text: "#" + (index + 1)
                                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.8
                                                font.weight: Font.Bold
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Boot Frequency Analysis
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: bootHistoryDialog.bootHistory.length > 0
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Boot Frequency Analysis")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        // Count boots per entry
                        Repeater {
                            model: {
                                // Calculate boot counts per entry
                                const counts = {}
                                for (let i = 0; i < bootHistoryDialog.bootHistory.length; i++) {
                                    const entry = bootHistoryDialog.bootHistory[i]
                                    if (entry && entry.entryName) {
                                        const name = entry.entryName
                                        counts[name] = (counts[name] || 0) + 1
                                    }
                                }
                                // Convert to array and sort
                                const result = []
                                for (const name in counts) {
                                    result.push({ name: name, count: counts[name] })
                                }
                                result.sort((a, b) => b.count - a.count)
                                return result.slice(0, 5) // Top 5
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                QQC.Label {
                                    text: modelData.name || ""
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // Progress bar
                                Rectangle {
                                    implicitWidth: Kirigami.Units.gridUnit * 8
                                    implicitHeight: Kirigami.Units.gridUnit * 0.5
                                    radius: height / 2
                                    color: Kirigami.Theme.backgroundColor

                                    Rectangle {
                                        width: parent.width * (modelData.count / Math.max(1, bootHistoryDialog.bootHistory.length))
                                        height: parent.height
                                        radius: parent.radius
                                        color: Kirigami.Theme.positiveTextColor
                                    }
                                }

                                QQC.Label {
                                    text: modelData.count || 0
                                    font.weight: Font.Medium
                                    font: Kirigami.Theme.smallFont
                                }
                            }
                        }
                    }
                }
            }
        }

        standardButtons: QQC.Dialog.Close
    }

    QQC.Dialog {
        id: validationDialog
        title: i18nc("@title", "Boot Entry Validation Results")
        modal: true
        width: Kirigami.Units.gridUnit * 45
        height: Kirigami.Units.gridUnit * 35

        property var issues: []

        contentItem: ScrollView {
            clip: true

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                width: Kirigami.Units.gridUnit * 43

                // Summary Card
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Validation Summary")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            QQC.Label {
                                text: i18nc("@label", "Issues Found:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: validationDialog.issues.length || 0
                                font.weight: Font.Bold
                                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                                color: validationDialog.issues.length === 0 ?
                                    Kirigami.Theme.positiveTextColor :
                                    (validationDialog.issues.length > 5 ?
                                        Kirigami.Theme.negativeTextColor :
                                        Kirigami.Theme.neutralTextColor)
                            }
                        }
                    }
                }

                // Issues List
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: validationDialog.issues.length > 0
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Detected Issues")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            ListView {
                                model: validationDialog.issues.length
                                delegate: Kirigami.AbstractListItem {
                                    width: ListView.view.width
                                    highlighted: false
                                    backgroundColor: {
                                        if (!modelData) return "transparent"
                                        const severity = validationDialog.issues[index].severity
                                        if (severity === "error") return Qt.rgba(0.96, 0.26, 0.21, 0.1)
                                        if (severity === "warning") return Qt.rgba(0.98, 0.65, 0.02, 0.1)
                                        return "transparent"
                                    }

                                    property var issue: validationDialog.issues[index] || {}

                                    contentItem: RowLayout {
                                        spacing: Kirigami.Units.largeSpacing

                                        // Severity icon
                                        Kirigami.Icon {
                                            source: {
                                                const severity = issue.severity
                                                if (severity === "error") return "dialog-error"
                                                if (severity === "warning") return "dialog-warning"
                                                return "dialog-information"
                                            }
                                            implicitWidth: Kirigami.Units.iconSizes.medium
                                            implicitHeight: Kirigami.Units.iconSizes.medium
                                            color: {
                                                const severity = issue.severity
                                                if (severity === "error") return Kirigami.Theme.negativeTextColor
                                                if (severity === "warning") return Kirigami.Theme.neutralTextColor
                                                return Kirigami.Theme.positiveTextColor
                                            }
                                        }

                                        // Issue details
                                        ColumnLayout {
                                            spacing: Kirigami.Units.smallSpacing
                                            Layout.fillWidth: true

                                            QQC.Label {
                                                text: issue.message || ""
                                                font.weight: Font.Medium
                                                Layout.fillWidth: true
                                                wrapMode: Text.WordWrap
                                            }

                                            QQC.Label {
                                                text: {
                                                    const entryId = issue.entryId
                                                    if (entryId && entryId !== 0) {
                                                        return i18nc("@info:label", "Entry: %1").arg("Boot" + Number(entryId).toString(16).toUpperCase().padStart(4, '0'))
                                                    }
                                                    return ""
                                                }
                                                font: Kirigami.Theme.smallFont
                                                opacity: 0.7
                                                visible: issue.entryId && issue.entryId !== 0
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // No Issues Message
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: validationDialog.issues.length === 0
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            source: "dialog-ok"
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: Kirigami.Units.iconSizes.huge
                            implicitHeight: Kirigami.Units.iconSizes.huge
                            color: Kirigami.Theme.positiveTextColor
                        }

                        QQC.Label {
                            text: i18nc("@info", "No Issues Detected")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                            Layout.alignment: Qt.AlignHCenter
                        }

                        QQC.Label {
                            text: i18nc("@info", "All boot entries appear to be properly configured")
                            Layout.alignment: Qt.AlignHCenter
                            opacity: 0.7
                        }
                    }
                }
            }
        }

        standardButtons: QQC.Dialog.Close
    }

    QQC.Dialog {
        id: compareDialog
        title: i18nc("@title", "Compare Boot Entries")
        modal: true
        width: Kirigami.Units.gridUnit * 45
        height: Kirigami.Units.gridUnit * 35

        property var comparison: ({})

        contentItem: ScrollView {
            clip: true

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                width: Kirigami.Units.gridUnit * 43

                // Summary Card
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: compareDialog.comparison.identical ?
                                i18nc("@title", "Entries are Identical") :
                                i18nc("@title", "Entries Comparison")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                            color: compareDialog.comparison.identical ?
                                Kirigami.Theme.positiveTextColor :
                                Kirigami.Theme.textColor
                        }

                        Kirigami.Separator {}

                        // Entry 1
                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Entry 1:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: (compareDialog.comparison.entry1Name || "") +
                                    " (" + (compareDialog.comparison.entry1Id || 0).toString(16).toUpperCase() + ")"
                                font.weight: Font.Medium
                            }
                        }

                        QQC.Label {
                            text: compareDialog.comparison.entry1Path || ""
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            Layout.fillWidth: true
                        }

                        // Entry 2
                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Entry 2:")
                                opacity: 0.7
                            }
                            QQC.Label {
                                text: (compareDialog.comparison.entry2Name || "") +
                                    " (" + (compareDialog.comparison.entry2Id || 0).toString(16).toUpperCase() + ")"
                                font.weight: Font.Medium
                            }
                        }

                        QQC.Label {
                            text: compareDialog.comparison.entry2Path || ""
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            Layout.fillWidth: true
                        }
                    }
                }

                // Similarities
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: compareDialog.comparison.similarities &&
                              compareDialog.comparison.similarities.length > 0
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Similarities")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                            color: Kirigami.Theme.positiveTextColor
                        }

                        Kirigami.Separator {}

                        Repeater {
                            model: compareDialog.comparison.similarities || []

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: "dialog-ok"
                                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                    implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                    color: Kirigami.Theme.positiveTextColor
                                }

                                QQC.Label {
                                    text: modelData || ""
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // Differences
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: compareDialog.comparison.differences &&
                              compareDialog.comparison.differences.length > 0
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Differences")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                            color: Kirigami.Theme.neutralTextColor
                        }

                        Kirigami.Separator {}

                        Repeater {
                            model: compareDialog.comparison.differences || []

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: "dialog-information"
                                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                    implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                    color: Kirigami.Theme.neutralTextColor
                                }

                                QQC.Label {
                                    text: modelData || ""
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
        }

        standardButtons: QQC.Dialog.Close
    }

    QQC.Dialog {
        id: rebootToBiosConfirmationDialog
        title: i18nc("@title", "Confirm Reboot to BIOS")
        modal: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                Layout.fillWidth: true
                text: i18nc("@info", "Are you sure you want to reboot to BIOS/firmware setup?")
                wrapMode: Text.WordWrap
            }

            QQC.Label {
                Layout.fillWidth: true
                text: i18nc("@info", "This will restart your system and enter the firmware setup screen. Make sure to save any unsaved work before proceeding.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        standardButtons: QQC.Dialog.Yes | QQC.Dialog.No

        onAccepted: {
            kcm.manager.rebootToBios()
        }
    }

    // Delete Confirmation Dialog
    QQC.Dialog {
        id: deleteConfirmationDialog
        property int entryId: 0
        property string entryName: ""

        title: i18nc("@title", "Confirm Delete Boot Entry")
        modal: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: "dialog-warning"
                    color: Kirigami.Theme.negativeTextColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                }

                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC.Label {
                        text: i18nc("@info", "Are you sure you want to delete this boot entry?")
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    QQC.Label {
                        text: i18nc("@info", "Entry: %1").arg(deleteConfirmationDialog.entryName)
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                    }

                    QQC.Label {
                        text: i18nc("@info", "This action cannot be undone. Make sure you have a backup before proceeding.")
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }
        }

        standardButtons: QQC.Dialog.Yes | QQC.Dialog.No

        onAccepted: {
            kcm.manager.deleteEntry(deleteConfirmationDialog.entryId)
        }
    }

    // Backup Dialog
    QQC.Dialog {
        id: backupDialog
        title: i18nc("@title", "Backup Boot Entries")
        modal: true

        property string backupFilePath: ""

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Save a backup of all EFI boot entries to a file.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC.TextField {
                    id: backupPathField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "/path/to/backup.json")
                    text: "~/efiboot-backup-" + new Date().toISOString().split('T')[0] + ".json"
                }

                QQC.Button {
                    text: i18nc("@action:button", "Browse...")
                    onClicked: {
                        // In a real implementation, this would open a file dialog
                        // For now, users can type the path directly
                        backupPathField.forceActiveFocus()
                    }
                }
            }

            QQC.Label {
                text: i18nc("@info", "The backup will include all boot entries, boot order, timeout settings, and BootNext configuration.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel

        onAccepted: {
            const path = backupPathField.text
            if (path.length > 0) {
                // Expand ~ to home directory
                let expandedPath = path
                if (path.startsWith("~/")) {
                    expandedPath = StandardPaths.home() + "/" + path.substring(2)
                }
                kcm.manager.backupEntries(expandedPath)
            }
        }
    }

    // Restore Dialog
    QQC.Dialog {
        id: restoreDialog
        title: i18nc("@title", "Restore Boot Entries")
        modal: true

        property string restoreFilePath: ""

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Restore EFI boot entries from a backup file.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC.TextField {
                    id: restorePathField
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "/path/to/backup.json")
                }

                QQC.Button {
                    text: i18nc("@action:button", "Browse...")
                    onClicked: {
                        restorePathField.forceActiveFocus()
                    }
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: true
                type: Kirigami.MessageType.Warning
                text: i18nc("@info", "Warning: Restoring will replace all current boot entries and settings. This cannot be undone.")
                showCloseButton: false
            }

            QQC.Label {
                text: i18nc("@info", "Make sure to create a backup before restoring if you want to preserve your current configuration.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel

        onAccepted: {
            const path = restorePathField.text
            if (path.length > 0) {
                // Expand ~ to home directory
                let expandedPath = path
                if (path.startsWith("~/")) {
                    expandedPath = StandardPaths.home() + "/" + path.substring(2)
                }
                kcm.manager.restoreEntries(expandedPath)
            }
        }
    }

    // Rename Dialog
    QQC.Dialog {
        id: renameDialog
        property int entryId: 0
        property string currentName: ""
        property alias newNameField: nameInput

        title: i18nc("@title", "Rename Boot Entry")
        modal: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Enter a new name for this boot entry:")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC.TextField {
                id: nameInput
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Enter new name...")
                selectByMouse: true
                maximumLength: 255

                // Enable OK button only when name is valid
                onTextChanged: {
                    renameDialog.standardButton(QQC.Dialog.Ok).enabled =
                        text.length > 0 && text.length <= 255 && text !== renameDialog.currentName
                }
            }

            QQC.Label {
                text: i18nc("@info", "Current name: %1").arg(renameDialog.currentName)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC.Label {
                text: i18nc("@info", "Note: The name change will take effect immediately but will only be visible in the boot loader on next reboot.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel

        Component.onCompleted: {
            // Disable OK button initially
            renameDialog.standardButton(QQC.Dialog.Ok).enabled = false
        }

        onOpened: {
            nameInput.forceActiveFocus()
            nameInput.selectAll()
        }

        onAccepted: {
            if (nameInput.text.length > 0 && nameInput.text !== renameDialog.currentName) {
                kcm.manager.renameEntry(renameDialog.entryId, nameInput.text)
            }
        }
    }

    // Clone Dialog
    QQC.Dialog {
        id: cloneDialog
        property int entryId: 0
        property string sourceName: ""
        property string suggestedName: ""
        property alias cloneNameField: cloneNameInput

        title: i18nc("@title", "Clone Boot Entry")
        modal: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Create a copy of this boot entry with a new name.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC.Label {
                text: i18nc("@info", "Source entry: %1").arg(cloneDialog.sourceName)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC.Label {
                    text: i18nc("@label", "Clone name:")
                    enabled: false
                }

                QQC.TextField {
                    id: cloneNameInput
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "Enter name for cloned entry...")
                    selectByMouse: true
                    maximumLength: 255

                    // Enable OK button only when name is valid and different
                    onTextChanged: {
                        cloneDialog.standardButton(QQC.Dialog.Ok).enabled =
                            text.length > 0 && text.length <= 255 && text !== cloneDialog.sourceName
                    }
                }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: true
                type: Kirigami.MessageType.Information
                text: i18nc("@info", "The cloned entry will be added to the end of your boot order.")
                showCloseButton: false
            }

            QQC.Label {
                text: i18nc("@info", "Note: The clone will have the same device path and settings as the original entry.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel

        Component.onCompleted: {
            cloneDialog.standardButton(QQC.Dialog.Ok).enabled = false
        }

        onOpened: {
            cloneNameInput.forceActiveFocus()
            cloneNameInput.selectAll()
        }

        onAccepted: {
            if (cloneNameInput.text.length > 0 && cloneNameInput.text !== cloneDialog.sourceName) {
                kcm.manager.cloneEntry(cloneDialog.entryId, cloneNameInput.text)
            }
        }
    }

    // Compare Selection Dialog
    QQC.Dialog {
        id: compareSelectionDialog
        property int firstEntryId: 0
        property string firstEntryName: ""
        property int secondEntryId: 0

        title: i18nc("@title", "Compare Boot Entries")
        modal: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Select another boot entry to compare with:")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC.Label {
                text: i18nc("@info", "First entry: %1").arg(compareSelectionDialog.firstEntryName)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                Layout.fillWidth: true
            }

            QQC.ComboBox {
                id: compareEntrySelector
                Layout.fillWidth: true
                model: kcm.manager.entries
                textRole: "name"
                valueRole: "entryId"

                property int selectedId: -1

                onActivated: {
                    compareSelectionDialog.secondEntryId = currentValue
                    compareSelectionDialog.standardButton(QQC.Dialog.Ok).enabled = (currentValue !== compareSelectionDialog.firstEntryId)
                }
            }
        }

        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel

        Component.onCompleted: {
            compareSelectionDialog.standardButton(QQC.Dialog.Ok).enabled = false
        }

        onAccepted: {
            if (compareEntrySelector.currentValue !== compareSelectionDialog.firstEntryId) {
                kcm.manager.compareEntries(compareSelectionDialog.firstEntryId, compareEntrySelector.currentValue)
            }
        }
    }

    // Boot Health Analysis Dialog
    QQC.Dialog {
        id: bootHealthDialog
        title: i18nc("@title", "Boot Configuration Health Analysis")
        modal: true
        width: Kirigami.Units.gridUnit * 45
        height: Kirigami.Units.gridUnit * 40

        property var analysis: ({})

        contentItem: ScrollView {
            clip: true

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                width: Kirigami.Units.gridUnit * 43

                // Overall Health Score
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Overall Health Score")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        // Score circle
                        RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Rectangle {
                                implicitWidth: Kirigami.Units.gridUnit * 6
                                implicitHeight: Kirigami.Units.gridUnit * 6
                                radius: width / 2
                                color: {
                                    const score = bootHealthDialog.analysis.overallScore || 0
                                    if (score >= 80) return Kirigami.Theme.positiveTextColor
                                    if (score >= 60) return "#FFC107"
                                    if (score >= 40) return "#FF9800"
                                    return Kirigami.Theme.negativeTextColor
                                }

                                QQC.Label {
                                    anchors.centerIn: parent
                                    text: (bootHealthDialog.analysis.overallScore || 0).toString()
                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 2
                                    font.weight: Font.Bold
                                    color: "white"
                                }
                            }

                            ColumnLayout {
                                spacing: Kirigami.Units.smallSpacing

                                QQC.Label {
                                    text: bootHealthDialog.analysis.healthStatus || ""
                                    font.weight: Font.Bold
                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                                }

                                QQC.Label {
                                    text: i18nc("@info", "%1 entries analyzed").arg(bootHealthDialog.analysis.totalEntries || 0)
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                }

                                RowLayout {
                                    spacing: Kirigami.Units.smallSpacing

                                    Rectangle {
                                        implicitWidth: Kirigami.Units.gridUnit * 0.8
                                        implicitHeight: Kirigami.Units.gridUnit * 0.8
                                        radius: width / 2
                                        color: Kirigami.Theme.negativeTextColor
                                        visible: (bootHealthDialog.analysis.criticalIssues || 0) > 0
                                    }

                                    QQC.Label {
                                        text: i18nc("@info", "%1 critical").arg(bootHealthDialog.analysis.criticalIssues || 0)
                                        font: Kirigami.Theme.smallFont
                                        color: Kirigami.Theme.negativeTextColor
                                        visible: (bootHealthDialog.analysis.criticalIssues || 0) > 0
                                    }

                                    Rectangle {
                                        implicitWidth: Kirigami.Units.gridUnit * 0.8
                                        implicitHeight: Kirigami.Units.gridUnit * 0.8
                                        radius: width / 2
                                        color: Kirigami.Theme.neutralTextColor
                                        visible: (bootHealthDialog.analysis.warnings || 0) > 0
                                    }

                                    QQC.Label {
                                        text: i18nc("@info", "%1 warnings").arg(bootHealthDialog.analysis.warnings || 0)
                                        font: Kirigami.Theme.smallFont
                                        color: Kirigami.Theme.neutralTextColor
                                        visible: (bootHealthDialog.analysis.warnings || 0) > 0
                                    }
                                }
                            }
                        }
                    }
                }

                // OS Distribution
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: bootHealthDialog.analysis.osDistribution !== undefined
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "OS Distribution")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        Repeater {
                            model: {
                                const osDist = bootHealthDialog.analysis.osDistribution || {}
                                const result = []
                                for (const os in osDist) {
                                    result.push({ os: os, count: osDist[os] })
                                }
                                result.sort((a, b) => b.count - a.count)
                                return result
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                QQC.Label {
                                    text: modelData.os || ""
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    implicitWidth: Kirigami.Units.gridUnit * 15
                                    implicitHeight: Kirigami.Units.gridUnit * 0.5
                                    radius: height / 2
                                    color: Kirigami.Theme.backgroundColor

                                    Rectangle {
                                        width: parent.width * (modelData.count / Math.max(1, bootHealthDialog.analysis.totalEntries || 1))
                                        height: parent.height
                                        radius: parent.radius
                                        color: {
                                            const os = modelData.os || ""
                                            if (os === "Windows") return "#0178C6"
                                            if (os === "Linux") return "#E95420"
                                            if (os === "macOS") return "#555555"
                                            return Kirigami.Theme.positiveTextColor
                                        }
                                    }
                                }

                                QQC.Label {
                                    text: modelData.count || 0
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }
                }

                // Recommendations
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    visible: bootHealthDialog.analysis.recommendations &&
                              bootHealthDialog.analysis.recommendations.length > 0
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Recommendations")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        Repeater {
                            model: bootHealthDialog.analysis.recommendations || []

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: "documentinfo"
                                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                    implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                }

                                QQC.Label {
                                    text: modelData || ""
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }

        standardButtons: QQC.Dialog.Close
    }

    // About/Help Dialog
    QQC.Dialog {
        id: aboutDialog
        title: i18nc("@title", "EFI Boot Manager - Help & Shortcuts")
        modal: true
        width: Kirigami.Units.gridUnit * 45
        height: Kirigami.Units.gridUnit * 35

        contentItem: ScrollView {
            clip: true

            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing
                width: Kirigami.Units.gridUnit * 40

                // About section
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                source: "system-boot"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                            }

                            ColumnLayout {
                                spacing: Kirigami.Units.smallSpacing

                                QQC.Label {
                                    text: i18nc("@title", "EFI Boot Manager")
                                    font.weight: Font.Bold
                                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.3
                                }

                                QQC.Label {
                                    text: i18nc("@info", "Manage EFI boot entries with ease")
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                }
                            }
                        }
                    }
                }

                // Keyboard shortcuts section
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Keyboard Shortcuts")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        // Shortcut items
                        Repeater {
                            model: [
                                {shortcut: "Ctrl+R", action: i18nc("@info", "Refresh boot entries")},
                                {shortcut: "Ctrl+F", action: i18nc("@info", "Focus search field")},
                                {shortcut: "Ctrl+D", action: i18nc("@info", "Show system diagnostics")},
                                {shortcut: "Ctrl+P", action: i18nc("@info", "Show boot performance statistics")},
                                {shortcut: "Ctrl+H", action: i18nc("@info", "Show boot history")},
                                {shortcut: "Ctrl+V", action: i18nc("@info", "Validate boot entries")},
                                {shortcut: "Ctrl+Shift+B", action: i18nc("@info", "Reboot to BIOS/firmware")},
                                {shortcut: "F1", action: i18nc("@info", "Show this help dialog")},
                                {shortcut: "Escape", action: i18nc("@info", "Close dialogs / Clear search")},
                                {shortcut: "↑ ↓ ← →", action: i18nc("@info", "Navigate between entries")},
                                {shortcut: "Enter", action: i18nc("@info", "View entry details")},
                            ]

                            RowLayout {
                                spacing: Kirigami.Units.largeSpacing

                                // Shortcut key
                                Rectangle {
                                    width: shortcutLabel.width + Kirigami.Units.smallSpacing * 2
                                    height: shortcutLabel.height + Kirigami.Units.smallSpacing
                                    color: Kirigami.Theme.backgroundColor
                                    border.color: Kirigami.Theme.disabledTextColor
                                    radius: Kirigami.Units.smallSpacing

                                    QQC.Label {
                                        id: shortcutLabel
                                        anchors.centerIn: parent
                                        text: modelData.shortcut
                                        font.family: "monospace"
                                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 0.9
                                    }
                                }

                                // Action description
                                QQC.Label {
                                    text: modelData.action
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }

                // Features section
                Kirigami.AbstractCard {
                    Layout.fillWidth: true
                    contentItem: ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Features")
                            font.weight: Font.Bold
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                        }

                        Kirigami.Separator {}

                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: "• " + i18nc("@info", "Smart OS detection with distro-specific icons")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "Visual feedback for operations (success/failure)")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "Search and filter boot entries")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "Set default boot order and timeout")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "One-time boot (BootNext) configuration")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "System diagnostics and health status")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "Backup and restore boot configuration")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "Delete unwanted boot entries")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "Rename boot entries")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "Hide/Show boot entries")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                            QQC.Label {
                                text: "• " + i18nc("@info", "Clone/duplicate boot entries")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }

        standardButtons: QQC.Dialog.Close
    }

    // Single entry verification result dialog
    QQC.Dialog {
        id: entryVerificationDialog
        title: i18nc("@title", "Boot Entry File Verification")
        modal: true
        property var verificationResult: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // Status indicator
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: {
                            const status = entryVerificationDialog.overallStatus || "ok"
                            if (status === "ok") return "dialog-ok"
                            if (status === "warning") return "dialog-warning"
                            return "dialog-error"
                        }
                        color: {
                            const status = entryVerificationDialog.overallStatus || "ok"
                            if (status === "ok") return Kirigami.Theme.positiveTextColor
                            if (status === "warning") return "#FFC107"
                            return Kirigami.Theme.negativeTextColor
                        }
                        Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                        Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: entryVerificationDialog.entryName || ""
                            font.weight: Font.Bold
                            font.pointSize: -1
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                        }

                        QQC.Label {
                            text: {
                                const status = entryVerificationDialog.overallStatus || "ok"
                                if (status === "ok") return i18nc("@info:status", "All files verified successfully")
                                if (status === "warning") return i18nc("@info:status", "Files verified with warnings")
                                return i18nc("@info:status", "File verification failed")
                            }
                            color: {
                                const status = entryVerificationDialog.overallStatus || "ok"
                                if (status === "ok") return Kirigami.Theme.positiveTextColor
                                if (status === "warning") return "#FFC107"
                                return Kirigami.Theme.negativeTextColor
                            }
                        }
                    }
                }

                Kirigami.Separator {}

                // Boot path
                QQC.Label {
                    text: i18nc("@label", "Boot Loader Path:")
                    font.weight: Font.Bold
                }
                QQC.Label {
                    text: entryVerificationDialog.path || ""
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                // Errors section
                QQC.Label {
                    text: i18nc("@label", "Errors:")
                    font.weight: Font.Bold
                    visible: (entryVerificationDialog.errors || []).length > 0
                }
                Repeater {
                    model: entryVerificationDialog.errors || []
                    QQC.Label {
                        text: "• " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: Kirigami.Theme.negativeTextColor
                    }
                }

                // Warnings section
                QQC.Label {
                    text: i18nc("@label", "Warnings:")
                    font.weight: Font.Bold
                    visible: (entryVerificationDialog.warnings || []).length > 0
                }
                Repeater {
                    model: entryVerificationDialog.warnings || []
                    QQC.Label {
                        text: "• " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: "#FFC107"
                    }
                }
            }
        }

        onOpened: {
            overallStatus = verificationResult.overallStatus
            entryName = verificationResult.entryName
            path = verificationResult.path
            errors = verificationResult.errors
            warnings = verificationResult.warnings
        }
    }

    // All entries verification result dialog
    QQC.Dialog {
        id: allEntriesVerificationDialog
        title: i18nc("@title", "Boot Entry File Verification Results")
        modal: true
        property var verificationResults: []

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // Summary
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: {
                            const results = allEntriesVerificationDialog.verificationResults || []
                            const errorCount = results.filter(r => r.overallStatus === "error").length
                            const warningCount = results.filter(r => r.overallStatus === "warning").length

                            if (errorCount > 0) return "dialog-error"
                            if (warningCount > 0) return "dialog-warning"
                            return "dialog-ok"
                        }
                        color: {
                            const results = allEntriesVerificationDialog.verificationResults || []
                            const errorCount = results.filter(r => r.overallStatus === "error").length
                            const warningCount = results.filter(r => r.overallStatus === "warning").length

                            if (errorCount > 0) return Kirigami.Theme.negativeTextColor
                            if (warningCount > 0) return "#FFC107"
                            return Kirigami.Theme.positiveTextColor
                        }
                        Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                        Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@title", "Verification Summary")
                            font.weight: Font.Bold
                            font.pointSize: -1
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                        }

                        QQC.Label {
                            text: {
                                const results = allEntriesVerificationDialog.verificationResults || []
                                const errorCount = results.filter(r => r.overallStatus === "error").length
                                const warningCount = results.filter(r => r.overallStatus === "warning").length
                                const okCount = results.filter(r => r.overallStatus === "ok").length

                                return i18nc("@info:status", "%1 OK, %2 Warnings, %3 Errors", okCount, warningCount, errorCount)
                            }
                        }
                    }
                }

                Kirigami.Separator {}

                // Individual entry results
                Repeater {
                    model: allEntriesVerificationDialog.verificationResults || []

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true

                        // Entry header with status
                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: {
                                    const status = modelData.overallStatus || "ok"
                                    if (status === "ok") return "dialog-ok"
                                    if (status === "warning") return "dialog-warning"
                                    return "dialog-error"
                                }
                                color: {
                                    const status = modelData.overallStatus || "ok"
                                    if (status === "ok") return Kirigami.Theme.positiveTextColor
                                    if (status === "warning") return "#FFC107"
                                    return Kirigami.Theme.negativeTextColor
                                }
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            }

                            QQC.Label {
                                text: modelData.entryName || ""
                                font.weight: Font.Bold
                            }

                            Item { Layout.fillWidth: true }

                            QQC.Label {
                                text: modelData.path || ""
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                            }
                        }

                        // Errors
                        Repeater {
                            model: modelData.errors || []
                            visible: modelData.errors.length > 0
                            QQC.Label {
                                text: "  • " + modelData
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.largeSpacing
                                color: Kirigami.Theme.negativeTextColor
                                font: Kirigami.Theme.smallFont
                            }
                        }

                        // Warnings
                        Repeater {
                            model: modelData.warnings || []
                            visible: modelData.warnings.length > 0
                            QQC.Label {
                                text: "  • " + modelData
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                Layout.leftMargin: Kirigami.Units.largeSpacing
                                color: "#FFC107"
                                font: Kirigami.Theme.smallFont
                            }
                        }

                        Kirigami.Separator {
                            Layout.fillWidth: true
                            visible: index < (allEntriesVerificationDialog.verificationResults || []).length - 1
                        }
                    }
                }
            }
        }
    }

    // Secure Boot Status Dialog
    QQC.Dialog {
        id: secureBootDialog
        title: i18nc("@title", "Secure Boot Status")
        modal: true
        property var status: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // Status indicator
            RowLayout {
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: {
                        if (!secureBootDialog.status.supported) return "dialog-cancel"
                        return secureBootDialog.status.enabled ? "security-high" : "security-medium"
                    }
                    color: {
                        if (!secureBootDialog.status.supported) return Kirigami.Theme.negativeTextColor
                        return secureBootDialog.status.enabled ? Kirigami.Theme.positiveTextColor : "#FFC107"
                    }
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                }

                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC.Label {
                        text: secureBootDialog.status.message || ""
                        font.weight: Font.Bold
                        font.pointSize: -1
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                        color: {
                            if (!secureBootDialog.status.supported) return Kirigami.Theme.negativeTextColor
                            return secureBootDialog.status.enabled ? Kirigami.Theme.positiveTextColor : "#FFC107"
                        }
                    }

                    QQC.Label {
                        text: i18nc("@info:status", "UEFI Secure Boot Technology")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }

            Kirigami.Separator {}

            // Details
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC.Label {
                    text: i18nc("@label", "Details:")
                    font.weight: Font.Bold
                }

                QQC.Label {
                    text: i18nc("@info:label", "Supported: %1",
                               secureBootDialog.status.supported ?
                               i18nc("@info:status", "Yes") : i18nc("@info:status", "No"))
                }

                QQC.Label {
                    text: i18nc("@info:label", "Enabled: %1",
                               secureBootDialog.status.enabled ?
                               i18nc("@info:status", "Yes") : i18nc("@info:status", "No"))
                    visible: secureBootDialog.status.supported
                }

                QQC.Label {
                    text: secureBootDialog.status.setupModeMessage || ""
                    visible: secureBootDialog.status.setupModeMessage !== undefined
                    wrapMode: Text.WordWrap
                }

                QQC.Label {
                    text: i18nc("@info", "Secure Boot helps protect your system from malware and unauthorized boot loaders. It ensures that only trusted software can run during boot.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                }
            }
        }
    }

    // Firmware Info Dialog
    QQC.Dialog {
        id: firmwareInfoDialog
        title: i18nc("@title", "Firmware and System Information")
        modal: true
        property var info: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // Firmware type
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: "computer-chip"
                        color: Kirigami.Theme.highlightColor
                        Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                        Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: firmwareInfoDialog.info.firmwareType || ""
                            font.weight: Font.Bold
                            font.pointSize: -1
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                        }

                        QQC.Label {
                            text: i18nc("@info:status", "Firmware Type")
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                }

                Kirigami.Separator {}

                // System Information
                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: firmwareInfoDialog.info.systemVendor !== undefined ||
                             firmwareInfoDialog.info.productName !== undefined

                    QQC.Label {
                        text: i18nc("@title", "System Information")
                        font.weight: Font.Bold
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Manufacturer: %1", firmwareInfoDialog.info.systemVendor || "")
                        visible: firmwareInfoDialog.info.systemVendor !== undefined
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Product: %1", firmwareInfoDialog.info.productName || "")
                        visible: firmwareInfoDialog.info.productName !== undefined
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Version: %1", firmwareInfoDialog.info.productVersion || "")
                        visible: firmwareInfoDialog.info.productVersion !== undefined
                    }
                }

                // Board Information
                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: firmwareInfoDialog.info.boardVendor !== undefined ||
                             firmwareInfoDialog.info.boardName !== undefined

                    QQC.Label {
                        text: i18nc("@title", "Board Information")
                        font.weight: Font.Bold
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Vendor: %1", firmwareInfoDialog.info.boardVendor || "")
                        visible: firmwareInfoDialog.info.boardVendor !== undefined
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Board: %1", firmwareInfoDialog.info.boardName || "")
                        visible: firmwareInfoDialog.info.boardName !== undefined
                    }
                }

                // BIOS Information
                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: firmwareInfoDialog.info.biosVendor !== undefined ||
                             firmwareInfoDialog.info.biosVersion !== undefined ||
                             firmwareInfoDialog.info.biosDate !== undefined

                    QQC.Label {
                        text: i18nc("@title", "BIOS/Firmware Information")
                        font.weight: Font.Bold
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Vendor: %1", firmwareInfoDialog.info.biosVendor || "")
                        visible: firmwareInfoDialog.info.biosVendor !== undefined
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Version: %1", firmwareInfoDialog.info.biosVersion || "")
                        visible: firmwareInfoDialog.info.biosVersion !== undefined
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Release Date: %1", firmwareInfoDialog.info.biosDate || "")
                        visible: firmwareInfoDialog.info.biosDate !== undefined
                    }
                }

                // EFI Information
                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: firmwareInfoDialog.info.efiVarsAvailable !== undefined

                    QQC.Label {
                        text: i18nc("@title", "EFI Information")
                        font.weight: Font.Bold
                    }

                    RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: firmwareInfoDialog.info.efiVarsAvailable ? "dialog-ok" : "dialog-cancel"
                            color: firmwareInfoDialog.info.efiVarsAvailable ?
                                   Kirigami.Theme.positiveTextColor :
                                   Kirigami.Theme.negativeTextColor
                        }

                        QQC.Label {
                            text: firmwareInfoDialog.info.efiVarsAvailable ?
                                   i18nc("@info:status", "EFI variables are available") :
                                   i18nc("@info:status", "EFI variables are not available")
                        }
                    }
                }
            }
        }
    }

    // Entry Repair Dialog
    QQC.Dialog {
        id: entryRepairDialog
        title: i18nc("@title", "Boot Entry Repair Results")
        modal: true
        property var repairResult: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // Status indicator
            RowLayout {
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: entryRepairDialog.repairResult.needsManualRepair ? "dialog-warning" : "dialog-ok"
                    color: entryRepairDialog.repairResult.needsManualRepair ?
                           Kirigami.Theme.negativeTextColor :
                           Kirigami.Theme.positiveTextColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                }

                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC.Label {
                        text: entryRepairDialog.repairResult.entryName || ""
                        font.weight: Font.Bold
                        font.pointSize: -1
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                    }

                    QQC.Label {
                        text: entryRepairDialog.repairResult.message || ""
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }

            Kirigami.Separator {}

            // Repairs made
            QQC.Label {
                text: i18nc("@label", "Repairs Made:")
                font.weight: Font.Bold
                visible: (entryRepairDialog.repairResult.repairsMade || []).length > 0
            }
            Repeater {
                model: entryRepairDialog.repairResult.repairsMade || []
                QQC.Label {
                    text: "✓ " + modelData
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: Kirigami.Theme.positiveTextColor
                }
            }

            // Issues that cannot be auto-repaired
            QQC.Label {
                text: i18nc("@label", "Requires Manual Repair:")
                font.weight: Font.Bold
                visible: (entryRepairDialog.repairResult.cannotRepair || []).length > 0
            }
            Repeater {
                model: entryRepairDialog.repairResult.cannotRepair || []
                QQC.Label {
                    text: "⚠ " + modelData
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: "#FF9800"
                }
            }

            // Suggestions
            QQC.Label {
                text: i18nc("@info", "Manual repair options:")
                font.weight: Font.Bold
                visible: entryRepairDialog.repairResult.needsManualRepair
            }
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                visible: entryRepairDialog.repairResult.needsManualRepair
                QQC.Label {
                    text: "• " + i18nc("@info", "Rename the entry to give it a proper name")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                }
                QQC.Label {
                    text: "• " + i18nc("@info", "Edit the entry to set the correct boot loader path")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                }
                QQC.Label {
                    text: "• " + i18nc("@info", "Toggle visibility if the entry should be shown")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                }
                QQC.Label {
                    text: "• " + i18nc("@info", "Delete the entry if it's no longer needed")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                }
            }
        }
    }

    // Auto Repair Dialog
    QQC.Dialog {
        id: autoRepairDialog
        title: i18nc("@title", "Boot Entry Auto Repair Results")
        modal: true
        property var results: {}

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // Summary
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Kirigami.Icon {
                        source: autoRepairDialog.results.needsManualRepair > 0 ? "dialog-warning" : "dialog-ok"
                        color: autoRepairDialog.results.needsManualRepair > 0 ?
                               Kirigami.Theme.negativeTextColor :
                               Kirigami.Theme.positiveTextColor
                        Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                        Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: autoRepairDialog.results.summary || ""
                            font.weight: Font.Bold
                            font.pointSize: -1
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                        }

                        QQC.Label {
                            text: i18nc("@info:status", "Scan Complete")
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                }

                Kirigami.Separator {}

                // Statistics
                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC.Label {
                        text: i18nc("@title", "Statistics")
                        font.weight: Font.Bold
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Total Entries: %1", autoRepairDialog.results.totalEntries || 0)
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Healthy Entries: %1", autoRepairDialog.results.healthyEntries || 0)
                        color: Kirigami.Theme.positiveTextColor
                    }

                    QQC.Label {
                        text: i18nc("@info:label", "Entries Needing Manual Repair: %1", autoRepairDialog.results.needsManualRepair || 0)
                        color: autoRepairDialog.results.needsManualRepair > 0 ?
                               Kirigami.Theme.negativeTextColor :
                               Kirigami.Theme.positiveTextColor
                    }
                }

                // Issues found
                QQC.Label {
                    text: i18nc("@title", "Issues Found")
                    font.weight: Font.Bold
                    visible: (autoRepairDialog.results.issues || []).length > 0
                }

                Repeater {
                    model: autoRepairDialog.results.issues || []
                    QQC.Label {
                        text: "⚠ " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: "#FF9800"
                        font: Kirigami.Theme.smallFont
                    }
                }

                // Help text
                QQC.Label {
                    text: i18nc("@info", "To manually repair entries:")
                    font.weight: Font.Bold
                    visible: autoRepairDialog.results.needsManualRepair > 0
                }

                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    visible: autoRepairDialog.results.needsManualRepair > 0

                    QQC.Label {
                        text: "• " + i18nc("@info", "Right-click on an entry and select 'Repair Entry' for detailed analysis")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                    }
                    QQC.Label {
                        text: "• " + i18nc("@info", "Use 'Edit Entry' to fix path or name issues")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                    }
                    QQC.Label {
                        text: "• " + i18nc("@info", "Use 'Rename Entry' to give entries proper names")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                    }
                    QQC.Label {
                        text: "• " + i18nc("@info", "Delete entries that are no longer needed")
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }
    }

    // Template Selection Dialog
    QQC.Dialog {
        id: templateSelectionDialog
        title: i18nc("@title", "Create Boot Entry from Template")
        modal: true

        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Select a template to create a new boot entry:")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC.ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 15

                ListView {
                    id: templateListView
                    model: ListModel {
                        ListElement {
                            name: "Windows Boot Manager"
                            templateId: "windows"
                            icon: "dialog-warning"
                            description: "Windows Boot Manager (bootmgfw.efi)"
                        }
                        ListElement {
                            name: "Ubuntu (GRUB)"
                            templateId: "ubuntu"
                            icon: "ubuntu"
                            description: "Ubuntu GNU/Linux with GRUB bootloader"
                        }
                        ListElement {
                            name: "Fedora (GRUB)"
                            templateId: "fedora"
                            icon: "fedora"
                            description: "Fedora Linux with GRUB bootloader"
                        }
                        ListElement {
                            name: "Arch Linux (GRUB)"
                            templateId: "arch"
                            icon: "archlinux"
                            description: "Arch Linux with GRUB bootloader"
                        }
                        ListElement {
                            name: "Debian (GRUB)"
                            templateId: "debian"
                            icon: "debian"
                            description: "Debian GNU/Linux with GRUB bootloader"
                        }
                        ListElement {
                            name: "openSUSE (GRUB)"
                            templateId: "opensuse"
                            icon: "opensuse"
                            description: "openSUSE with GRUB bootloader"
                        }
                        ListElement {
                            name: "systemd-boot"
                            templateId: "systemd"
                            icon: "system"
                            description: "systemd-boot EFI bootloader"
                        }
                        ListElement {
                            name: "rEFInd Boot Manager"
                            templateId: "refind"
                            icon: "view-preview"
                            description: "rEFInd graphical boot manager"
                        }
                    }

                    delegate: QQC.ItemDelegate {
                        width: templateListView.width
                        highlighted: templateListView.currentIndex === index

                        onClicked: {
                            templateListView.currentIndex = index
                        }

                        onDoubleClicked: {
                            templateListView.currentIndex = index
                            templateSelectionDialog.accept()
                        }

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                source: model.icon
                                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            }

                            ColumnLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Layout.fillWidth: true

                                QQC.Label {
                                    text: model.name
                                    font.weight: templateListView.currentIndex === index ? Font.Bold : Font.Normal
                                }

                                QQC.Label {
                                    text: model.description
                                    font: Kirigami.Theme.smallFont
                                    opacity: 0.7
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    highlight: QQC.Rectangle {
                        color: Kirigami.Theme.highlightColor
                        opacity: 0.3
                        radius: Kirigami.Units.smallSpacing
                    }

                    QQC.ScrollBar.vertical: QQC.ScrollBar {}
                }
            }

            // Custom name field
            QQC.Label {
                text: i18nc("@label", "Custom name (optional):")
                visible: customNameField.visible
            }
            QQC.TextField {
                id: customNameField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Leave empty to use default name")
            }
        }

        onAccepted: {
            if (templateListView.currentIndex >= 0) {
                const template = templateListView.model.get(templateListView.currentIndex)
                kcm.manager.createEntryFromTemplate(template.templateId, customNameField.text)
                customNameField.text = ""
            }
        }

        onRejected: {
            customNameField.text = ""
        }
    }

    // Favorites Panel (shown as a sidebar or overlay)
    Kirigami.OverlaySheet {
        id: favoritesSheet
        title: i18nc("@title", "Favorite Boot Entries")
        property var favorites: []

        onOpened: {
            favorites = kcm.manager.getFavorites()
        }

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Quick access to your favorite boot entries")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Kirigami.Separator {}

            ListView {
                id: favoritesListView
                model: favoritesSheet.favorites.length
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(Kirigami.Units.gridUnit * 20,
                                                   favoritesSheet.favorites.length * Kirigami.Units.gridUnit * 4)

                delegate: QQC.ItemDelegate {
                    width: favoritesListView.width
                    highlighted: favoritesListView.currentIndex === index

                    onClicked: {
                        const favorite = favoritesSheet.favorites[index]
                        const details = kcm.manager.detailsForEntry(favorite.entryId)
                        entryDetailsDialog.details = details
                        entryDetailsDialog.open()
                    }

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            source: "documentinfo"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }

                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Layout.fillWidth: true

                            QQC.Label {
                                text: favoritesSheet.favorites[index].name || ""
                                font.weight: Font.Bold
                            }

                            RowLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Kirigami.Icon {
                                    source: "starred"
                                    visible: favoritesSheet.favorites[index].isDefault || false
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }

                                QQC.Label {
                                    text: favoritesSheet.favorites[index].isDefault ?
                                           i18nc("@info:status", "Default") : ""
                                    font: Kirigami.Theme.smallFont
                                    color: Kirigami.Theme.highlightColor
                                }

                                Kirigami.Icon {
                                    source: "arrow-right"
                                    visible: favoritesSheet.favorites[index].isCurrent || false
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                }

                                QQC.Label {
                                    text: favoritesSheet.favorites[index].isCurrent ?
                                           i18nc("@info:status", "Current") : ""
                                    font: Kirigami.Theme.smallFont
                                    color: Kirigami.Theme.positiveTextColor
                                }
                            }
                        }

                        QQC.ToolButton {
                            icon.name: "go-next"
                            onClicked: {
                                const favorite = favoritesSheet.favorites[index]
                                kcm.manager.setDefault(favorite.entryId)
                            }
                            tooltip: i18nc("@info:tooltip", "Set as default")
                        }
                    }
                }

                QQC.Label {
                    visible: favoritesListView.count === 0
                    text: i18nc("@info:placeholder", "No favorites yet.\nRight-click an entry and select 'Add to Favorites'")
                    horizontalAlignment: Text.AlignHCenter
                    anchors.centerIn: parent
                    opacity: 0.7
                }
            }

            // Show Favorites action button
            QQC.Button {
                text: i18nc("@action:button", "Show Favorites")
                icon.name: "bookmark"
                Layout.alignment: Qt.AlignHCenter
                onClicked: {
                    favoritesSheet.open()
                }
            }
        }
    }

    // Entry Test Dialog
    QQC.Dialog {
        id: entryTestDialog
        title: i18nc("@title", "Boot Entry Test Results")
        modal: true
        property var testResult: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // Score indicator
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    Rectangle {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                        Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                        radius: width / 2
                        color: {
                            const score = entryTestDialog.testResult.score || 0
                            if (score >= 80) return Kirigami.Theme.positiveTextColor
                            if (score >= 60) return "#FFC107"
                            if (score >= 40) return "#FF9800"
                            return Kirigami.Theme.negativeTextColor
                        }

                        QQC.Label {
                            anchors.centerIn: parent
                            text: entryTestDialog.testResult.score || 0
                            font.weight: Font.Bold
                            font.pointSize: -1
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.5
                            color: "white"
                        }
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: entryTestDialog.testResult.entryName || ""
                            font.weight: Font.Bold
                            font.pointSize: -1
                            font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                        }

                        QQC.Label {
                            text: entryTestDialog.testResult.message || ""
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        QQC.Label {
                            text: entryTestDialog.testResult.bootable ?
                                   i18nc("@info:status", "Status: Bootable") :
                                   i18nc("@info:status", "Status: May have issues")
                            font: Kirigami.Theme.smallFont
                            color: entryTestDialog.testResult.bootable ?
                                   Kirigami.Theme.positiveTextColor :
                                   Kirigami.Theme.negativeTextColor
                        }
                    }
                }

                Kirigami.Separator {}

                // Checks passed
                QQC.Label {
                    text: i18nc("@label", "Checks Passed:")
                    font.weight: Font.Bold
                    visible: (entryTestDialog.testResult.checks || []).length > 0
                }
                Repeater {
                    model: entryTestDialog.testResult.checks || []
                    QQC.Label {
                        text: "✓ " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: Kirigami.Theme.positiveTextColor
                    }
                }

                // Warnings
                QQC.Label {
                    text: i18nc("@label", "Warnings:")
                    font.weight: Font.Bold
                    visible: (entryTestDialog.testResult.warnings || []).length > 0
                }
                Repeater {
                    model: entryTestDialog.testResult.warnings || []
                    QQC.Label {
                        text: "⚠ " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: "#FFC107"
                    }
                }

                // Errors
                QQC.Label {
                    text: i18nc("@label", "Errors:")
                    font.weight: Font.Bold
                    visible: (entryTestDialog.testResult.errors || []).length > 0
                }
                Repeater {
                    model: entryTestDialog.testResult.errors || []
                    QQC.Label {
                        text: "✗ " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: Kirigami.Theme.negativeTextColor
                    }
                }

                // Recommendations
                QQC.Label {
                    text: i18nc("@info", "Note: This is a dry-run simulation. Actual boot behavior may vary.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }
        }
    }

    // Boot Order Optimization Dialog
    QQC.Dialog {
        id: bootOrderOptimizeDialog
        title: i18nc("@title", "Boot Order Optimization Analysis")
        modal: true
        property var result: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // Summary
            RowLayout {
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: bootOrderOptimizeDialog.result.optimizations > 0 ? "document-edit" : "dialog-ok"
                    color: bootOrderOptimizeDialog.result.optimizations > 0 ?
                           Kirigami.Theme.highlightColor :
                           Kirigami.Theme.positiveTextColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                }

                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC.Label {
                        text: bootOrderOptimizeDialog.result.summary || ""
                        font.weight: Font.Bold
                        font.pointSize: -1
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                    }

                    QQC.Label {
                        text: i18nc("@info:status", "Analysis Complete")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }

            Kirigami.Separator {}

            // Optimization suggestions
            QQC.Label {
                text: i18nc("@title", "Suggested Optimizations:")
                font.weight: Font.Bold
                visible: (bootOrderOptimizeDialog.result.changes || []).length > 0
            }
            Repeater {
                model: bootOrderOptimizeDialog.result.changes || []
                QQC.Label {
                    text: "• " + modelData
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            // No optimizations needed message
            QQC.Label {
                text: i18nc("@info", "✓ Your boot order is already well-optimized!")
                visible: (bootOrderOptimizeDialog.result.optimizations || 0) === 0
                font.pointSize: -1
                font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                color: Kirigami.Theme.positiveTextColor
                Layout.alignment: Qt.AlignHCenter
            }

            // Help text
            QQC.Label {
                text: i18nc("@info", "Boot order optimization helps improve boot performance by prioritizing frequently used entries and organizing the boot menu efficiently.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }
    }

    // Save Profile Dialog
    QQC.Dialog {
        id: saveProfileDialog
        title: i18nc("@title", "Save Boot Configuration Profile")
        modal: true

        standardButtons: QQC.Dialog.Save | QQC.Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Save the current boot configuration as a profile for quick restoration later.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC.TextField {
                id: profileNameField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Enter profile name...")
                selectByMouse: true
            }

            QQC.Label {
                text: i18nc("@info", "Profiles are saved to: %1",
                           QStandardPaths.writableLocation(QStandardPaths::AppDataLocation) + "/profiles")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        onAccepted: {
            if (profileNameField.text.length > 0) {
                kcm.manager.saveProfile(profileNameField.text)
                profileNameField.text = ""
            }
        }
    }

    // Load Profile Dialog
    QQC.Dialog {
        id: loadProfileDialog
        title: i18nc("@title", "Load Boot Configuration Profile")
        modal: true

        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                QQC.Label {
                    text: i18nc("@info", "Select a profile to load. This will restore the boot configuration to the saved state.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                ListView {
                    id: profileListView
                    model: kcm.manager.getProfiles()
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Kirigami.Units.gridUnit * 15,
                                                       profileListView.count * Kirigami.Units.gridUnit * 3)

                    delegate: QQC.ItemDelegate {
                        width: profileListView.width
                        highlighted: profileListView.currentIndex === index

                        onClicked: {
                            profileListView.currentIndex = index
                        }

                        onDoubleClicked: {
                            profileListView.currentIndex = index
                            loadProfileDialog.accept()
                        }

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                source: "document-save"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            }

                            ColumnLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Layout.fillWidth: true

                                QQC.Label {
                                    text: modelData.name || ""
                                    font.weight: Font.Bold
                                }

                                RowLayout {
                                    spacing: Kirigami.Units.smallSpacing

                                    QQC.Label {
                                        text: i18nc("@info", "%1 entries", modelData.entriesCount || 0)
                                        font: Kirigami.Theme.smallFont
                                        opacity: 0.7
                                    }

                                    QQC.Label {
                                        text: "|"
                                        font: Kirigami.Theme.smallFont
                                        opacity: 0.5
                                    }

                                    QQC.Label {
                                        text: modelData.timestamp || ""
                                        font: Kirigami.Theme.smallFont
                                        opacity: 0.7
                                    }
                                }
                            }

                            QQC.ToolButton {
                                icon.name: "edit-delete"
                                onClicked: {
                                    confirmDeleteProfileDialog.profileName = modelData.name
                                    confirmDeleteProfileDialog.open()
                                }
                                tooltip: i18nc("@info:tooltip", "Delete profile")
                            }
                        }
                    }

                    QQC.Label {
                        visible: profileListView.count === 0
                        text: i18nc("@info:placeholder", "No saved profiles")
                        anchors.centerIn: parent
                        opacity: 0.7
                    }
                }
            }
        }

        onAccepted: {
            if (profileListView.currentIndex >= 0) {
                const profile = profileListView.model.get(profileListView.currentIndex)
                kcm.manager.loadProfile(profile.name)
            }
        }
    }

    // Confirm Delete Profile Dialog
    QQC.Dialog {
        id: confirmDeleteProfileDialog
        property string profileName: ""
        title: i18nc("@title", "Delete Profile")
        modal: true

        standardButtons: QQC.Dialog.Delete | QQC.Dialog.Cancel

        contentItem: QQC.Label {
            text: i18nc("@info", "Are you sure you want to delete the profile '%1'?", confirmDeleteProfileDialog.profileName)
            wrapMode: Text.WordWrap
        }

        onAccepted: {
            kcm.manager.deleteProfile(profileName)
        }
    }

    // Export Report Dialog
    QQC.Dialog {
        id: exportReportDialog
        title: i18nc("@title", "Export Configuration Report")
        modal: true

        standardButtons: QQC.Dialog.Save | QQC.Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Generate a comprehensive report of your boot configuration including entries, profiles, and favorites.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC.TextField {
                id: reportPathField
                Layout.fillWidth: true
                text: QStandardPaths.writableLocation(QStandardPaths::DocumentsLocation) + "/efiboot-report.txt"
                selectByMouse: true
            }

            QQC.Label {
                text: i18nc("@info", "The report will be saved as a text file with complete configuration details.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        onAccepted: {
            if (reportPathField.text.length > 0) {
                kcm.manager.exportConfigReport(reportPathField.text)
            }
        }
    }

    // Batch Operation Dialog
    QQC.Dialog {
        id: batchOperationDialog
        title: i18nc("@title", "Batch Operation Results")
        modal: true
        property var result: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            // Summary
            RowLayout {
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: batchOperationDialog.result.failureCount > 0 ? "dialog-warning" : "dialog-ok"
                    color: batchOperationDialog.result.failureCount > 0 ?
                           Kirigami.Theme.negativeTextColor :
                           Kirigami.Theme.positiveTextColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                }

                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC.Label {
                        text: batchOperationDialog.result.summary || ""
                        font.weight: Font.Bold
                        font.pointSize: -1
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                    }

                    QQC.Label {
                        text: i18nc("@info:status", "Operation: %1", batchOperationDialog.result.operation || "")
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                    }
                }
            }

            Kirigami.Separator {}

            // Statistics
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC.Label {
                    text: i18nc("@title", "Statistics")
                    font.weight: Font.Bold
                }

                QQC.Label {
                    text: i18nc("@info:label", "Total entries: %1", batchOperationDialog.result.totalEntries || 0)
                }

                QQC.Label {
                    text: i18nc("@info:label", "Successful: %1", batchOperationDialog.result.successCount || 0)
                    color: Kirigami.Theme.positiveTextColor
                }

                QQC.Label {
                    text: i18nc("@info:label", "Failed: %1", batchOperationDialog.result.failureCount || 0)
                    color: (batchOperationDialog.result.failureCount || 0) > 0 ?
                           Kirigami.Theme.negativeTextColor :
                           Kirigami.Theme.positiveTextColor
                }
            }

            // Errors
            QQC.Label {
                text: i18nc("@title", "Errors:")
                font.weight: Font.Bold
                visible: (batchOperationDialog.result.errors || []).length > 0
            }
            Repeater {
                model: batchOperationDialog.result.errors || []
                QQC.Label {
                    text: "• " + modelData
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    color: Kirigami.Theme.negativeTextColor
                    font: Kirigami.Theme.smallFont
                }
            }
        }
    }

    // EFI Variables Dialog
    QQC.Dialog {
        id: efiVariablesDialog
        title: i18nc("@title", "EFI Variables Viewer")
        modal: true
        property var variables: []

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                QQC.Label {
                    text: i18nc("@info", "View and analyze EFI NVRAM variables. Advanced users only.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.italic: true
                    opacity: 0.7
                }

                Kirigami.Separator {}

                Repeater {
                    model: efiVariablesDialog.variables

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Layout.fillWidth: true

                        QQC.Label {
                            text: modelData.name || ""
                            font.weight: Font.Bold
                        }

                        RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            QQC.Label {
                                text: i18nc("@label", "Exists:")
                                font: Kirigami.Theme.smallFont
                            }

                            Kirigami.Icon {
                                source: modelData.exists ? "dialog-ok" : "dialog-cancel"
                                color: modelData.exists ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            }

                            QQC.Label {
                                text: modelData.exists ? i18nc("@info:status", "Yes") : i18nc("@info:status", "No")
                            }
                        }

                        QQC.Label {
                            text: i18nc("@label", "Size: %1 bytes", modelData.size || 0)
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            visible: modelData.exists
                        }

                        QQC.Label {
                            text: i18nc("@label", "Type: %1", modelData.type || "")
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                            visible: modelData.exists
                        }

                        QQC.Label {
                            text: i18nc("@label", "Value: %1", modelData.value || "")
                            font: Kirigami.Theme.smallFont
                            Layout.fillWidth: true
                            visible: modelData.exists
                        }

                        Kirigami.Separator {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    // Dependencies Analysis Dialog
    QQC.Dialog {
        id: dependenciesDialog
        title: i18nc("@title", "Boot Entry Dependencies")
        modal: true
        property var dependencies: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // Entry info
                QQC.Label {
                    text: dependenciesDialog.dependencies.entryName || ""
                    font.weight: Font.Bold
                    font.pointSize: -1
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.2
                }

                Kirigami.Separator {}

                // Dependencies
                QQC.Label {
                    text: i18nc("@title", "Dependencies:")
                    font.weight: Font.Bold
                    visible: (dependenciesDialog.dependencies.dependsOn || []).length > 0
                }
                Repeater {
                    model: dependenciesDialog.dependencies.dependsOn || []
                    QQC.Label {
                        text: "• " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Related entries
                QQC.Label {
                    text: i18nc("@title", "Related Entries:")
                    font.weight: Font.Bold
                    visible: (dependenciesDialog.dependencies.relatedEntries || []).length > 0
                }
                Repeater {
                    model: dependenciesDialog.dependencies.relatedEntries || []
                    QQC.Label {
                        text: "• " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                // Help text
                QQC.Label {
                    text: i18nc("@info", "This analysis shows what the boot entry depends on and which other entries are related.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }
        }
    }

    // Audit Log Dialog
    QQC.Dialog {
        id: auditLogDialog
        title: i18nc("@title", "Configuration Audit Log")
        modal: true
        property var auditLog: []

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                QQC.Label {
                    text: i18nc("@info", "History of configuration changes and operations.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Kirigami.Separator {}

                ListView {
                    model: auditLogDialog.auditLog.length
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(Kirigami.Units.gridUnit * 20,
                                                       auditLogDialog.auditLog.length * Kirigami.Units.gridUnit * 2)

                    delegate: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: auditLogDialog.auditLog[index].timestamp || ""
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }

                        QQC.Label {
                            text: auditLogDialog.auditLog[index].operation || ""
                            font.weight: Font.Bold
                        }

                        QQC.Label {
                            text: auditLogDialog.auditLog[index].user || ""
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }

                        QQC.Label {
                            text: auditLogDialog.auditLog[index].details || ""
                            Layout.fillWidth: true
                        }
                    }

                    QQC.Label {
                        visible: auditLogDialog.auditLog.length === 0
                        text: i18nc("@info:placeholder", "No audit log entries yet")
                        anchors.centerIn: parent
                        opacity: 0.7
                    }
                }
            }
        }
    }

    // Create Snapshot Dialog
    QQC.Dialog {
        id: createSnapshotDialog
        title: i18nc("@title", "Create Configuration Snapshot")
        modal: true

        standardButtons: QQC.Dialog.Save | QQC.Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@info", "Save a snapshot of your current boot configuration. Snapshots can be compared to track changes over time.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            QQC.TextField {
                id: snapshotNameField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Enter snapshot name...")
                selectByMouse: true
            }
        }

        onAccepted: {
            if (snapshotNameField.text.length > 0) {
                kcm.manager.createSnapshot(snapshotNameField.text)
                snapshotNameField.text = ""
            }
        }
    }

    // Snapshot Comparison Dialog
    QQC.Dialog {
        id: snapshotComparisonDialog
        title: i18nc("@title", "Snapshot Comparison")
        modal: true
        property var comparison: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // Snapshots being compared
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@label", "Snapshot 1:")
                            font.weight: Font.Bold
                        }

                        QQC.Label {
                            text: snapshotComparisonDialog.comparison.snapshot1 || ""
                        }
                    }

                    Kirigami.Icon {
                        source: "go-next"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                    }

                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        QQC.Label {
                            text: i18nc("@label", "Snapshot 2:")
                            font.weight: Font.Bold
                        }

                        QQC.Label {
                            text: snapshotComparisonDialog.comparison.snapshot2 || ""
                        }
                    }
                }

                Kirigami.Separator {}

                // Differences
                QQC.Label {
                    text: i18nc("@title", "Differences:")
                    font.weight: Font.Bold
                    visible: (snapshotComparisonDialog.comparison.differences || []).length > 0
                }
                Repeater {
                    model: snapshotComparisonDialog.comparison.differences || []
                    QQC.Label {
                        text: "✗ " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: Kirigami.Theme.negativeTextColor
                    }
                }

                // Similarities
                QQC.Label {
                    text: i18nc("@title", "Similarities:")
                    font.weight: Font.Bold
                    visible: (snapshotComparisonDialog.comparison.similarities || []).length > 0
                }
                Repeater {
                    model: snapshotComparisonDialog.comparison.similarities || []
                    QQC.Label {
                        text: "✓ " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        color: Kirigami.Theme.positiveTextColor
                    }
                }

                // Identical indicator
                QQC.Label {
                    text: snapshotComparisonDialog.comparison.identical ?
                           i18nc("@info", "Snapshots are identical") :
                           i18nc("@info", "Snapshots differ")
                    font.weight: Font.Bold
                    font.pointSize: -1
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.1
                    color: snapshotComparisonDialog.comparison.identical ?
                           Kirigami.Theme.positiveTextColor :
                           Kirigami.Theme.highlightColor
                    visible: snapshotComparisonDialog.comparison.identical !== undefined
                }
            }
        }
    }

    // Advanced Search Dialog
    QQC.Dialog {
        id: advancedSearchDialog
        title: i18nc("@title", "Advanced Search")
        modal: true

        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@label", "Search entries by multiple criteria")
                font.weight: Font.Bold
            }

            // Name query
            QQC.TextField {
                id: searchNameField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Name pattern (supports wildcards)")
            }

            // Path query
            QQC.TextField {
                id: searchPathField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Path pattern (supports wildcards)")
            }

            // OS Type filter
            QQC.ComboBox {
                id: searchOsTypeCombo
                Layout.fillWidth: true
                model: [i18nc("@item:inlistbox", "All Types"),
                        i18nc("@item:inlistbox", "Linux"),
                        i18nc("@item:inlistbox", "Windows"),
                        i18nc("@item:inlistbox", "macOS"),
                        i18nc("@item:inlistbox", "Other")]
            }

            // Visible only checkbox
            QQC.CheckBox {
                id: searchVisibleOnlyCheck
                text: i18nc("@option:check", "Visible entries only")
                checked: true
            }
        }

        onAccepted: {
            kcm.manager.advancedSearch(searchNameField.text,
                                      searchPathField.text,
                                      searchOsTypeCombo.currentIndex - 1,
                                      searchVisibleOnlyCheck.checked)
            searchNameField.text = ""
            searchPathField.text = ""
            searchOsTypeCombo.currentIndex = 0
            searchVisibleOnlyCheck.checked = true
        }
    }

    // Create Group Dialog
    QQC.Dialog {
        id: createGroupDialog
        title: i18nc("@title", "Create Entry Group")
        modal: true

        standardButtons: QQC.Dialog.Ok | QQC.Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            QQC.Label {
                text: i18nc("@label", "Group name:")
            }

            QQC.TextField {
                id: groupNameField
                Layout.fillWidth: true
                placeholderText: i18nc("@info:placeholder", "Enter group name")
            }

            QQC.Label {
                text: i18nc("@label", "Select entries to include:")
            }

            // Entry selection list
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 200

                ListView {
                    id: groupEntryList
                    model: kcm.manager.entries

                    delegate: QQC.CheckDelegate {
                        width: ListView.view.width
                        text: model.name + " (" + model.entryIdHex + ")"
                        checked: false

                        onCheckedChanged: {
                            if (checked) {
                                groupSelectedEntries.push(model.entryId)
                            } else {
                                const index = groupSelectedEntries.indexOf(model.entryId)
                                if (index > -1) {
                                    groupSelectedEntries.splice(index, 1)
                                }
                            }
                        }
                    }
                }
            }

            property var groupSelectedEntries: []
        }

        onAccepted: {
            if (groupNameField.text.length > 0 && createGroupDialog.contentItem.groupSelectedEntries.length > 0) {
                kcm.manager.createEntryGroup(groupNameField.text, createGroupDialog.contentItem.groupSelectedEntries)
                groupNameField.text = ""
                createGroupDialog.contentItem.groupSelectedEntries = []
            }
        }
    }

    // Reset Defaults Dialog
    QQC.Dialog {
        id: resetDefaultsDialog
        title: i18nc("@title", "Reset to Defaults")
        modal: true

        standardButtons: QQC.Dialog.Yes | QQC.Dialog.No

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: "warning"
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            }

            QQC.Label {
                text: i18nc("@info", "Are you sure you want to reset all settings to defaults?")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.weight: Font.Bold
            }

            QQC.Label {
                text: i18nc("@info", "This action cannot be undone.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        onAccepted: {
            kcm.manager.resetToDefaults()
        }
    }

    // Boot Performance Benchmark Dialog
    QQC.Dialog {
        id: bootPerformanceDialog
        title: i18nc("@title", "Boot Performance Benchmark")
        modal: true
        property var benchmark: ({})

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                // Entry Retrieval Performance
                QQC.Label {
                    text: i18nc("@title", "Entry Retrieval Performance")
                    font.weight: Font.Bold
                }
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    QQC.Label {
                        text: i18nc("@label", "Retrieval Time:")
                    }
                    QQC.Label {
                        text: bootPerformanceDialog.benchmark.entryRetrievalTime ? bootPerformanceDialog.benchmark.entryRetrievalTime + " ms" : "-"
                    }
                }
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    QQC.Label {
                        text: i18nc("@label", "Entry Count:")
                    }
                    QQC.Label {
                        text: bootPerformanceDialog.benchmark.entryCount || "-"
                    }
                }
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    QQC.Label {
                        text: i18nc("@label", "Entries Per Second:")
                    }
                    QQC.Label {
                        text: bootPerformanceDialog.benchmark.entriesPerSecond ? bootPerformanceDialog.benchmark.entriesPerSecond.toFixed(2) : "-"
                    }
                }

                Kirigami.Separator {}

                // Memory Usage
                QQC.Label {
                    text: i18nc("@title", "Memory Usage")
                    font.weight: Font.Bold
                }
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    QQC.Label {
                        text: i18nc("@label", "Estimated Memory:")
                    }
                    QQC.Label {
                        text: bootPerformanceDialog.benchmark.estimatedMemoryUsage ?
                              (bootPerformanceDialog.benchmark.estimatedMemoryUsage / 1024).toFixed(2) + " KB" : "-"
                    }
                }

                Kirigami.Separator {}

                // Boot Timeout Analysis
                QQC.Label {
                    text: i18nc("@title", "Boot Timeout Analysis")
                    font.weight: Font.Bold
                }
                QQC.Label {
                    text: bootPerformanceDialog.benchmark.timeoutAnalysis || "-"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Kirigami.Separator {}

                // Efficiency Score
                QQC.Label {
                    text: i18nc("@title", "Efficiency Score")
                    font.weight: Font.Bold
                }
                QQC.Label {
                    text: bootPerformanceDialog.benchmark.efficiencyScore !== undefined ?
                          i18nc("@info", "%1/100", bootPerformanceDialog.benchmark.efficiencyScore) : "-"
                    font.pointSize: -1
                    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize * 1.5
                    font.weight: Font.Bold
                    color: bootPerformanceDialog.benchmark.efficiencyScore >= 80 ?
                           Kirigami.Theme.positiveTextColor :
                           (bootPerformanceDialog.benchmark.efficiencyScore >= 50 ?
                            Kirigami.Theme.neutralTextColor :
                            Kirigami.Theme.negativeTextColor)
                }

                // Recommendations
                QQC.Label {
                    text: i18nc("@title", "Recommendations")
                    font.weight: Font.Bold
                    visible: (bootPerformanceDialog.benchmark.recommendations || []).length > 0
                }
                Repeater {
                    model: bootPerformanceDialog.benchmark.recommendations || []
                    QQC.Label {
                        text: "• " + modelData
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    // Advanced Search Results Dialog
    QQC.Dialog {
        id: advancedSearchResultsDialog
        title: i18nc("@title", "Advanced Search Results")
        modal: true
        property var results: []

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                QQC.Label {
                    text: i18nc("@info", "Found %1 matching entries", advancedSearchResultsDialog.results.length)
                    font.weight: Font.Bold
                    visible: advancedSearchResultsDialog.results.length > 0
                }

                QQC.Label {
                    text: i18nc("@info:placeholder", "No matching entries found")
                    visible: advancedSearchResultsDialog.results.length === 0
                }

                Repeater {
                    model: advancedSearchResultsDialog.results
                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Separator {}

                        RowLayout {
                            spacing: Kirigami.Units.largeSpacing
                            QQC.Label {
                                text: modelData.name || ""
                                font.weight: Font.Bold
                            }
                            QQC.Label {
                                text: modelData.entryIdHex || ""
                                font: Kirigami.Theme.smallFont
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.largeSpacing
                            QQC.Label {
                                text: i18nc("@label", "Path:")
                                font: Kirigami.Theme.smallFont
                            }
                            QQC.Label {
                                text: modelData.path || ""
                                font: Kirigami.Theme.smallFont
                                Layout.fillWidth: true
                            }
                        }

                        RowLayout {
                            spacing: Kirigami.Units.largeSpacing
                            QQC.Label {
                                text: i18nc("@label", "OS Type:")
                                font: Kirigami.Theme.smallFont
                            }
                            QQC.Label {
                                text: modelData.osType || ""
                                font: Kirigami.Theme.smallFont
                            }
                        }
                    }
                }
            }
        }
    }

    // System Boot Log Dialog
    QQC.Dialog {
        id: systemBootLogDialog
        title: i18nc("@title", "System Boot Log")
        modal: true
        property var bootLog: []

        standardButtons: QQC.Dialog.Close

        contentItem: ScrollView {
            ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                QQC.Label {
                    text: i18nc("@info", "Recent boot log entries:")
                    font.weight: Font.Bold
                }

                QQC.Label {
                    text: i18nc("@info:placeholder", "No boot log entries found")
                    visible: systemBootLogDialog.bootLog.length === 0
                }

                Repeater {
                    model: systemBootLogDialog.bootLog
                    ColumnLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Separator {}

                        QQC.Label {
                            text: modelData.timestamp || ""
                            font.weight: Font.Bold
                            font: Kirigami.Theme.smallFont
                        }

                        QQC.Label {
                            text: modelData.message || ""
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            font: Kirigami.Theme.smallFont
                        }

                        QQC.Label {
                            text: modelData.source ? i18nc("@label", "Source: %1", modelData.source) : ""
                            font: Kirigami.Theme.smallFont
                            visible: modelData.source !== undefined
                        }
                    }
                }
            }
        }
    }
}

