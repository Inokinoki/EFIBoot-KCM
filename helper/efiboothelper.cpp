/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include <KAuth/ActionReply>
#include <KAuth/HelperSupport>

#include <QtEndian>

#include <algorithm>

#include <qefi.h>

using namespace Qt::StringLiterals;

static QUuid efiGlobalGuid()
{
    return QUuid(QStringLiteral("8be4df61-93ca-11d2-aa0d-00e098032b8c"));
}

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
};

KAUTH_HELPER_MAIN("cc.inoki.efibootkcm.helper", EfiBootHelper)

#include "efiboothelper.moc"

