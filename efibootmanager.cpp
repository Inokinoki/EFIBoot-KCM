/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "efibootmanager.h"

#include <KAuth/Action>
#include <KAuth/ExecuteJob>
#include <KLocalizedString>

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

static QString bootVarName(quint16 entryId)
{
    return QStringLiteral("Boot%1").arg(entryId, 4, 16, QLatin1Char('0'));
}

EfiBootManager::EfiBootManager(QObject *parent)
    : QObject(parent)
{
    m_available = qefi_is_available();
}

EfiBootEntryModel *EfiBootManager::entries()
{
    return &m_entries;
}

bool EfiBootManager::available() const
{
    return m_available;
}

bool EfiBootManager::busy() const
{
    return m_busy;
}

QString EfiBootManager::lastError() const
{
    return m_lastError;
}

void EfiBootManager::refresh()
{
    const bool nowAvailable = qefi_is_available();
    if (m_available != nowAvailable) {
        m_available = nowAvailable;
        Q_EMIT availableChanged();
    }

    setLastError(QString());

    if (!m_available) {
        m_entries.setEntries({});
        setLastError(i18n("EFI variables are not available on this system."));
        return;
    }

    const QUuid global = efiGlobalGuid();
    const auto bootOrder = parseUint16Array(qefi_get_variable(global, u"BootOrder"_s));
    const quint16 defaultId = bootOrder.empty() ? 0 : bootOrder.front();

    // Read BootNext to get one-time boot entry
    const auto bootNext = qefi_get_variable_uint16(global, u"BootNext"_s);

    // Read BootCurrent to get the currently booted entry
    const auto bootCurrent = qefi_get_variable_uint16(global, u"BootCurrent"_s);

    std::vector<EfiBootEntryModel::Entry> entries;
    entries.reserve(bootOrder.size());

    // Read only the boot entries listed in BootOrder (these are the active ones)
    for (const quint16 entryId : bootOrder) {
        // Use qefi utility to read the boot variable data
        const QByteArray raw = qefi_get_variable(global, bootVarName(entryId));
        if (raw.isEmpty()) {
            continue;
        }

        QEFILoadOption opt(raw);
        if (!opt.isValidated()) {
            continue;
        }

        EfiBootEntryModel::Entry entry;
        entry.id = entryId;
        entry.name = opt.name().isEmpty() ? i18nc("@item:inlistbox", "(Unnamed entry)") : opt.name();
        entry.path = opt.path();
        entry.isVisible = opt.isVisible();
        entry.isDefault = (entryId == defaultId);
        entry.isBootNext = (bootNext == entryId);
        entry.isCurrent = (bootCurrent == entryId);
        entry.raw = raw;
        entry.optionalData = qefi_extract_optional_data(raw);
        entries.push_back(std::move(entry));
    }

    std::ranges::sort(entries, {}, &EfiBootEntryModel::Entry::id);
    m_entries.setEntries(std::move(entries));

    if (m_entries.rowCount() == 0 && m_available) {
        setLastError(i18n("No EFI boot entries could be read."));
    }
}

QVariantMap EfiBootManager::detailsForEntry(quint16 entryId) const
{
    const auto *entry = m_entries.entryForId(entryId);
    if (!entry) {
        return {};
    }

    auto hexString = [](const QByteArray &data) -> QString {
        if (data.isEmpty()) {
            return QString();
        }
        return QString::fromLatin1(data.toHex(' ')).toUpper();
    };

    return {
        {u"entryId"_s, entry->id},
        {u"entryIdHex"_s, QStringLiteral("%1").arg(entry->id, 4, 16, QLatin1Char('0')).toUpper()},
        {u"name"_s, entry->name},
        {u"path"_s, entry->path},
        {u"isDefault"_s, entry->isDefault},
        {u"isVisible"_s, entry->isVisible},
        {u"rawSize"_s, entry->raw.size()},
        {u"rawHex"_s, hexString(entry->raw)},
        {u"optionalDataSize"_s, entry->optionalData.size()},
        {u"optionalDataHex"_s, hexString(entry->optionalData)},
    };
}

void EfiBootManager::setDefault(quint16 entryId)
{
    runAuthAction(u"org.kde.kcm.efiboot.setdefault"_s, {{u"entryId"_s, entryId}});
}

void EfiBootManager::rebootTo(quint16 entryId)
{
    runAuthAction(u"org.kde.kcm.efiboot.rebootto"_s, {{u"entryId"_s, entryId}});
}

void EfiBootManager::runAuthAction(const QString &actionId, const QVariantMap &args)
{
    if (!m_available) {
        setLastError(i18n("EFI variables are not available on this system."));
        return;
    }

    if (m_busy) {
        return;
    }

    setBusy(true);
    setLastError(QString());

    KAuth::Action action(actionId);
    action.setHelperId(QStringLiteral("org.kde.kcm.efiboot.helper"));
    for (auto it = args.cbegin(); it != args.cend(); ++it) {
        action.addArgument(it.key(), it.value());
    }

    auto *job = action.execute();
    job->setAutoDelete(true);
    connect(job, &KJob::result, this, [this, job, actionId] {
        setBusy(false);

        // Log detailed error information
        qDebug() << "Action:" << actionId;
        qDebug() << "Job error:" << job->error();
        qDebug() << "Job error text:" << job->errorText();
        qDebug() << "Job data:" << job->data();

        if (job->error() != 0) {
            const QString errorMsg = job->errorText();
            const QString finalError = errorMsg.isEmpty()
                ? i18n("Authentication or execution failed. Check terminal for details.")
                : errorMsg;
            setLastError(finalError);
            Q_EMIT operationResult(false, finalError);
            return;
        }

        const QVariantMap data = job->data();

        // Check for error from helper (ActionReply error)
        if (const auto error = data.value(u"error"_s).toString(); !error.isEmpty()) {
            setLastError(error);
            Q_EMIT operationResult(false, error);
            return;
        }

        // Check for error description from ActionReply
        if (const auto errorDesc = data.value(u"errorDescription"_s).toString(); !errorDesc.isEmpty()) {
            setLastError(errorDesc);
            Q_EMIT operationResult(false, errorDesc);
            return;
        }

        // Check for custom error code from helper
        if (data.value(u"errorCode"_s).toInt() != 0) {
            const auto errorDesc = data.value(u"errorDescription"_s).toString();
            const QString errorMsg = errorDesc.isEmpty()
                ? i18n("Helper action failed with error code %1").arg(data.value(u"errorCode"_s).toInt())
                : errorDesc;
            setLastError(errorMsg);
            Q_EMIT operationResult(false, errorMsg);
            return;
        }

        // Check for success with info message
        if (const auto info = data.value(u"info"_s).toString(); !info.isEmpty()) {
            Q_EMIT operationResult(true, info);
        } else {
            Q_EMIT operationResult(true, i18n("Operation completed successfully."));
        }

        refresh();
    });
    job->start();
}

void EfiBootManager::setBusy(bool busy)
{
    if (m_busy == busy) {
        return;
    }
    m_busy = busy;
    Q_EMIT busyChanged();
}

void EfiBootManager::setLastError(const QString &error)
{
    if (m_lastError == error) {
        return;
    }
    m_lastError = error;
    Q_EMIT lastErrorChanged();
}

