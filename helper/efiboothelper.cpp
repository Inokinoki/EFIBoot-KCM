/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include <KAuth/ActionReply>
#include <KAuth/HelperSupport>

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QProcess>
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
    KAuth::ActionReply setDefault(const QVariantMap &args)
    {
        if (!qefi_is_available()) {
            return KAuth::ActionReply::ErrorReply(u"EFI variables are not available on this system."_s);
        }

        bool ok = false;
        const quint16 entryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            return KAuth::ActionReply::ErrorReply(u"Missing or invalid entryId."_s);
        }

        const QUuid global = efiGlobalGuid();
        auto order = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));

        // New order: selected entry first, then the existing order without duplicates.
        std::vector<quint16> newOrder;
        newOrder.reserve(order.size() + 1);
        newOrder.push_back(entryId);
        for (const auto id : order) {
            if (id != entryId) {
                newOrder.push_back(id);
            }
        }

        qefi_set_variable(global, u"BootOrder"_s, encodeUint16Array(newOrder));

        auto reply = KAuth::ActionReply::SuccessReply();
        reply.addData({{u"info"_s, u"Default boot entry updated."_s}});
        return reply;
    }

    KAuth::ActionReply rebootTo(const QVariantMap &args)
    {
        if (!qefi_is_available()) {
            return KAuth::ActionReply::ErrorReply(u"EFI variables are not available on this system."_s);
        }

        bool ok = false;
        const quint16 entryId = static_cast<quint16>(args.value(u"entryId"_s).toUInt(&ok));
        if (!ok) {
            return KAuth::ActionReply::ErrorReply(u"Missing or invalid entryId."_s);
        }

        const QUuid global = efiGlobalGuid();
        qefi_set_variable_uint16(global, u"BootNext"_s, entryId);

        if (qEnvironmentVariableIsSet("KCM_EFIBOOT_NO_REBOOT")) {
            auto reply = KAuth::ActionReply::SuccessReply();
            reply.addData({{u"info"_s, u"BootNext set; reboot skipped (KCM_EFIBOOT_NO_REBOOT)."_s}});
            return reply;
        }

        // Prefer logind, fallback to systemctl.
        QDBusInterface login1(u"org.freedesktop.login1"_s,
                              u"/org/freedesktop/login1"_s,
                              u"org.freedesktop.login1.Manager"_s,
                              QDBusConnection::systemBus());
        if (login1.isValid()) {
            const auto call = login1.call(u"Reboot"_s, true);
            if (call.type() == QDBusMessage::ErrorMessage) {
                QProcess::startDetached(u"systemctl"_s, {u"reboot"_s});
            }
        } else {
            QProcess::startDetached(u"systemctl"_s, {u"reboot"_s});
        }

        return KAuth::ActionReply::SuccessReply();
    }
};

KAUTH_HELPER_MAIN("org.kde.kcm.efiboot.helper", EfiBootHelper)

#include "efiboothelper.moc"

