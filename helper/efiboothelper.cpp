/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include <KAuth/ActionReply>
#include <KAuth/HelperSupport>

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

#include <QtEndian>

#include <algorithm>

#include <qefi.h>

#include "../efivarcommon.h"

using namespace Qt::StringLiterals;

static std::vector<quint16> parseUint16Array(const QByteArray &data)
{
    std::vector<quint16> values;
    if (data.isEmpty() || (data.size() % 2) != 0) {
        return values;
    }

    values.reserve(static_cast<size_t>(data.size() / 2));
    for (qsizetype i = 0; i + 1 < data.size(); i += 2) {
        const quint16 raw = *reinterpret_cast<const quint16 *>(data.constData() + i);
        values.push_back(qFromLittleEndian<quint16>(raw));
    }
    return values;
}

static QByteArray encodeUint16Array(const std::vector<quint16> &values)
{
    QByteArray data;
    data.resize(static_cast<qsizetype>(values.size() * 2));
    for (size_t i = 0; i < values.size(); ++i) {
        const quint16 le = qToLittleEndian<quint16>(values[i]);
        memcpy(data.data() + static_cast<qsizetype>(i * 2), &le, sizeof(le));
    }
    return data;
}

class EfiBootHelper : public QObject
{
    Q_OBJECT

public Q_SLOTS:
    KAuth::ActionReply cc_inoki_efibootkcm_setdefault(const QVariantMap &args)
    {
        return setDefault(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_rebootto(const QVariantMap &args)
    {
        return rebootTo(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_settimeout(const QVariantMap &args)
    {
        return setTimeout(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_resetbootnext(const QVariantMap &args)
    {
        Q_UNUSED(args)
        return resetBootNext();
    }

    KAuth::ActionReply cc_inoki_efibootkcm_reboottobios(const QVariantMap &args)
    {
        Q_UNUSED(args)
        return rebootToBios();
    }

    KAuth::ActionReply cc_inoki_efibootkcm_diagnostics(const QVariantMap &args)
    {
        Q_UNUSED(args)
        return getDiagnostics();
    }

    KAuth::ActionReply cc_inoki_efibootkcm_moveentryup(const QVariantMap &args)
    {
        return moveEntryUp(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_moveentrydown(const QVariantMap &args)
    {
        return moveEntryDown(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_deleteentry(const QVariantMap &args)
    {
        return deleteEntry(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_backupentries(const QVariantMap &args)
    {
        return backupEntries(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_restoreentries(const QVariantMap &args)
    {
        return restoreEntries(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_renameentry(const QVariantMap &args)
    {
        return renameEntry(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_togglevisibility(const QVariantMap &args)
    {
        return toggleVisibility(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_cloneentry(const QVariantMap &args)
    {
        return cloneEntry(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_editentry(const QVariantMap &args)
    {
        return editEntry(args);
    }

    KAuth::ActionReply cc_inoki_efibootkcm_getbootstats(const QVariantMap &args)
    {
        Q_UNUSED(args)
        return getBootStats();
    }

    KAuth::ActionReply cc_inoki_efibootkcm_getboothistory(const QVariantMap &args)
    {
        Q_UNUSED(args)
        return getBootHistory();
    }

    KAuth::ActionReply setDefault(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        bool ok = false;
        const quint16 entryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing or invalid entryId."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();
        auto order = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));

        if (order.empty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"BootOrder is empty. No boot entries found."_s);
            return reply;
        }

        // Check if entry exists in current order
        bool found = false;
        for (const auto id : order) {
            if (id == entryId) {
                found = true;
                break;
            }
        }
        if (!found) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Entry %1 not found in BootOrder."_s.arg(QString::number(entryId, 16).toUpper().rightJustified(4, u'0')));
            return reply;
        }

        // New order: selected entry first, then the existing order without duplicates.
        std::vector<quint16> newOrder;
        newOrder.reserve(order.size() + 1);
        newOrder.push_back(entryId);
        for (const auto id : order) {
            if (id != entryId) {
                newOrder.push_back(id);
            }
        }

        const QByteArray encoded = encodeUint16Array(newOrder);
        // TODO: When qefi_set_variable returns int error code:
        qefi_set_variable(global, u"BootOrder"_s, encoded);
        // if (ret != 0) {
        //     reply = KAuth::ActionReply::HelperErrorReply();
        //     reply.setErrorDescription(u"Failed to write BootOrder. Error code: %1. Ensure efivarfs is mounted read-write and not locked down."_s.arg(ret));
        //     return reply;
        // }

        // Verify the write succeeded by reading back
        const auto verifyOrder = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));
        if (verifyOrder.empty() || verifyOrder.front() != entryId) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to update BootOrder. The value may not have been written correctly."_s);
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Default boot entry updated to %1."_s.arg(QString::number(entryId, 16).toUpper().rightJustified(4, u'0')));
        return reply;
    }

    KAuth::ActionReply rebootTo(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        bool ok = false;
        const quint16 entryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing or invalid entryId."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();
        // TODO: When qefi_set_variable_uint16 returns int error code:
        qefi_set_variable_uint16(global, u"BootNext"_s, entryId);        // if (ret != 0) {
        //     reply = KAuth::ActionReply::HelperErrorReply();
        //     reply.setErrorDescription(u"Failed to write BootNext. Error code: %1. Ensure efivarfs is mounted read-write and not locked down."_s.arg(ret));
        //     return reply;
        // }
        

        // Verify the write succeeded by reading back
        const quint16 verifyBootNext = qefi_get_variable_uint16(global, u"BootNext"_s);
        if (verifyBootNext != entryId) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to set BootNext. The value may not have been written correctly."_s);
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"BootNext set to %1. Reboot your system to boot into the selected entry."_s.arg(QString::number(entryId, 16).toUpper().rightJustified(4, u'0')));
        return reply;
    }

    KAuth::ActionReply setTimeout(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        bool ok = false;
        const int seconds = args.value(u"seconds"_s).toInt(&ok);
        if (!ok || seconds < 0 || seconds > 65535) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing or invalid timeout value. Must be between 0 and 65535 seconds."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();

        // Encode timeout as little-endian 16-bit value
        QByteArray timeoutData;
        timeoutData.resize(2);
        const quint16 timeoutLe = qToLittleEndian<quint16>(static_cast<quint16>(seconds));
        memcpy(timeoutData.data(), &timeoutLe, sizeof(timeoutLe));

        qefi_set_variable(global, u"Timeout"_s, timeoutData);

        // Verify the write succeeded by reading back
        const auto verifyTimeout = qefi_get_variable(global, u"Timeout"_s);
        if (verifyTimeout.isEmpty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to set Timeout. The value may not have been written correctly."_s);
            return reply;
        }

        const quint16 verifyValue = qFromLittleEndian<quint16>(*reinterpret_cast<const quint16 *>(verifyTimeout.constData()));
        if (verifyValue != static_cast<quint16>(seconds)) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to set Timeout. The value may not have been written correctly."_s);
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Boot timeout set to %1 seconds."_s.arg(seconds));
        return reply;
    }

    KAuth::ActionReply resetBootNext()
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();

        // Delete BootNext variable by writing empty data
        qefi_set_variable(global, u"BootNext"_s, QByteArray());

        // Verify BootNext was cleared
        const auto bootNext = qefi_get_variable_uint16(global, u"BootNext"_s);
        if (bootNext != 0) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to clear BootNext. The variable may not have been deleted correctly."_s);
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"BootNext cleared successfully. The system will boot normally on next reboot."_s);
        return reply;
    }

    KAuth::ActionReply rebootToBios()
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();

        // OsIndications is a 64-bit value. Bit 0 (value 1) requests firmware setup.
        // GUID: 8be4df61-93ca-11d2-aa0d-00e098032b8c (same as global)
        const auto osIndicationsData = qefi_get_variable(global, u"OsIndications"_s);

        quint64 osIndications = 0;
        if (!osIndicationsData.isEmpty() && osIndicationsData.size() >= 8) {
            osIndications = qFromLittleEndian<quint64>(*reinterpret_cast<const quint64 *>(osIndicationsData.constData()));
        }

        // Set bit 0 to request firmware setup
        osIndications |= 1ULL;

        // Encode as little-endian 64-bit value
        QByteArray indicationsData;
        indicationsData.resize(8);
        const quint64 indicationsLe = qToLittleEndian<quint64>(osIndications);
        memcpy(indicationsData.data(), &indicationsLe, sizeof(indicationsLe));

        qefi_set_variable(global, u"OsIndications"_s, indicationsData);

        // Verify the write succeeded
        const auto verifyData = qefi_get_variable(global, u"OsIndications"_s);
        if (verifyData.isEmpty() || verifyData.size() < 8) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to set OsIndications. The value may not have been written correctly."_s);
            return reply;
        }

        const quint64 verifyValue = qFromLittleEndian<quint64>(*reinterpret_cast<const quint64 *>(verifyData.constData()));
        if ((verifyValue & 1ULL) == 0) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to set OsIndications. The firmware setup bit was not set."_s);
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Firmware setup requested. Reboot your system to enter BIOS/firmware setup."_s);
        return reply;
    }

    KAuth::ActionReply getDiagnostics()
    {
        KAuth::ActionReply reply;

        QVariantMap diagnosticInfo;

        // Check EFI availability
        const bool efiAvailable = qefi_is_available();
        diagnosticInfo.insert(u"efiAvailable"_s, efiAvailable);

        if (!efiAvailable) {
            diagnosticInfo.insert(u"efiError"_s, u"EFI variables are not accessible. Check if efivarfs is mounted."_s);
            diagnosticInfo.insert(u"suggestions"_s,
                                  QStringList({u"Check if /sys/firmware/efi/efivars exists"_s,
                                               u"Try: sudo mount -t efivarfs efivarfs /sys/firmware/efi/efivars"_s,
                                               u"Check if booted in EFI mode (check /sys/firmware/efi)"_s,
                                               u"Verify system has EFI support"_s}));
        } else {
            // Get BootOrder
            const QUuid global = efiGlobalGuid();
            const auto bootOrderData = qefi_get_variable(global, u"BootOrder"_s);
            const auto bootOrder = parseUint16Array(bootOrderData);

            QStringList bootOrderList;
            bootOrderList.reserve(static_cast<int>(bootOrder.size()));
            for (const auto id : bootOrder) {
                bootOrderList.append(QStringLiteral("Boot%1").arg(id, 4, 16, QLatin1Char('0')).toUpper());
            }
            diagnosticInfo.insert(u"bootOrder"_s, bootOrderList);
            diagnosticInfo.insert(u"bootOrderCount"_s, static_cast<int>(bootOrder.size()));

            // Get BootCurrent
            const auto bootCurrent = qefi_get_variable_uint16(global, u"BootCurrent"_s);
            if (bootCurrent != 0) {
                diagnosticInfo.insert(u"bootCurrent"_s, QStringLiteral("Boot%1").arg(bootCurrent, 4, 16, QLatin1Char('0')).toUpper());
            } else {
                diagnosticInfo.insert(u"bootCurrent"_s, u"Unknown"_s);
            }

            // Get BootNext
            const auto bootNext = qefi_get_variable_uint16(global, u"BootNext"_s);
            if (bootNext != 0) {
                diagnosticInfo.insert(u"bootNext"_s, QStringLiteral("Boot%1").arg(bootNext, 4, 16, QLatin1Char('0')).toUpper());
            } else {
                diagnosticInfo.insert(u"bootNext"_s, u"Not set"_s);
            }

            // Get Timeout
            const auto timeoutData = qefi_get_variable(global, u"Timeout"_s);
            if (!timeoutData.isEmpty() && timeoutData.size() >= 2) {
                const quint16 timeout = qFromLittleEndian<quint16>(*reinterpret_cast<const quint16 *>(timeoutData.constData()));
                diagnosticInfo.insert(u"timeout"_s, static_cast<int>(timeout));
            } else {
                diagnosticInfo.insert(u"timeout"_s, -1); // -1 means not set
            }

            // Check OsIndications support
            const auto osIndications = qefi_get_variable(global, u"OsIndicationsSupported"_s);
            const bool osIndicationsSupported = !osIndications.isEmpty();
            diagnosticInfo.insert(u"osIndicationsSupported"_s, osIndicationsSupported);

            // Get current OsIndications
            const auto osIndicationsData = qefi_get_variable(global, u"OsIndications"_s);
            if (!osIndicationsData.isEmpty() && osIndicationsData.size() >= 8) {
                const quint64 osIndications = qFromLittleEndian<quint64>(*reinterpret_cast<const quint64 *>(osIndicationsData.constData()));
                diagnosticInfo.insert(u"osIndications"_s, static_cast<qint64>(osIndications));
                diagnosticInfo.insert(u"osIndicationsBootToFirmware"_s, static_cast<bool>(osIndications & 1ULL));
            } else {
                diagnosticInfo.insert(u"osIndications"_s, static_cast<qint64>(0));
                diagnosticInfo.insert(u"osIndicationsBootToFirmware"_s, false);
            }

            // Count total boot entries (including those not in BootOrder)
            int totalEntries = 0;
            // Scan a reasonable range instead of all 65536 possible IDs
            for (quint16 id = 0; id < 4096; id++) {
                const QString bootVarName = QStringLiteral("Boot%1").arg(id, 4, 16, QLatin1Char('0'));
                const auto data = qefi_get_variable(global, bootVarName);
                if (!data.isEmpty()) {
                    totalEntries++;
                }
            }
            diagnosticInfo.insert(u"totalBootEntries"_s, totalEntries);

            // Platform and Firmware Information
            QByteArray platformData;
            QFile file(QStringLiteral("/sys/firmware/efi/platform"));
            if (file.open(QIODevice::ReadOnly)) {
                platformData = file.readAll();
                file.close();
            }
            if (!platformData.isEmpty()) {
                diagnosticInfo.insert(u"platformName"_s, QString::fromUtf8(platformData).trimmed());
            }

            // Get firmware version from DMI/SMBIOS
            QFile biosVendorFile(QStringLiteral("/sys/class/dmi/id/bios_vendor"));
            if (biosVendorFile.open(QIODevice::ReadOnly)) {
                diagnosticInfo.insert(u"biosVendor"_s, QString::fromUtf8(biosVendorFile.readAll().trimmed()).trimmed());
                biosVendorFile.close();
            }

            QFile biosVersionFile(QStringLiteral("/sys/class/dmi/id/bios_version"));
            if (biosVersionFile.open(QIODevice::ReadOnly)) {
                diagnosticInfo.insert(u"biosVersion"_s, QString::fromUtf8(biosVersionFile.readAll().trimmed()).trimmed());
                biosVersionFile.close();
            }

            QFile biosDateFile(QStringLiteral("/sys/class/dmi/id/bios_date"));
            if (biosDateFile.open(QIODevice::ReadOnly)) {
                diagnosticInfo.insert(u"biosDate"_s, QString::fromUtf8(biosDateFile.readAll().trimmed()).trimmed());
                biosDateFile.close();
            }

            // Board information
            QFile boardVendorFile(QStringLiteral("/sys/class/dmi/id/board_vendor"));
            if (boardVendorFile.open(QIODevice::ReadOnly)) {
                diagnosticInfo.insert(u"boardVendor"_s, QString::fromUtf8(boardVendorFile.readAll().trimmed()).trimmed());
                boardVendorFile.close();
            }

            QFile boardNameFile(QStringLiteral("/sys/class/dmi/id/board_name"));
            if (boardNameFile.open(QIODevice::ReadOnly)) {
                diagnosticInfo.insert(u"boardName"_s, QString::fromUtf8(boardNameFile.readAll().trimmed()).trimmed());
                boardNameFile.close();
            }

            // System information
            QFile machineIdFile(QStringLiteral("/etc/machine-id"));
            if (machineIdFile.open(QIODevice::ReadOnly)) {
                diagnosticInfo.insert(u"machineId"_s, QString::fromUtf8(machineIdFile.readAll().trimmed()).left(8));
                machineIdFile.close();
            }

            // Get EFI runtime services version
            const auto rtVerData = qefi_get_variable(global, u"RuntimeServicesVersion"_s);
            if (!rtVerData.isEmpty() && rtVerData.size() >= 2) {
                // EFI Runtime Services version is typically UTF-16 string
                QString rtVer;
                for (int i = 0; i < rtVerData.size() - 1; i += 2) {
                    const quint16 ch = qFromLittleEndian<quint16>(*reinterpret_cast<const quint16 *>(rtVerData.constData() + i));
                    if (ch == 0)
                        break;
                    rtVer += QChar(ch);
                }
                if (!rtVer.isEmpty()) {
                    diagnosticInfo.insert(u"efiRuntimeVersion"_s, rtVer);
                }
            }

            // Get firmware vendor (typically from BIOS vendor DMI or EFI variable)
            const auto firmwareVendorData = qefi_get_variable(global, u"FirmwareVendor"_s);
            if (!firmwareVendorData.isEmpty() && firmwareVendorData.size() >= 4) {
                // Firmware vendor is a UTF-16 string
                QString fwVendor;
                for (int i = 0; i < firmwareVendorData.size() - 1; i += 2) {
                    const quint16 ch = qFromLittleEndian<quint16>(*reinterpret_cast<const quint16 *>(firmwareVendorData.constData() + i));
                    if (ch == 0)
                        break;
                    fwVendor += QChar(ch);
                }
                if (!fwVendor.isEmpty()) {
                    diagnosticInfo.insert(u"firmwareVendor"_s, fwVendor);
                }
            }

            // Fallback to biosVendor if firmwareVendor not available
            if (!diagnosticInfo.contains(u"firmwareVendor"_s) && diagnosticInfo.contains(u"biosVendor"_s)) {
                diagnosticInfo.insert(u"firmwareVendor"_s, diagnosticInfo.value(u"biosVendor"_s));
            }

            // Get firmware version (combine BIOS version as fallback)
            const auto firmwareVersionData = qefi_get_variable(global, u"FirmwareVersion"_s);
            if (!firmwareVersionData.isEmpty() && firmwareVersionData.size() >= 2) {
                const quint16 fwVer = qFromLittleEndian<quint16>(*reinterpret_cast<const quint16 *>(firmwareVersionData.constData()));
                diagnosticInfo.insert(u"firmwareVersion"_s, QString::number(fwVer));
            }

            // Fallback to biosVersion if firmwareVersion not available
            if (!diagnosticInfo.contains(u"firmwareVersion"_s) && diagnosticInfo.contains(u"biosVersion"_s)) {
                diagnosticInfo.insert(u"firmwareVersion"_s, diagnosticInfo.value(u"biosVersion"_s));
            }

            // Use biosDate as firmwareDate
            if (diagnosticInfo.contains(u"biosDate"_s)) {
                diagnosticInfo.insert(u"firmwareDate"_s, diagnosticInfo.value(u"biosDate"_s));
            }

            // System health check
            QStringList healthStatus;
            QStringList healthWarnings;

            if (bootOrder.empty()) {
                healthWarnings.append(u"BootOrder is empty - system may not boot properly!"_s);
            } else {
                healthStatus.append(u"BootOrder is configured"_s);
            }

            if (bootCurrent == 0 && !bootOrder.empty()) {
                healthWarnings.append(u"BootCurrent not set - may indicate unexpected boot state"_s);
            } else {
                healthStatus.append(u"System booted from EFI"_s);
            }

            if (!osIndicationsSupported) {
                healthWarnings.append(u"OsIndications not supported - 'Reboot to BIOS' may not work"_s);
            } else {
                healthStatus.append(u"OsIndications supported - advanced features available"_s);
            }

            diagnosticInfo.insert(u"healthStatus"_s, healthStatus);
            diagnosticInfo.insert(u"healthWarnings"_s, healthWarnings);
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"diagnostics"_s, diagnosticInfo);
        return reply;
    }

    KAuth::ActionReply moveEntryUp(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        bool ok = false;
        const quint16 entryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing or invalid entryId."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();
        auto order = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));

        if (order.empty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"BootOrder is empty. Cannot move entries."_s);
            return reply;
        }

        // Find current position
        auto it = std::find(order.begin(), order.end(), entryId);
        if (it == order.end()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Entry %1 not found in BootOrder."_s.arg(QString::number(entryId, 16).toUpper().rightJustified(4, u'0')));
            return reply;
        }

        // Check if already at top
        if (it == order.begin()) {
            reply = KAuth::ActionReply::SuccessReply();
            reply.addData(u"info"_s, u"Entry is already at the top of BootOrder."_s);
            return reply;
        }

        // Move up by swapping with previous element
        std::iter_swap(it, it - 1);

        const QByteArray encoded = encodeUint16Array(order);
        qefi_set_variable(global, u"BootOrder"_s, encoded);

        // Verify
        const auto verifyOrder = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));
        if (verifyOrder.empty() || verifyOrder.size() != order.size()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to update BootOrder. The order may not have been written correctly."_s);
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Entry moved up in boot order."_s);
        return reply;
    }

    KAuth::ActionReply moveEntryDown(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        bool ok = false;
        const quint16 entryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing or invalid entryId."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();
        auto order = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));

        if (order.empty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"BootOrder is empty. Cannot move entries."_s);
            return reply;
        }

        // Find current position
        auto it = std::find(order.begin(), order.end(), entryId);
        if (it == order.end()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Entry %1 not found in BootOrder."_s.arg(QString::number(entryId, 16).toUpper().rightJustified(4, u'0')));
            return reply;
        }

        // Check if already at bottom
        if (it == order.end() - 1) {
            reply = KAuth::ActionReply::SuccessReply();
            reply.addData(u"info"_s, u"Entry is already at the bottom of BootOrder."_s);
            return reply;
        }

        // Move down by swapping with next element
        std::iter_swap(it, it + 1);

        const QByteArray encoded = encodeUint16Array(order);
        qefi_set_variable(global, u"BootOrder"_s, encoded);

        // Verify
        const auto verifyOrder = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));
        if (verifyOrder.empty() || verifyOrder.size() != order.size()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to update BootOrder. The order may not have been written correctly."_s);
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Entry moved down in boot order."_s);
        return reply;
    }

    KAuth::ActionReply deleteEntry(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        bool ok = false;
        const quint16 entryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing or invalid entryId."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();
        const QString bootVarName = QStringLiteral("Boot%1").arg(entryId, 4, 16, QLatin1Char('0'));

        // Check if entry exists
        const auto entryData = qefi_get_variable(global, bootVarName);
        if (entryData.isEmpty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Entry %1 does not exist."_s.arg(bootVarName));
            return reply;
        }

        // Remove from BootOrder if present
        auto order = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));
        auto it = std::find(order.begin(), order.end(), entryId);
        if (it != order.end()) {
            order.erase(it);
            const QByteArray encoded = encodeUint16Array(order);
            qefi_set_variable(global, u"BootOrder"_s, encoded);
        }

        // Delete the boot entry variable
        qefi_set_variable(global, bootVarName, QByteArray());

        // Verify deletion
        const auto verifyData = qefi_get_variable(global, bootVarName);
        if (!verifyData.isEmpty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to delete entry %1. The entry may still exist."_s.arg(bootVarName));
            return reply;
        }

        // Verify it was removed from BootOrder
        const auto verifyOrder = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));
        if (std::find(verifyOrder.begin(), verifyOrder.end(), entryId) != verifyOrder.end()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Entry was deleted but may still be in BootOrder."_s.arg(bootVarName));
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Entry %1 deleted successfully."_s.arg(bootVarName));
        return reply;
    }

    KAuth::ActionReply backupEntries(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        const QString filePath = args.value(u"filePath"_s).toString();
        if (filePath.isEmpty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing file path for backup."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();

        // Create backup data structure
        QVariantMap backupData;

        // Backup BootOrder
        const auto bootOrderData = qefi_get_variable(global, u"BootOrder"_s);
        if (!bootOrderData.isEmpty()) {
            backupData.insert(u"bootOrder"_s, QString::fromLatin1(bootOrderData.toHex()));
        }

        // Backup BootNext
        const auto bootNextData = qefi_get_variable(global, u"BootNext"_s);
        if (!bootNextData.isEmpty()) {
            backupData.insert(u"bootNext"_s, QString::fromLatin1(bootNextData.toHex()));
        }

        // Backup Timeout
        const auto timeoutData = qefi_get_variable(global, u"Timeout"_s);
        if (!timeoutData.isEmpty()) {
            backupData.insert(u"timeout"_s, QString::fromLatin1(timeoutData.toHex()));
        }

        // Backup all boot entries
        const auto bootOrder = parseUint16Array(bootOrderData);
        QVariantMap entries;

        for (const auto id : bootOrder) {
            const QString bootVarName = QStringLiteral("Boot%1").arg(id, 4, 16, QLatin1Char('0'));
            const auto entryData = qefi_get_variable(global, bootVarName);
            if (!entryData.isEmpty()) {
                entries.insert(bootVarName, QString::fromLatin1(entryData.toHex()));
            }
        }

        // Also scan for any entries not in BootOrder (limit to reasonable range)
        for (quint16 id = 0; id < 4096; id++) {
            const QString bootVarName = QStringLiteral("Boot%1").arg(id, 4, 16, QLatin1Char('0'));
            if (!entries.contains(bootVarName)) {
                const auto entryData = qefi_get_variable(global, bootVarName);
                if (!entryData.isEmpty()) {
                    entries.insert(bootVarName, QString::fromLatin1(entryData.toHex()));
                }
            }
        }

        backupData.insert(u"entries"_s, entries);
        backupData.insert(u"timestamp"_s, QDateTime::currentDateTime().toString(Qt::ISODate));
        backupData.insert(u"version"_s, u"1.0"_s);

        // Write to JSON file
        QJsonDocument jsonDoc(QJsonObject::fromVariantMap(backupData));
        QFile file(filePath);
        if (!file.open(QIODevice::WriteOnly)) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to open backup file for writing: %1"_s.arg(file.errorString()));
            return reply;
        }

        const QByteArray jsonData = jsonDoc.toJson(QJsonDocument::Indented);
        if (file.write(jsonData) != jsonData.size()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to write backup data."_s);
            file.close();
            return reply;
        }
        file.close();

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Successfully backed up %1 boot entries to %2"_s.arg(entries.size()).arg(filePath));
        return reply;
    }

    KAuth::ActionReply restoreEntries(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        const QString filePath = args.value(u"filePath"_s).toString();
        if (filePath.isEmpty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing file path for restore."_s);
            return reply;
        }

        // Read backup file
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly)) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to open backup file: %1"_s.arg(file.errorString()));
            return reply;
        }

        const QByteArray jsonData = file.readAll();
        file.close();

        QJsonParseError parseError;
        QJsonDocument jsonDoc = QJsonDocument::fromJson(jsonData, &parseError);
        if (parseError.error != QJsonParseError::NoError) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Invalid backup file format: %1"_s.arg(parseError.errorString()));
            return reply;
        }

        const QVariantMap backupData = jsonDoc.object().toVariantMap();
        const QString version = backupData.value(u"version"_s).toString();
        if (version != u"1.0"_s) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Unsupported backup version: %1"_s.arg(version));
            return reply;
        }

        const QUuid global = efiGlobalGuid();
        int restoredCount = 0;

        // Restore boot entries
        const QVariantMap entries = backupData.value(u"entries"_s).toMap();
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            const QString entryName = it.key();
            const QByteArray entryData = QByteArray::fromHex(it.value().toString().toLatin1());

            if (!entryData.isEmpty()) {
                qefi_set_variable(global, entryName, entryData);
                restoredCount++;
            }
        }

        // Restore BootOrder
        const QString bootOrderHex = backupData.value(u"bootOrder"_s).toString();
        if (!bootOrderHex.isEmpty()) {
            const QByteArray bootOrderData = QByteArray::fromHex(bootOrderHex.toLatin1());
            qefi_set_variable(global, u"BootOrder"_s, bootOrderData);
        }

        // Restore BootNext
        const QString bootNextHex = backupData.value(u"bootNext"_s).toString();
        if (!bootNextHex.isEmpty()) {
            const QByteArray bootNextData = QByteArray::fromHex(bootNextHex.toLatin1());
            qefi_set_variable(global, u"BootNext"_s, bootNextData);
        }

        // Restore Timeout
        const QString timeoutHex = backupData.value(u"timeout"_s).toString();
        if (!timeoutHex.isEmpty()) {
            const QByteArray timeoutData = QByteArray::fromHex(timeoutHex.toLatin1());
            qefi_set_variable(global, u"Timeout"_s, timeoutData);
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Successfully restored %1 boot entries from %2"_s.arg(restoredCount).arg(filePath));
        return reply;
    }

    KAuth::ActionReply renameEntry(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        bool ok = false;
        const quint16 entryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing or invalid entryId."_s);
            return reply;
        }

        const QString newName = args.value(u"newName"_s).toString();
        if (newName.isEmpty() || newName.length() > 255) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Invalid entry name. Must be 1-255 characters."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();
        const QString bootVarName = QStringLiteral("Boot%1").arg(entryId, 4, 16, QLatin1Char('0'));

        // Read existing entry data
        QByteArray entryData = qefi_get_variable(global, bootVarName);
        if (entryData.isEmpty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Entry %1 does not exist."_s.arg(bootVarName));
            return reply;
        }

        // Parse the load option (need non-const copy for modification)
        QEFILoadOption loadOption(entryData);
        if (!loadOption.isValidated()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to parse boot entry data."_s);
            return reply;
        }

        // Store the original name for confirmation message
        const QString originalName = loadOption.name();

        // Set the new name
        loadOption.setName(newName);

        // Get the formatted data with new name
        const QByteArray newData = loadOption.format();

        // Write the renamed entry
        qefi_set_variable(global, bootVarName, newData);

        // Verify the write
        const auto verifyData = qefi_get_variable(global, bootVarName);
        if (verifyData.isEmpty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to write renamed entry. The entry may have been corrupted."_s);
            return reply;
        }

        // Verify the name was changed
        QEFILoadOption verifyOption(verifyData);
        if (!verifyOption.isValidated() || verifyOption.name() != newName) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to rename entry. Verification failed."_s);
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Entry renamed from '%1' to '%2'."_s.arg(originalName).arg(newName));
        return reply;
    }

    KAuth::ActionReply toggleVisibility(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        bool ok = false;
        const quint16 entryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing or invalid entryId."_s);
            return reply;
        }

        const bool makeVisible = args.value(u"visible"_s).toBool();

        const QUuid global = efiGlobalGuid();
        const QString bootVarName = QStringLiteral("Boot%1").arg(entryId, 4, 16, QLatin1Char('0'));

        // Read existing entry data
        QByteArray entryData = qefi_get_variable(global, bootVarName);
        if (entryData.isEmpty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Entry %1 does not exist."_s.arg(bootVarName));
            return reply;
        }

        // Parse the load option
        QEFILoadOption loadOption(entryData);
        if (!loadOption.isValidated()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to parse boot entry data."_s);
            return reply;
        }

        // Set visibility
        loadOption.setIsVisible(makeVisible);

        // Get the formatted data
        const QByteArray newData = loadOption.format();

        // Write the modified entry
        qefi_set_variable(global, bootVarName, newData);

        // Update BootOrder
        auto order = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));
        bool inOrder = std::find(order.begin(), order.end(), entryId) != order.end();

        if (makeVisible && !inOrder) {
            // Add to BootOrder (append to end)
            order.push_back(entryId);
            const QByteArray encoded = encodeUint16Array(order);
            qefi_set_variable(global, u"BootOrder"_s, encoded);
        } else if (!makeVisible && inOrder) {
            // Remove from BootOrder
            order.erase(std::remove(order.begin(), order.end(), entryId), order.end());
            const QByteArray encoded = encodeUint16Array(order);
            qefi_set_variable(global, u"BootOrder"_s, encoded);
        }

        // Verify the visibility change
        const auto verifyData = qefi_get_variable(global, bootVarName);
        QEFILoadOption verifyOption(verifyData);
        if (!verifyOption.isValidated() || verifyOption.isVisible() != makeVisible) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to change entry visibility. Verification failed."_s);
            return reply;
        }

        const QString actionStr = makeVisible ? u"shown"_s : u"hidden"_s;
        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Entry %1 is now %2 from boot menu."_s.arg(bootVarName).arg(actionStr));
        return reply;
    }

    KAuth::ActionReply cloneEntry(const QVariantMap &args)
    {
        KAuth::ActionReply reply;
        if (!qefi_is_available()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"EFI variables are not available on this system."_s);
            return reply;
        }

        bool ok = false;
        const quint16 sourceEntryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Missing or invalid entryId."_s);
            return reply;
        }

        const QString cloneName = args.value(u"cloneName"_s).toString();
        if (cloneName.isEmpty() || cloneName.length() > 255) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Invalid clone name. Must be 1-255 characters."_s);
            return reply;
        }

        const QUuid global = efiGlobalGuid();
        const QString sourceBootVarName = QStringLiteral("Boot%1").arg(sourceEntryId, 4, 16, QLatin1Char('0'));

        // Read source entry data
        QByteArray sourceData = qefi_get_variable(global, sourceBootVarName);
        if (sourceData.isEmpty()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Entry %1 does not exist."_s.arg(sourceBootVarName));
            return reply;
        }

        // Parse the source entry
        QEFILoadOption sourceOption(sourceData);
        if (!sourceOption.isValidated()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to parse boot entry data."_s);
            return reply;
        }

        // Find a free BootXXXX slot
        quint16 newEntryId = 0;
        for (newEntryId = 0; newEntryId < 65535; newEntryId++) {
            const QString testVarName = QStringLiteral("Boot%1").arg(newEntryId, 4, 16, QLatin1Char('0'));
            const auto testData = qefi_get_variable(global, testVarName);
            if (testData.isEmpty()) {
                break;
            }
        }

        if (newEntryId >= 65535) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"No free boot entry slots available."_s);
            return reply;
        }

        const QString newBootVarName = QStringLiteral("Boot%1").arg(newEntryId, 4, 16, QLatin1Char('0'));

        // Create cloned entry with new name
        sourceOption.setName(cloneName);
        const QByteArray clonedData = sourceOption.format();

        // Write the cloned entry
        qefi_set_variable(global, newBootVarName, clonedData);

        // Add to BootOrder (append to end)
        auto order = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));
        order.push_back(newEntryId);
        const QByteArray encoded = encodeUint16Array(order);
        qefi_set_variable(global, u"BootOrder"_s, encoded);

        // Verify the clone
        const auto verifyData = qefi_get_variable(global, newBootVarName);
        QEFILoadOption verifyOption(verifyData);
        if (!verifyOption.isValidated() || verifyOption.name() != cloneName) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Failed to verify cloned entry."_s);
            return reply;
        }

        // Verify it's in BootOrder
        const auto verifyOrder = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));
        if (std::find(verifyOrder.begin(), verifyOrder.end(), newEntryId) == verifyOrder.end()) {
            reply = KAuth::ActionReply::HelperErrorReply();
            reply.setErrorDescription(u"Cloned entry was not added to BootOrder."_s);
            return reply;
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"info"_s, u"Entry cloned as %1 with name '%2'."_s.arg(newBootVarName).arg(cloneName));
        return reply;
    }

    KAuth::ActionReply editEntry(const QVariantMap &args)
    {
        Q_UNUSED(args)
        KAuth::ActionReply reply;
        // This is a placeholder for future implementation
        // Editing EFI load options is complex as it requires rebuilding the entire
        // EFI_LOAD_OPTION structure while preserving all attributes
        reply = KAuth::ActionReply::HelperErrorReply();
        reply.setErrorDescription(u"Direct entry editing is not yet implemented. Please delete and recreate the entry with desired parameters."_s);
        return reply;
    }

    KAuth::ActionReply getBootStats()
    {
        KAuth::ActionReply reply;
        QVariantMap bootStats;

        // Get current boot time from systemd (if available)
        QFile systemdTime(QStringLiteral("/proc/uptime"));
        if (systemdTime.open(QIODevice::ReadOnly)) {
            const QByteArray uptimeData = systemdTime.readAll();
            const double uptime = QString::fromUtf8(uptimeData).split(u' ').first().toDouble();
            bootStats.insert(u"currentUptime"_s, static_cast<qint64>(uptime));
            bootStats.insert(u"currentBootTime"_s, QDateTime::currentDateTime().addSecs(-static_cast<qint64>(uptime)).toString(Qt::ISODate));
            systemdTime.close();
        }

        // Get boot time from kernel
        QFile statFile(QStringLiteral("/proc/stat"));
        if (statFile.open(QIODevice::ReadOnly)) {
            const QByteArray statData = statFile.readAll();
            const QStringList lines = QString::fromUtf8(statData).split(u'\n');
            for (const QString &line : lines) {
                if (line.startsWith(QStringLiteral("btime"))) {
                    const QStringList parts = line.split(u' ');
                    if (parts.size() >= 2) {
                        bool ok = false;
                        const qint64 btime = parts[1].toLongLong(&ok);
                        if (ok) {
                            bootStats.insert(u"kernelBootTime"_s, btime);
                            bootStats.insert(u"kernelBootDateTime"_s, QDateTime::fromSecsSinceEpoch(btime).toString(Qt::ISODate));
                        }
                    }
                    break;
                }
            }
            statFile.close();
        }

        // Try to read systemd-analyze boot time data
        // We can't run systemd-analyze directly, but we can try to read from journal
        QFile journalBootId(QStringLiteral("/etc/machine-id"));
        if (journalBootId.open(QIODevice::ReadOnly)) {
            const QString bootId = QString::fromUtf8(journalBootId.readAll()).trimmed().left(8);
            bootStats.insert(u"bootId"_s, bootId);
            journalBootId.close();
        }

        // Get firmware boot time from EFI if available
        const QUuid global = efiGlobalGuid();
        const auto bootCurrentData = qefi_get_variable(global, u"BootCurrent"_s);
        if (!bootCurrentData.isEmpty() && bootCurrentData.size() >= 2) {
            const quint16 bootCurrent = qFromLittleEndian<quint16>(*reinterpret_cast<const quint16 *>(bootCurrentData.constData()));
            bootStats.insert(u"bootCurrent"_s, static_cast<int>(bootCurrent));
        }

        // Get timestamp of when EFI started (if available)
        QFile uptimeFile(QStringLiteral("/proc/uptime"));
        if (uptimeFile.open(QIODevice::ReadOnly)) {
            const QString uptimeStr = QString::fromUtf8(uptimeFile.readAll());
            const double uptime = uptimeStr.split(u' ').first().toDouble();
            bootStats.insert(u"uptimeSeconds"_s, static_cast<qint64>(uptime));

            // Format uptime as human-readable
            const qint64 uptimeDays = static_cast<qint64>(uptime) / 86400;
            const qint64 uptimeHours = (static_cast<qint64>(uptime) % 86400) / 3600;
            const qint64 uptimeMinutes = (static_cast<qint64>(uptime) % 3600) / 60;
            bootStats.insert(u"uptimeFormatted"_s, u"%1d %2h %3m"_s.arg(uptimeDays).arg(uptimeHours).arg(uptimeMinutes));

            uptimeFile.close();
        }

        // Get load averages
        QFile loadavgFile(QStringLiteral("/proc/loadavg"));
        if (loadavgFile.open(QIODevice::ReadOnly)) {
            const QByteArray loadavgData = loadavgFile.readAll();
            const QString loadavgStr = QString::fromUtf8(loadavgData);
            const QStringList loadavgParts = loadavgStr.split(u' ');
            if (loadavgParts.size() >= 3) {
                bootStats.insert(u"loadAverage1m"_s, loadavgParts[0]);
                bootStats.insert(u"loadAverage5m"_s, loadavgParts[1]);
                bootStats.insert(u"loadAverage15m"_s, loadavgParts[2]);
            }
            loadavgFile.close();
        }

        // Get process count
        bootStats.insert(u"processCount"_s, 0);
        QFile loadavgProcFile(QStringLiteral("/proc/loadavg"));
        if (loadavgProcFile.open(QIODevice::ReadOnly)) {
            const QByteArray data = loadavgProcFile.readAll();
            const QString str = QString::fromUtf8(data);
            const QStringList parts = str.split(u' ');
            // The last two parts are usually "processes/total processes"
            if (parts.size() >= 5) {
                bool ok = false;
                const int procCount = parts[3].toInt(&ok);
                if (ok) {
                    bootStats.insert(u"runningProcesses"_s, procCount);
                }
                const int totalProcs = parts[4].split(QStringLiteral("/"))[0].toInt(&ok);
                if (ok) {
                    bootStats.insert(u"totalProcesses"_s, totalProcs);
                }
            }
            loadavgProcFile.close();
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"bootStats"_s, bootStats);
        return reply;
    }

    KAuth::ActionReply getBootHistory()
    {
        KAuth::ActionReply reply;
        QVariantList history;

        // Boot history file location
        const QString historyPath = QStringLiteral("/var/lib/efibootkcm/boot_history.json");

        // Try to read existing boot history
        QFile historyFile(historyPath);
        if (historyFile.open(QIODevice::ReadOnly)) {
            const QByteArray historyData = historyFile.readAll();
            historyFile.close();

            QJsonDocument jsonDoc = QJsonDocument::fromJson(historyData);
            if (jsonDoc.isArray()) {
                QJsonArray jsonArray = jsonDoc.array();
                for (const QJsonValue &value : jsonArray) {
                    history.append(value.toVariant());
                }
            }
        } else {
            // No history file yet - return empty history
            reply = KAuth::ActionReply::SuccessReply();
            reply.addData(u"bootHistory"_s, history);
            return reply;
        }

        // Add current boot entry to history if not already recorded
        const QUuid global = efiGlobalGuid();
        const auto bootCurrentData = qefi_get_variable(global, u"BootCurrent"_s);
        if (!bootCurrentData.isEmpty() && bootCurrentData.size() >= 2) {
            const quint16 bootCurrent = qFromLittleEndian<quint16>(*reinterpret_cast<const quint16 *>(bootCurrentData.constData()));

            // Get current boot time
            QFile statFile(QStringLiteral("/proc/stat"));
            qint64 bootTime = 0;
            if (statFile.open(QIODevice::ReadOnly)) {
                const QByteArray statData = statFile.readAll();
                const QStringList lines = QString::fromUtf8(statData).split(u'\n');
                for (const QString &line : lines) {
                    if (line.startsWith(QStringLiteral("btime"))) {
                        const QStringList parts = line.split(u' ');
                        if (parts.size() >= 2) {
                            bool ok = false;
                            bootTime = parts[1].toLongLong(&ok);
                        }
                        break;
                    }
                }
                statFile.close();
            }

            // Check if this boot is already in history
            bool alreadyRecorded = false;
            for (const QVariant &entry : history) {
                QVariantMap entryMap = entry.toMap();
                if (entryMap.value(u"bootTime"_s).toLongLong() == bootTime) {
                    alreadyRecorded = true;
                    break;
                }
            }

            if (!alreadyRecorded && bootTime > 0) {
                // Read boot entry details
                const QString bootVarName = QStringLiteral("Boot%1").arg(bootCurrent, 4, 16, QLatin1Char('0'));
                const QByteArray entryData = qefi_get_variable(global, bootVarName);
                QString entryName;
                if (!entryData.isEmpty()) {
                    QEFILoadOption entryOption(entryData);
                    if (entryOption.isValidated()) {
                        entryName = entryOption.name();
                    }
                }

                // Create new history entry
                QVariantMap newEntry;
                newEntry.insert(u"bootTime"_s, bootTime);
                newEntry.insert(u"bootDateTime"_s, QDateTime::fromSecsSinceEpoch(bootTime).toString(Qt::ISODate));
                newEntry.insert(u"bootEntry"_s, static_cast<int>(bootCurrent));
                newEntry.insert(u"entryName"_s, entryName);
                newEntry.insert(u"entryId"_s, bootVarName);

                // Add to beginning of history
                history.prepend(newEntry);

                // Keep only last 100 boot entries
                while (history.size() > 100) {
                    history.removeLast();
                }

                // Save updated history
                QDir().mkpath(QStringLiteral("/var/lib/efibootkcm"));
                if (historyFile.open(QIODevice::WriteOnly)) {
                    QJsonArray jsonArray;
                    for (const QVariant &entry : history) {
                        QJsonObject entryObj = QJsonObject::fromVariantMap(entry.toMap());
                        jsonArray.append(entryObj);
                    }
                    QJsonDocument jsonDoc(jsonArray);
                    historyFile.write(jsonDoc.toJson(QJsonDocument::Compact));
                    historyFile.close();
                }
            }
        }

        reply = KAuth::ActionReply::SuccessReply();
        reply.addData(u"bootHistory"_s, history);
        return reply;
    }
};

KAUTH_HELPER_MAIN("cc.inoki.efibootkcm.helper", EfiBootHelper)

#include "efiboothelper.moc"

