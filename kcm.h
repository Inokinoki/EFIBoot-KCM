/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <KQuickConfigModule>
#include <KSharedConfig>

class EfiBootManager;

class EfiBootKCM : public KQuickConfigModule
{
    Q_OBJECT
    Q_PROPERTY(EfiBootManager *manager READ manager CONSTANT)
    Q_PROPERTY(QString settingsPath READ settingsPath CONSTANT)

public:
    explicit EfiBootKCM(QObject *parent, const KPluginMetaData &data, const QVariantList &args);

    EfiBootManager *manager() const;
    QString settingsPath() const;

public Q_SLOTS:
    void load() override;
    void savePreferences();
    void loadPreferences();

private:
    EfiBootManager *const m_manager;
    KSharedConfig::Ptr m_config;
};

