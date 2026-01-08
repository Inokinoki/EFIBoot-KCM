/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include "efibootentrymodel.h"

#include <QObject>
#include <QVariantMap>

class KJob;

class EfiBootManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(EfiBootEntryModel *entries READ entries CONSTANT)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit EfiBootManager(QObject *parent = nullptr);

    EfiBootEntryModel *entries();
    bool available() const;
    bool busy() const;
    QString lastError() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE QVariantMap detailsForEntry(quint16 entryId) const;
    Q_INVOKABLE void setDefault(quint16 entryId);
    Q_INVOKABLE void rebootTo(quint16 entryId);

Q_SIGNALS:
    void availableChanged();
    void busyChanged();
    void lastErrorChanged();
    void infoMessage(const QString &text);

private:
    void runAuthAction(const QString &actionId, const QVariantMap &args);
    void setBusy(bool busy);
    void setLastError(const QString &error);

    EfiBootEntryModel m_entries;
    bool m_available = false;
    bool m_busy = false;
    QString m_lastError;
};

