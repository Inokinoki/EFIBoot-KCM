/**
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "kcm.h"

#include "efibootentrymodel.h"
#include "efibootmanager.h"

#include <KConfigGroup>
#include <KPluginFactory>

#include <QQmlEngine>
#include <QStandardPaths>

K_PLUGIN_CLASS_WITH_JSON(EfiBootKCM, "kcm_efiboot.json")

EfiBootKCM::EfiBootKCM(QObject *parent, const KPluginMetaData &data, const QVariantList &args)
    : KQuickConfigModule(parent, data)
    , m_manager(new EfiBootManager(this))
    , m_config(KSharedConfig::openConfig(QStringLiteral("efibootkcmrc")))
{
    Q_UNUSED(args)

    // Hide OK/Apply/Cancel buttons since changes are applied immediately via helper actions
    setButtons(KQuickConfigModule::NoAdditionalButton);

    constexpr const char *uri = "org.kde.plasma.kcm.efiboot";
    qmlRegisterUncreatableType<EfiBootEntryModel>(uri, 1, 0, "EfiBootEntryModel", QStringLiteral("Provided by the KCM"));
    qmlRegisterUncreatableType<EfiBootManager>(uri, 1, 0, "EfiBootManager", QStringLiteral("Provided by the KCM"));

    connect(this, &KQuickConfigModule::mainUiReady, this, &EfiBootKCM::load, Qt::SingleShotConnection);
}

EfiBootManager *EfiBootKCM::manager() const
{
    return m_manager;
}

QString EfiBootKCM::settingsPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QStringLiteral("/efibootkcmrc");
}

void EfiBootKCM::load()
{
    m_manager->refresh();
    loadPreferences();
}

void EfiBootKCM::savePreferences()
{
    KConfigGroup group(m_config, QStringLiteral("General"));
    // Settings can be saved here when needed
    group.sync();
}

void EfiBootKCM::loadPreferences()
{
    KConfigGroup group(m_config, QStringLiteral("General"));
    // Settings can be loaded here when needed
}

#include "kcm.moc"

