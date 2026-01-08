/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "efibootmanager.h"

#include <KAuth/Action>
#include <KAuth/ExecuteJob>
#include <KLocalizedString>

#include <QDir>
#include <QRegularExpression>
#include <QtEndian>

#include <algorithm>

#include <qefi.h>

using namespace Qt::StringLiterals;

static QUuid efiGlobalGuid()
{
    return QUuid(QStringLiteral("8be4df61-93ca-11d2-aa0d-00e098032b8c"));
}

static QString efivarfsPath()
{
    const QString fromEnv = qEnvironmentVariable("EFIVARFS_PATH");
    if (!fromEnv.isEmpty()) {
        return fromEnv;
    }
    return QStringLiteral("/sys/firmware/efi/efivars/");
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
    return QStringLiteral("Boot%1").arg(entryId, 4, 16, QLatin1Char('0')).toUpper();
}

EfiBootManager::EfiBootManager(QObject *parent)
    : QObject(parent)
{
    m_available = qefi_is_available();
    m_hasPrivilege = qefi_has_privilege();
}

EfiBootEntryModel *EfiBootManager::entries()
{
    return &m_entries;
}

bool EfiBootManager::available() const
{
    return m_available;
}

bool EfiBootManager::hasPrivilege() const
{
    return m_hasPrivilege;
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

    const bool nowHasPrivilege = qefi_has_privilege();
    if (m_hasPrivilege != nowHasPrivilege) {
        m_hasPrivilege = nowHasPrivilege;
        Q_EMIT hasPrivilegeChanged();
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

    QDir dir(efivarfsPath());
    const QStringList files = dir.entryList(QDir::Files | QDir::NoDotAndDotDot);

    static const QRegularExpression bootVarRe(QStringLiteral(R"(^Boot([0-9A-Fa-f]{4})-([0-9A-Fa-f-]{36})$)"));

    std::vector<EfiBootEntryModel::Entry> entries;
    entries.reserve(static_cast<size_t>(files.size()));

    const QString guidWithDashes = global.toString(QUuid::WithoutBraces).toLower();

    for (const QString &file : files) {
        const auto match = bootVarRe.match(file);
        if (!match.hasMatch()) {
            continue;
        }

        const QString fileGuid = match.captured(2).toLower();
        if (fileGuid != guidWithDashes) {
            continue;
        }

        bool ok = false;
        const quint16 entryId = match.captured(1).toUShort(&ok, 16);
        if (!ok) {
            continue;
        }

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
        entry.isDefault = (defaultId != 0) && (entryId == defaultId);
        entry.raw = raw;
        entry.optionalData = qefi_extract_optional_data(raw);
        entries.push_back(std::move(entry));
    }

    std::ranges::sort(entries, {}, &EfiBootEntryModel::Entry::id);
    m_entries.setEntries(std::move(entries));

    if (m_entries.rowCount() == 0 && m_available && !m_hasPrivilege) {
        // Listing should not trigger authentication; if the system restricts reads,
        // show an informative message instead of prompting.
        setLastError(i18n("No EFI boot entries could be read. This may require administrator privileges on your system."));
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
    connect(job, &KJob::result, this, [this, job] {
        setBusy(false);

        if (job->error() != 0) {
            setLastError(job->errorText());
            return;
        }

        const QVariantMap data = job->data();
        if (const auto error = data.value(u"error"_s).toString(); !error.isEmpty()) {
            setLastError(error);
            return;
        }

        if (const auto info = data.value(u"info"_s).toString(); !info.isEmpty()) {
            Q_EMIT infoMessage(info);
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

